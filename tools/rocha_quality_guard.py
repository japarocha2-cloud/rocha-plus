from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

BANNED = {
    "screen_mirror": "comando legado de espelhamento",
    "ACTION_CAST_SETTINGS": "atalho legado de Cast",
    "ACTION_WIRELESS_SETTINGS": "atalho legado de rede",
    "ROCHA_CAST_APP_ID": "identificador legado de Cast",
    "HlsVideoSegmentFormat.mpeg2Ts": "segmentação HLS legada",
}

SOURCE_EXTS = {".dart", ".xml", ".kt", ".kts", ".gradle", ".properties"}
issues = []

for source_root in (ROOT / "lib", ROOT / "android"):
    if not source_root.exists():
        continue
    for path in source_root.rglob("*"):
        if not path.is_file() or path.suffix.lower() not in SOURCE_EXTS:
            continue
        try:
            source = path.read_text(encoding="utf-8", errors="ignore")
        except OSError:
            continue

        rel = path.relative_to(ROOT)
        for token, label in BANNED.items():
            if token in source:
                issues.append(f"{rel}: encontrou {label} ({token})")

        if path.suffix == ".dart" and '"Undefined"' in source:
            issues.append(f"{rel}: texto visível 'Undefined' encontrado")

required = [
    ROOT / "lib/src/screens/player_screen.dart",
    ROOT / "lib/src/screens/intro_screen.dart",
    ROOT / "lib/src/cast/cast_hls_proxy.dart",
    ROOT / "branding/rocha_plus_icon.webp",
]
for path in required:
    if not path.exists() or path.stat().st_size == 0:
        issues.append(f"{path.relative_to(ROOT)}: arquivo obrigatório ausente ou vazio")

print("Rocha+ Quality Guard")
if issues:
    print("FALHA: regressões críticas encontradas:")
    for issue in issues:
        print(f"- {issue}")
    sys.exit(1)

print("OK: nenhuma regressão crítica conhecida encontrada.")
