## Segunda etapa: triagem do CSV (sem rede, sem exclusões)

Depois de executar `tools/channel_health.py`, classifique as observações:

```bat
python tools\channel_triage.py
```

Saídas: `reports/channel_triage.csv` e `reports/channel_triage.json`.

Categorias:
- `prioridade_player`: mídia acessível no HTTP; testar vídeo/áudio no app.
- `retestar_lentidao`: resposta lenta; repetir teste.
- `acesso_restrito`: HTTP 401/403, NÃO representa necessariamente canal fora do ar.
- `link_nao_encontrado`: HTTP 404/410; confirmar no player ou fonte antes de decisão.
- `retestar_http`, `retestar_inconclusivo`, `investigar_falha`: precisam de diagnóstico adicional.

Os dados refletem apenas o momento da coleta. O comando não modifica o catálogo e não remove canais.

Para rodar os testes unitários a partir da raiz do projeto:

```bat
python -m unittest discover -s tests -p test_channel_triage.py
```
