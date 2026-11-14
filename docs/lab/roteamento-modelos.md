# Rocha+ LAB • Roteamento de modelos (fallback) — estudo simulado

Estado: **protótipo simulado**. Nenhum provedor foi chamado, nenhuma chave real existe,
nenhum custo foi gerado.

## O que foi validado (13/11/2026, sessão LAB)
- `tools/lab/model_router_sim.py` com LiteLLM 1.109.1 (venv isolado, fora do repositório).
- Primário forçado a falhar com `RateLimitError` (429) simulado → roteador caiu no
  `rocha-fallback-a` e retornou `SIMULADO: resposta do fallback A`.
- Repetido com proxy de rede apontado para porta inexistente: mesmo resultado, prova de que
  nenhuma requisição externa é feita (`mock_response` + `LITELLM_LOCAL_MODEL_COST_MAP=True`).

## Limites (não pressupor)
- O Claude web/app **não** troca de modelo para GPT/Gemini por plugin; o roteamento só vale
  para clientes que chamam APIs (Claude Code CLI com `ANTHROPIC_BASE_URL`, scripts, CI).
- Assinatura Claude Pro/Max **não** inclui créditos de API. Cada provedor exige chave e
  cobrança próprias; "fallback" para outro provedor gera custo nesse provedor.
- Claude Code Router / LiteLLM proxy traduzem formatos, mas recursos específicos
  (ferramentas, cache de prompt, contexto longo) podem degradar no fallback.
- Não contorna cotas: 429 de um provedor apenas desvia para outro que também tem cota.

## Configuração posterior (exige autorização do responsável)
1. Escolher provedores e orçamentos; criar chaves nos portais oficiais.
2. Guardar chaves como segredos do ambiente (nunca no repositório).
3. Trocar `mock_response` por chaves reais e definir `max_budget`/alertas no LiteLLM.
4. Testar primeiro em ambiente LAB com limite de gasto baixo.
