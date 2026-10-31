# Rocha+ TV — roteiro físico da candidata (pré-homologação)

**Status:** roteiro preparado; **nenhum teste físico executado por este documento**. Aplicar somente após APK candidato assinado e verificado com ferramentas Android reais. Manter PR #42 e PR #44 draft, sem merge, deploy, publicação ou cobrança real.

## Entrada obrigatória
- [ ] APK `com.rochaplus.app.candidate`, versão `0.1.0-candidate.1`, versionCode `1`, SHA-256 do arquivo registrado.
- [ ] Certificado SHA-1/SHA-256 do APK corresponde ao certificado público da candidata.
- [ ] Configuração Firebase/OAuth da candidata validada em ambiente privado; nenhuma credencial em logs.
- [ ] Instalar no aparelho de teste autorizado, sem substituir a versão oficial.

## Cenários ainda pendentes
| Área | Ação | Evidência mínima |
| --- | --- | --- |
| Instalação e login | Instalar APK candidato e autenticar em ambiente de teste | Resultado, modelo Android, versão do APK |
| Navegação TV | Percorrer abas com controle remoto; foco, voltar e recuperação | Caminho e eventual falha reproduzível |
| LibVLC e ExoPlayer | Abrir mídias de teste autorizadas; alternar engine e recuperar erro | Tipo de mídia, engine, erro e tempo de recuperação |
| Reprodução contínua | Manter mídia de teste reproduzindo por janela acordada | Duração, interrupções e resultado |
| Chromecast | Iniciar Cast MP4 180s, reconectar e confirmar mídia de destino | Estado antes/depois, erro e dispositivo |
| Trial/expiração | Exercitar trial, vencimento exato e gate em sandbox | Relógio, estado esperado/observado, sem pagamentos reais |
| Retorno/estabilidade | Suspender/retomar, alternar rede e voltar à reprodução | Passos e resultado |

**Teste físico nº 6 já aprovado:** preservar congelado; não repetir sem mudança relacionada, regressão observada ou evidência contraditória. Não confundir a numeração desse teste histórico com a ordem dos cenários desta tabela.

## Registro por execução
Data/hora; aparelho e Android; commit; SHA-256 do APK; cenário; passos; esperado; observado; logs sanitizados; 🟢/🟡/🔴; correção/commit; decisão de revalidação. Não marcar verde sem evidência física.

## Bloqueios atuais
Sem acesso ao ambiente privado de assinatura/Firebase até o retorno do Work (previsto pelo usuário para 04/11/2026). Sem APK candidato assinado, este roteiro não é autorização nem evidência de homologação.
