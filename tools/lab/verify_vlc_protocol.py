#!/usr/bin/env python3
"""Fail before building when VLC Dart and Android Pigeon wire protocols drift."""
import hashlib
import json
from pathlib import Path
import re
from urllib.parse import unquote, urlsplit


def verify(native, dart):
    pattern = r'''["'](dev\.flutter\.pigeon[^"']*VlcPlayerApi\.(?:initialize|create|dispose))["']'''
    android_channels = set(re.findall(pattern, native))
    dart_channels = set(re.findall(pattern, dart))
    generator = lambda s: re.search(r'Pigeon \(v([^\)]+)\)', s).group(1)
    if len(android_channels) != 3 or android_channels != dart_channels or generator(native) != generator(dart):
        raise ValueError('Incompatible VLC Pigeon protocols: Android and Dart channel names/generators differ')
    return {'channels': sorted(android_channels), 'nativePigeon': generator(native),
            'dartPigeon': generator(dart),
            'nativeSha256': hashlib.sha256(native.encode()).hexdigest(),
            'dartSha256': hashlib.sha256(dart.encode()).hexdigest()}


def main():
    config = Path('.dart_tool/package_config.json')
    packages = json.loads(config.read_text())['packages']
    def root(name):
        uri = next(p['rootUri'] for p in packages if p['name'] == name)
        return Path(unquote(urlsplit(uri).path)) if uri.startswith('file:') else config.parent / unquote(uri)
    native = root('flutter_vlc_player') / 'android/src/main/java/software/solid/fluttervlcplayer/Messages.java'
    dart = root('flutter_vlc_player_platform_interface') / 'lib/src/messages/messages.dart'
    result = verify(native.read_text(), dart.read_text())
    out = Path('build/lab/vlc-protocol.json')
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(result, indent=2))
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
