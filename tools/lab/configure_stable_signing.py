"""Optional dedicated Android LAB debug signing. Never checks secrets into Git."""
import base64
import os
from pathlib import Path


def configure(env, root):
    fields = ('LAB_KEYSTORE_BASE64', 'LAB_KEYSTORE_PASSWORD', 'LAB_KEY_ALIAS')
    present = [bool(env.get(k)) for k in fields]
    if not any(present):
        print('LAB signing secrets absent: temporary debug signing; SHA-1 is diagnostic only.')
        return False
    if not all(present):
        raise ValueError('Incomplete dedicated LAB signing secrets')
    gradle = Path(root) / 'android/app/build.gradle.kts'
    content = gradle.read_text()
    marker = 'applicationIdSuffix = ".lab"'
    if marker not in content or 'rochaLabSigning' in content:
        raise ValueError('LAB Android configuration not prepared or already modified')
    directory = Path(root) / '.rocha-private-lab'
    directory.mkdir(mode=0o700, exist_ok=True)
    directory.chmod(0o700)
    store = directory / 'lab.keystore'
    store.write_bytes(base64.b64decode(env['LAB_KEYSTORE_BASE64'], validate=True))
    store.chmod(0o600)
    snippet = """
android {
    signingConfigs {
        create("rochaLabSigning") {
            storeFile = file("$STOREPATH")
            storePassword = System.getenv("LAB_KEYSTORE_PASSWORD")
            keyAlias = System.getenv("LAB_KEY_ALIAS")
            keyPassword = System.getenv("LAB_KEYSTORE_PASSWORD")
        }
    }
    buildTypes {
        getByName("debug") { signingConfig = signingConfigs.getByName("rochaLabSigning") }
    }
}
""".replace("$STOREPATH", store.as_posix())
    gradle.write_text(content + '\n' + snippet)
    print('Dedicated LAB signing configured, key held only in transient CI workspace.')
    return True


if __name__ == '__main__':
    configure(os.environ, Path.cwd())
