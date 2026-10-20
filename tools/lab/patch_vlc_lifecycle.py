#!/usr/bin/env python3
"""Isolate the pinned VLC dependency and stop its decoder before releasing surfaces."""
import hashlib
import json
from pathlib import Path
import shutil
from urllib.parse import unquote, urljoin, urlparse

OLD = '''        textureView.dispose();
        textureEntry.release();
        mediaEventChannel.setStreamHandler(null);
        rendererEventChannel.setStreamHandler(null);
        if (mediaPlayer != null) {
            mediaPlayer.stop();
            mediaPlayer.setEventListener(null);
            mediaPlayer.getVLCVout().detachViews();
            mediaPlayer.release();
            mediaPlayer = null;
        }'''
NEW = '''        // LAB lifecycle fix: stop decoding and detach before releasing surfaces.
        if (mediaPlayer != null) {
            mediaPlayer.setEventListener(null);
            mediaPlayer.stop();
            mediaPlayer.getVLCVout().detachViews();
        }
        textureView.dispose();
        textureEntry.release();
        mediaEventChannel.setStreamHandler(null);
        rendererEventChannel.setStreamHandler(null);
        if (mediaPlayer != null) {
            mediaPlayer.release();
            mediaPlayer = null;
        }'''


def patch(source):
    if source.count(OLD) != 1:
        raise ValueError('Pinned VLC dispose implementation differs; refusing an unverified patch')
    return source.replace(OLD, NEW)


def main():
    root = Path(__file__).resolve().parents[2]
    config = root / '.dart_tool/package_config.json'
    packages = json.loads(config.read_text())['packages']
    package = next(p for p in packages if p['name'] == 'flutter_vlc_player')
    uri = urljoin(config.as_uri(), package['rootUri'])
    origin = Path(unquote(urlparse(uri).path))
    destination = root / 'build/lab-vlc-plugin'
    if origin.resolve() == destination.resolve():
        raise ValueError('Restore normal pub resolution before preparing a fresh LAB copy')
    shutil.copytree(origin, destination, dirs_exist_ok=True)
    java = destination / 'android/src/main/java/software/solid/fluttervlcplayer/FlutterVlcPlayer.java'
    original = java.read_text()
    java.write_text(patch(original))
    override = root / 'pubspec_overrides.yaml'
    if override.exists():
        raise ValueError('Existing pubspec override must be reviewed before LAB preparation')
    override.write_text('dependency_overrides:\n  flutter_vlc_player:\n    path: build/lab-vlc-plugin\n')
    out = root / 'build/lab'
    out.mkdir(parents=True, exist_ok=True)
    (out / 'vlc-lifecycle-patch.json').write_text(json.dumps({
        'package': 'flutter_vlc_player', 'version': '7.4.3', 'scope': 'isolated LAB copy',
        'sourceSha256': hashlib.sha256(original.encode()).hexdigest(),
        'patchedSha256': hashlib.sha256(java.read_bytes()).hexdigest(),
        'order': ['stop decoder', 'detach views', 'release texture', 'release player'],
    }, indent=2))


if __name__ == '__main__':
    main()
