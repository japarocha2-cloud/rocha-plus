#!/usr/bin/env bash
# PRODUCTION Mercado Pago secrets for rocha-plus. Run only with the owner's specific
# authorization, interactively, in a private terminal. Never from CI.
# Same safeguards as tools/homologation/register_mp_secrets.sh, plus: refuses a Mercado
# Pago TEST-user token (production must receive real payments) and prints only the
# receiving account ID (to set ROCHA_CHECKOUT_MERCHANT_ID), never the token.
set +x
set -euo pipefail
umask 077

readonly TARGET_PROJECT='rocha-plus'
if [[ "${1:-}" != '--cadastro-producao-autorizado' ]]; then
  printf '%s\n' 'Nada executado. Exige autorização específica e --cadastro-producao-autorizado.'
  exit 2
fi
if [[ ! -t 0 || ! -t 1 ]]; then
  printf '%s\n' 'Execute interativamente em terminal privado, sem gravação ou compartilhamento.'
  exit 2
fi
command -v gcloud >/dev/null
command -v curl >/dev/null
command -v python3 >/dev/null
actual_project="$(gcloud projects describe "$TARGET_PROJECT" --format='value(projectId)')"
[[ "$actual_project" == "$TARGET_PROJECT" ]] || exit 2
gcloud services list --enabled --project="$TARGET_PROJECT" --filter='name:secretmanager.googleapis.com' \
  --format='value(name)' | grep -q secretmanager || {
  printf '%s\n' 'Secret Manager desativado em rocha-plus. Ativação é uma ação separada que exige autorização.'
  exit 2
}

printf '%s\n' 'Destino fixo: rocha-plus (PRODUÇÃO). Não altera IAM, flags, Functions ou webhooks.'
read -r -p 'Credenciais REAIS da aplicação Mercado Pago revisadas? Digite PRODUCAO-VALIDADA: ' provenance
[[ "$provenance" == 'PRODUCAO-VALIDADA' ]] || exit 2
trap 'unset receiving_input webhook_input receiving_confirm webhook_confirm provenance' EXIT
read -r -s -p 'MP_RECEIVING_ACCESS_TOKEN de produção (entrada oculta): ' receiving_input
printf '\n'
read -r -s -p 'Repita o token (entrada oculta): ' receiving_confirm
printf '\n'
read -r -s -p 'MP_WEBHOOK_SECRET da aplicação de produção (entrada oculta): ' webhook_input
printf '\n'
read -r -s -p 'Repita o segredo de assinatura (entrada oculta): ' webhook_confirm
printf '\n'
[[ -n "$receiving_input" && "$receiving_input" == "$receiving_confirm" ]] || exit 2
[[ -n "$webhook_input" && "$webhook_input" == "$webhook_confirm" ]] || exit 2
[[ "$receiving_input" != "$webhook_input" ]] || exit 2
[[ "$receiving_input" == APP_USR-* ]] || { printf '%s\n' 'Token de produção deve começar com APP_USR-.'; exit 2; }
unset receiving_confirm webhook_confirm

# The token reaches curl through a header file descriptor, never argv or the environment.
account="$(curl -sS --max-time 20 -H @<(printf 'Authorization: Bearer %s\n' "$receiving_input") \
  https://api.mercadopago.com/users/me | python3 -I -c '
import json, sys
d = json.load(sys.stdin)
test = "test_user" in (d.get("tags") or []) or str(d.get("nickname", "")).upper().startswith("TESTUSER")
print(("TESTE" if test else "REAL") + " " + str(d.get("id", "")))')"
case "$account" in
  "REAL "[0-9]*) printf 'Conta recebedora real: %s (use em ROCHA_CHECKOUT_MERCHANT_ID)\n' "${account#REAL }" ;;
  *) printf '%s\n' 'Recusado: o token é de usuário de TESTE ou não foi validado no Mercado Pago.'; exit 2 ;;
esac

gcloud secrets create MP_RECEIVING_ACCESS_TOKEN --project="$TARGET_PROJECT" --replication-policy=automatic --quiet >/dev/null
gcloud secrets create MP_WEBHOOK_SECRET --project="$TARGET_PROJECT" --replication-policy=automatic --quiet >/dev/null
printf '%s' "$receiving_input" | gcloud secrets versions add MP_RECEIVING_ACCESS_TOKEN --project="$TARGET_PROJECT" --data-file=- --quiet >/dev/null
unset receiving_input
printf '%s' "$webhook_input" | gcloud secrets versions add MP_WEBHOOK_SECRET --project="$TARGET_PROJECT" --data-file=- --quiet >/dev/null
unset webhook_input
printf '%s\n' 'Cadastro concluído. Nenhum IAM, deploy, flag ou registro no Mercado Pago foi alterado.'
printf '%s\n' 'Checkout e webhook seguem desligados até a ativação autorizada (docs/release-comercial/producao.env.template).'
