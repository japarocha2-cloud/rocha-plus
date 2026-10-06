#!/usr/bin/env python3
"""Rocha+ Support V1: deterministic second-pair-of-eyes auditor."""

from __future__ import annotations
import json
import subprocess
from dataclasses import dataclass, asdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
REPORT_MD = ROOT / "rocha-support-report.md"
REPORT_JSON = ROOT / "rocha-support-report.json"

@dataclass
class Finding:
    level: str
    area: str
    message: str
    evidence: str = ""

findings = []

def add(level, area, message, evidence=""):
    findings.append(Finding(level, area, message, evidence))

def text(path):
    p = ROOT / path
    return p.read_text(errors="ignore") if p.exists() else ""

def changed_files():
    for command in (
        ["git", "diff", "--name-only", "HEAD^", "HEAD"],
        ["git", "show", "--pretty=", "--name-only", "HEAD"],
    ):
        try:
            result = subprocess.run(
                command, cwd=ROOT, check=True, capture_output=True, text=True
            )
            files = [line.strip() for line in result.stdout.splitlines() if line.strip()]
            if files:
                return files
        except Exception:
            pass
    return []

def audit_structure():
    required = [
        "branding/rocha_plus_icon.webp",
        "assets/rocha_intro_v2.mp4",
        "lib/src/screens/home_screen.dart",
        "lib/src/screens/live_tv_screen.dart",
        "lib/src/screens/player_screen.dart",
        "lib/src/screens/cast_control_screen.dart",
        "lib/src/cast/cast_hls_proxy.dart",
        "test/m3u_parser_test.dart",
    ]
    for path in required:
        p = ROOT / path
        if not p.exists() or p.stat().st_size == 0:
            add("critical", "estrutura", f"Arquivo obrigatório ausente ou vazio: {path}")

    forbidden_paths = [
        "assets/rocha_intro.mp4",
        "assets/rocha_plus_icon.png",
        "branding/rocha_plus_icon.xml",
        "branding/rocha_plus_icon.png",
        "receiver/index.html",
    ]
    for path in forbidden_paths:
        if (ROOT / path).exists():
            add("critical", "limpeza", f"Arquivo legado voltou ao projeto: {path}")

    webp = ROOT / "branding/rocha_plus_icon.webp"
    if webp.exists():
        data = webp.read_bytes()
        if len(data) < 1024 or data[:4] != b"RIFF" or data[8:12] != b"WEBP":
            add("critical", "branding", "O WebP oficial do Rocha+ parece inválido.")
        else:
            add("ok", "branding", "Ícone oficial único validado.", f"{len(data)} bytes")

def audit_legacy_tokens():
    source_files = []
    for root_name in ("lib", "android"):
        root = ROOT / root_name
        if root.exists():
            source_files.extend(
                p for p in root.rglob("*")
                if p.is_file() and p.suffix in {".dart", ".kt", ".kts", ".xml"}
            )
    source = "\n".join(p.read_text(errors="ignore") for p in source_files)
    forbidden = [
        "rocha_plus/screen_mirror",
        "ACTION_CAST_SETTINGS",
        "ACTION_WIRELESS_SETTINGS",
        "HlsVideoSegmentFormat.mpeg2Ts",
        "ROCHA_CAST_APP_ID",
    ]
    for token in forbidden:
        if token in source:
            add("critical", "legado", f"Comando proibido encontrado: {token}")

def audit_cast():
    player = text("lib/src/screens/player_screen.dart")
    proxy = text("lib/src/cast/cast_hls_proxy.dart")
    checks = [
        ("CastMediaPlayerState.playing", "Cast exige confirmação real de PLAYING."),
        ("GoogleCastConnectState.connected", "Sessão Cast exige estado conectado."),
        ("CastHlsProxy.instance.stop()", "Relay Cast é encerrado após uso/falha."),
        ("CastMediaPlayerState.buffering", "Player reconhece buffering do Cast."),
    ]
    for token, message in checks:
        if token in player:
            add("ok", "cast", message)
        else:
            add("critical", "cast", f"Proteção ausente: {message}")
    if "Future<void> stop()" not in proxy:
        add("critical", "cast", "Relay HLS não expõe rotina de encerramento.")

def audit_responsive_ui():
    files = {
        "home": text("lib/src/screens/home_screen.dart"),
        "canais": text("lib/src/screens/live_tv_screen.dart"),
        "player": text("lib/src/screens/player_screen.dart"),
    }
    for area, source in files.items():
        if "maxWidth >= 900" in source:
            add("ok", "responsividade", f"{area}: layout TV/celular detectado.")
        else:
            add("warning", "responsividade", f"{area}: breakpoint TV/celular não detectado.")
    home = files["home"]
    if "NavigationBar(" in home and "_TopNavButton" in home:
        add("ok", "navegação", "Home possui navegação móvel e foco para TV.")
    else:
        add("warning", "navegação", "Home pode estar sem uma das navegações responsivas.")

