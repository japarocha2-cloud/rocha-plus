from pathlib import Path
import re
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
dart_files = []

for path in ROOT.rglob("*"):
    if not path.is_file() or any(part in ignore_parts for part in path.parts):
        continue
    if ".rocha-support" in path.parts or path.suffix.lower() not in TEXT_EXTS:
        continue
    try:
        text = path.read_text(encoding="utf-8", errors="ignore")
    except OSError:
        continue

    rel = path.relative_to(ROOT)
    if path.suffix == ".dart":
        dart_files.append((rel, text))

    for token, label in BANNED.items():
        if token in text and rel != Path("tools/rocha_quality_guard.py"):
            issues.append(f"{rel}: encontrou {label} ({token})")

    if path.suffix == ".dart" and ('"Undefined"' in text or "'Undefined'" in text):
        issues.append(f"{rel}: texto visível 'Undefined' encontrado")

    # Segredos e transporte inseguro são bloqueadores de release.
    if re.search(r'(?i)(api[_-]?key|secret|token|password)\s*[:=]\s*["\'][^"\']{8,}', text):
        issues.append(f"{rel}: possível segredo fixo no código")
    # Só URLs literais de runtime contam. Ignora namespaces XML e testes/documentação.
    if rel.parts[0] not in {"test", "docs"} and path.suffix in {".dart", ".json", ".yaml", ".yml"}:
        if re.search(r"[\"']http://(?!localhost|127\\.0\\.0\\.1)", text):
            issues.append(f"{rel}: URL HTTP insegura de runtime encontrada")

# Fiscaliza os contratos mínimos das telas principais.
all_dart = "\n".join(text for rel, text in dart_files if rel.parts and rel.parts[0] == "lib")
required = {
    "Esportes": "rota/categoria Esportes",
    "Notícias": "rota/categoria Notícias",
    "Tela cheia": "controle de fullscreen",
    "Transmitir para TV": "controle de Cast",
    "VideoPlayerController.networkUrl": "player de rede",
}
for token, label in required.items():
    if token not in all_dart:
        issues.append(f"app: ausente {label} ({token})")

# Não permite reintroduzir a mensagem que transformou categorias em botões mortos.
if "Esportes entra na próxima etapa." in all_dart:
    issues.append("home: Esportes voltou a ser botão sem função")

# Não permite categorias técnicas do M3U como navegação principal.
raw_groups = ["Animation;Kids", "Animation;Comedy", "Comedy;Series", "Cooking;Lifestyle"]
for group in raw_groups:
    if group in all_dart:
        issues.append(f"UI: categoria técnica bruta exposta: {group}")

print("Rocha+ Fiscal de Varredura")
print(f"Arquivos Dart inspecionados: {len(dart_files)}")
if issues:
    print("BLOQUEADO: falhas críticas encontradas:")
    for issue in issues:
        print(f"- {issue}")
    sys.exit(1)

print("APROVADO NO ESTÁTICO: nenhuma regressão crítica conhecida encontrada.")
print("OBS: reprodução, áudio/volume, Cast, rede real e TV física exigem teste de dispositivo.")
