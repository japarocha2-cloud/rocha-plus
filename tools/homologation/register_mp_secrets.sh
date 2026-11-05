#!/usr/bin/env bash
# Preparation only. Run later in an authorized Cloud Shell, never from CI.
set +x
set -euo pipefail
umask 077

readonly TARGET_PROJECT='rocha-plus-homologacao'
if [[ "${1:-}" != '--cadastro-autorizado' ]]; then
  printf '%s\n' 'Nada executado. Exige autorização específica de cadastro e argumento --cadastro-autorizado.'
  exit 2
fi
if [[ ! -t 0 || ! -t 1 ]]; then
  printf '%s\n' 'Execute interativamente em terminal privado, sem gravação ou compartilhamento.'
  exit 2
fi
command -v gcloud >/dev/null
actual_project="$(gcloud projects describe "$TARGET_PROJECT" --format='value(projectId)')"
[[ "$actual_project" == "$TARGET_PROJECT" ]] || exit 2

printf '%s\n' 'Destino fixo: rocha-plus-homologacao.'
printf '%s\n' 'Não copia secrets do GitHub/produção. Não altera IAM, flags, Functions ou webhooks.'
read -r -p 'Credenciais da integração/ambiente de homologação foram revisadas separadamente? Digite HOMOLOGACAO-VALIDADA: ' provenance
[[ "$provenance" == 'HOMOLOGACAO-VALIDADA' ]] || exit 2
trap 'unset receiving_input webhook_input receiving_confirm webhook_confirm provenance' EXIT
read -r -s -p 'MP_RECEIVING_ACCESS_TOKEN (entrada oculta): ' receiving_input
printf '\n'
read -r -s -p 'Repita o token (entrada oculta): ' receiving_confirm
printf '\n'
read -r -s -p 'MP_WEBHOOK_SECRET oficial (entrada oculta): ' webhook_input
printf '\n'
read -r -s -p 'Repita o segredo de assinatura (entrada oculta): ' webhook_confirm
printf '\n'
[[ -n "$receiving_input" && "$receiving_input" == "$receiving_confirm" ]] || exit 2
[[ -n "$webhook_input" && "$webhook_input" == "$webhook_confirm" ]] || exit 2
[[ "$receiving_input" != "$webhook_input" ]] || exit 2
unset receiving_confirm webhook_confirm

# Creates only these two containers. An existing secret or permission failure stops
# execution before adding versions; do not bypass or add versions to existing secrets.
gcloud secrets create MP_RECEIVING_ACCESS_TOKEN --project="$TARGET_PROJECT" --replication-policy=automatic --quiet >/dev/null
gcloud secrets create MP_WEBHOOK_SECRET --project="$TARGET_PROJECT" --replication-policy=automatic --quiet >/dev/null
# Values travel over stdin, never command arguments, environment or temporary files.
printf '%s' "$receiving_input" | gcloud secrets versions add MP_RECEIVING_ACCESS_TOKEN --project="$TARGET_PROJECT" --data-file=- --quiet >/dev/null
unset receiving_input
printf '%s' "$webhook_input" | gcloud secrets versions add MP_WEBHOOK_SECRET --project="$TARGET_PROJECT" --data-file=- --quiet >/dev/null
unset webhook_input
printf '%s\n' 'Cadastro concluído. Nenhum IAM, deploy, flag ou registro no Mercado Pago foi alterado.'
printf '%s\n' 'Manter ROCHA_CHECKOUT_ENABLED=false e ROCHA_WEBHOOK_RECONCILIATION_ENABLED=false.'