def audit_stream_stability():
    repository = text("lib/src/live/channel_repository.dart")
    player = text("lib/src/screens/player_screen.dart")
    proxy = text("lib/src/cast/cast_hls_proxy.dart")
    if "cachedSource" in repository and "catch (_)" in repository:
        add("ok", "stream", "Catálogo possui fallback de cache.")
    else:
        add("warning", "stream", "Fallback de catálogo não foi reconhecido.")
    if "_playbackPreference" in repository:
        add("ok", "stream", "Seleção de feeds possui preferência de estabilidade.")
    else:
        add("warning", "stream", "Não há preferência explícita entre feeds duplicados.")
    if "value.isBuffering" in player:
        add("ok", "stream", "Buffering local tem feedback visual.")
    else:
        add("warning", "stream", "Buffering local não tem feedback visual detectado.")
    if "HttpServer" in proxy and "Range" in proxy:
        add("ok", "stream", "Relay HLS mantém servidor local e Range.")

def audit_scope():
    changed = changed_files()
    if changed:
        add(
            "info",
            "mudanças",
            f"{len(changed)} arquivo(s) alterado(s) no commit atual.",
            ", ".join(changed[:12]),
        )
        risky = [
            p for p in changed
            if p.startswith("lib/src/screens/player_screen")
            or p.startswith("lib/src/cast/")
            or p.endswith("build.yml")
        ]
        if risky:
            add(
                "info",
                "risco",
                "Commit toca áreas sensíveis e merece teste físico de reprodução/Cast.",
                ", ".join(risky),
            )
    workflow = text(".github/workflows/build.yml")
    if "flutter create --platforms=android ." in workflow:
        add(
            "warning",
            "build",
            "O CI ainda recria o scaffold Android a cada build; funciona, mas reduz reprodutibilidade.",
        )

def audit_intro():
    intro = ROOT / "assets/rocha_intro_v2.mp4"
    source = text("lib/src/screens/intro_screen.dart")
    if not intro.exists():
        add("critical", "intro", "Vinheta real de abertura ausente.")
        return
    data = intro.read_bytes()
    if len(data) < 200000 or b"ftyp" not in data[:64]:
        add("critical", "intro", "Arquivo da vinheta parece inválido ou excessivamente comprimido.")
    else:
        add("ok", "intro", "Vinheta real empacotada.", f"{len(data)} bytes")
    if "VideoPlayerController.asset('assets/rocha_intro_v2.mp4')" not in source:
        add("critical", "intro", "A tela de abertura não está conectada ao vídeo real.")
    else:
        add("ok", "intro", "Tela de abertura usa o vídeo real e mantém o ícone separado.")

def audit_auth_state():
    login = text("lib/src/screens/login_screen.dart")
    if "serão conectados às credenciais oficiais" in login:
        add(
            "info",
            "autenticação",
            "Login oficial segue propositalmente pendente para a etapa final.",
        )

def write_reports():
    order = {"critical": 0, "warning": 1, "info": 2, "ok": 3}
    items = sorted(findings, key=lambda item: order.get(item.level, 9))
    counts = {
        level: sum(1 for item in items if item.level == level)
        for level in ("critical", "warning", "info", "ok")
    }
    REPORT_JSON.write_text(json.dumps(
        {
            "name": "Rocha+ Support V1",
            "counts": counts,
            "findings": [asdict(item) for item in items],
        },
        ensure_ascii=False,
        indent=2,
    ) + "\n")

    icons = {"critical": "❌", "warning": "⚠️", "info": "ℹ️", "ok": "✅"}
    lines = [
        "# Rocha+ Support V1",
        "",
        f"Críticos: {counts['critical']} | Avisos: {counts['warning']} | Informações: {counts['info']} | OK: {counts['ok']}",
        "",
    ]
    for item in items:
        lines.append(f"## {icons.get(item.level, '•')} {item.area.title()}")
        lines.append(item.message)
        if item.evidence:
            lines.append("")
            lines.append(item.evidence)
        lines.append("")
    REPORT_MD.write_text("\n".join(lines))
    print("\n".join(lines))
    return 1 if counts["critical"] else 0

def main():
    audit_structure()
    audit_legacy_tokens()
    audit_cast()
    audit_responsive_ui()
    audit_stream_stability()
    audit_scope()
    audit_intro()
    audit_auth_state()
    return write_reports()

if __name__ == "__main__":
    raise SystemExit(main())
