# Rocha+ | Verificador de canais (CMD)

Ferramenta independente, somente leitura. Não remove canais, não modifica o catálogo, não garante reprodução no player Android nem Cast.

## Requisitos
Python 3.10 ou superior. Nenhuma biblioteca externa.

## Windows CMD
Abra o CMD na pasta principal do repositório e execute:

```bat
py -3 tools\channel_health.py --max-channels 20
py -3 tools\channel_health.py --workers 8 --timeout 8
```

O primeiro comando testa 20 URLs para uma verificação rápida. O segundo testa todos os canais únicos das playlists públicas configuradas. Se `py` não estiver disponível, substitua por `python`.

## Outras fontes
```bat
py -3 tools\channel_health.py --playlist "https://exemplo.com/lista.m3u" --output reports\minha_auditoria
```

## Relatórios
Gera `reports/channel_health.json` e `reports/channel_health.csv`. Resultados: `funcionando` (endpoint de mídia respondeu), `instavel` (resposta lenta), `falhou` (ex.: HTTP 404), `inconclusivo` (não comprovado). URL acessível NÃO confirma decodificação de áudio/vídeo nem continuidade da transmissão. Os resultados são observações pontuais, não uma certificação.

Não registre URLs com tokens privados em relatórios públicos. Execute apenas testes em endpoints que você tem permissão para consultar; limite `--workers` caso o servidor imponha limites de requisição.

**Status**: arquivo criado, execução integral ainda não validada em ambiente com internet.
