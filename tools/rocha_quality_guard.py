from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]

BANNED = {
    "screen_mirror": "comando legado de espelhamento",
    "ACTION_CAST_SETTINGS": "atalho legado de Cast",
    "ACTION_WIRELESS_SETTINGS": "atalho legado de rede",
    "ROCHA_CAST_APP_ID": "identificador legado de Cast",
}

TEXT_EXTS = {
    ".dart", ".yaml", ".yml", ".json", ".xml", ".gradle",
    ".kts", ".md", ".txt", ".properties", ".java", ".kt"
}

ignore_parts = {".git", "build", ".dart_tool"}
issues = []

for path in ROOT.rglob("*"):
    if not path.is_file():
        continue
    if any(part in ignore_parts for part in path.parts):
        continue
    if ".rocha-support" in path.parts:
        continue
    if path.suffix.lower() not in TEXT_EXTS:
        continue

    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        continue

    rel = path.relative_to(ROOT)

    for token, label in BANNED.items():
        if token in text and rel != Path("tools/rocha_quality_guard.py"):
            issues.append(f"{rel}: encontrou {label} ({token})")

    if path.suffix == ".dart" and '"Undefined"' in text:
        issues.append(f"{rel}: texto visível 'Undefined' encontrado")

print("Rocha+ Quality Guard")
if issues:
    print("FALHA: regressões críticas encontradas:")
    for issue in issues:
        print(f"- {issue}")
    sys.exit(1)

print("OK: nenhuma regressão crítica conhecida encontrada.")
