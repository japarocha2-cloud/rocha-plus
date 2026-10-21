#!/usr/bin/env python3
"""Static guard for Rocha+ site preview. Runs without network access or secrets."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[1]
tv = (root / "web/assinaturas/index.html").read_text(encoding="utf-8")
office = (root / "web/estudando-empresas/index.html").read_text(encoding="utf-8")
firebase = (root / "web/assets/firebase-config.js").read_text(encoding="utf-8")
checks = {
    "TV mensal preço": "R$ 4,50" in tv,
    "TV mensal link": 'href="https://mpago.la/32m6qxz"' in tv,
    "TV anual preço": "R$ 49,50" in tv,
    "TV anual link": 'href="https://mpago.la/1CKFRB2"' in tv,
    "TV anual sem preço antigo": "R$ 53,90" not in tv,
    "Office compra única preço": "R$ 49,90" in office,
    "Office link exclusivo": 'href="https://mpago.la/2KWTnPa"' in office,
    "Office link não confundido com TV": "mpago.la/2KWTnPa" not in tv,
    "Links TV não aparecem no Office": all(x not in office for x in ("mpago.la/32m6qxz", "mpago.la/1CKFRB2")),
    "Menu TV aponta Office": "../estudando-empresas/index.html" in tv,
    "Menu Office aponta TV": "../assinaturas/index.html" in office,
    "Login nas duas páginas": all('id="google-signin"' in x for x in (tv, office)),
    "Logout nas duas páginas": all('id="google-signout"' in x for x in (tv, office)),
    "Firebase configuração web importada": all("../assets/firebase-config.js" in x for x in (tv, office)),
    "Firebase projeto Rocha+ confirmado": 'projectId: "rocha-plus"' in firebase,
    "Firebase Web authDomain correto": 'authDomain: "rocha-plus.firebaseapp.com"' in firebase,
    "Firebase Web appId registrado": 'appId: "1:977269532083:web:bd469df549034d603f97c6"' in firebase,
    "Firebase Web sem placeholder": "SUBSTITUIR_" not in firebase,
    "Google provider registrado": all("new GoogleAuthProvider()" in x for x in (tv, office)),
    "Erro de domínio não autorizado explicado": all("auth/unauthorized-domain" in x for x in (tv, office)),
    "Erro Google desabilitado explicado": all("auth/operation-not-allowed" in x for x in (tv, office)),
    "Erro de rede explicado": all("auth/network-request-failed" in x for x in (tv, office)),
    "Sessão autenticada monitorada": all("onAuthStateChanged(auth" in x for x in (tv, office)),
    "Sessão permite saída": all("await signOut(auth)" in x for x in (tv, office)),
    "Sem chaves privadas nas páginas": all(not re.search(r"-----BEGIN (RSA |EC |OPENSSH )?PRIVATE KEY-----|access_token\\s*[:=]|client_secret\\s*[:=]", x, re.I) for x in (tv, office)),
    "Nenhuma liberação automática prometida": all("não" in x.lower() and "automaticamente" in x.lower() for x in (tv, office)),
}
for label, ok in checks.items():
    print(("OK" if ok else "FALHOU") + " - " + label)
raise SystemExit(0 if all(checks.values()) else 1)
