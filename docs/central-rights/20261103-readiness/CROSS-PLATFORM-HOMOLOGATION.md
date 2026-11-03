# Roteiro cruzado e integração futura

Template de24casos em cross-platform-results-template.json: todos NOT_EXECUTED. Não é autorização de teste físico ou ativação. Roteiro físico anterior21casos preservado em docs/roku/technical-followup-20261102/ROTEIRO-TESTE-FISICO.md. Usar evidências anteriores para não repetir resultados sem causa; os24casos descrevem a futura rodada cruzada após condições satisfeitas.

## Portões anteriores à execução

- Confirmar hostLAB, acesso de rede nos aparelhos, origem e certificado confiável, IAM mínimo próprio e LABFirestore comprovado. Auditoria atual não confirma esses itens.
- Manter disabledaté autorização exata do proprietário para host/configuração de clientes e grant por conta/prazo absolutos. Não criar grant a partir do histórico de pagamentos. Se o domínio necessário não estiver autorizado, qualquer alteração de Auth comercial exige aprovação específica separada.
- Identificar dispositivos, firmware, rede, fontes/artefatos/hashes e referência privada de autorização; exportar dados somente com custódia privada. Jamais logs de tokens ou rawregistry noGitHub.
- ZIP0.6.7 permanece desativado e anterior ao ajuste do carrossel; não exigir essa alteração visual nesse pacote como se já estivesse instalada. Novo pacote só em etapa autorizada.

## Android experimental — plano pronto, não aplicado

android-integration-plan.json fixa base e SHA256 anterior/posterior dos dois arquivos do overlay. Conferir a branch experimental e os bytes esperados antes de copiar; se houver divergência, parar aplicação e revisar em vez de sobrescrever trabalho novo. Aplicar apenas com autorização futura nessa branch, executar os dois testes novos/relacionados, análise e contrato9vetores compartilhados conforme CI41590689968 (36verdes). Não tocar oficial/C6/LAB714, não gerarAPK. Runtime já usa check()->status neutro e clear()->stop/logout; overlay corrige o corpo enviado. Manter ROCHA_CENTRAL_RIGHTS=false até autorização. Nada foi aplicado nesta missão.

## Vinculação preparada e lacunas

Código atual:8caracteres alfanuméricos/10min, não numérico. QR não implementado. Preparação confirma fluxo manual comfixtures; não autentica conta real. Não reduzir entropia/mudar contrato silenciosamente para cumprir rótulo numérico. Se proprietário exigir numérico ouQR, decidir formato, limite/rate e UX numa mudança posterior testada. QR deverá conter URLHTTPS de aprovação/código público curto, nunca session_token/device_code/IDtoken. Permitir conferência explícita na tela do celular antes de aprovar.

Fluxo: startTV->pending->Googleloginrecente/register_mobile->aprovação explícita->pollsessão->statusdireitos->leaseplayback->player. Repetir poll após resposta perdida deve manter mesma sessão. Backendscopehomologation não usa paid/trial para abrirLAB. Uma sessãoTV24h não substitui grant/lease60s. Revogaçãoglobal é consultada no refresh.

## Medições e classificação

Status válidos: APPROVED_FIXTURE, APPROVED_SIMULATOR, APPROVED_HARDWARE, PARTIAL, FAILED, BLOCKED, NOT_EXECUTED. Registrar imagem/áudio separadamente; FPS/RAM só por instrumento real com unidade e série antes/depois no mesmo aparelho. EndpointFPSzero doBRS não serve. Em stop, registrar estado decoder/receiver e horário da liberação da vaga; lacuna de sincronização física permanece. Não classificar testes de mocks como mídia real.

## Canais e capas

607registros técnicos/599runtime,578associações/534texturas. Isso não é quantidade de canais aprovados fisicamente. CSV atual29pendências em docs/roku/technical-followup-20261102/pending-covers.csv; motivos10HTTP403,4HTTP404,3TLS/DNS,5identidadessem logo,7sem identidadeexata. Não repetir downloads sem fonte nova, não desabilitarTLS. Arquivo antigo30pendências é histórico, preservado. CatálogoC6 final e exclusões01/11 continuam sem evidência recuperada; nenhuma nova reconstrução nesta missão. Grupos desconhecidos vão aOutros pelo códigoexistente; nenhuma reclassificação criada.

channel-review-template.csv é vazio, só cabeçalho. Futuras reprovações exigem IDoriginal, nome/categoria, motivo, aparelho/firmware, data e evidência; ausência de imagem não é reprovação do canal. O exportexistente decheckupJSONv2/CSV ajuda, mas não inclui todo contexto/motivo: anexar evidência. Arquivar proposta e revisão sem apagar catálogo, restaurar canais removidos ou alterar homologaçãoC6. Não preencher decisões com suposições.

## Próxima autorização necessária

Precisamos de aprovação concreta para infraestrutura/host/certificado/projetoLAB e configuração de clientes, com recursos/custos/escopo conhecidos; nesta missão nenhum recurso foi contratado. Depois, autorização exata de grant temporário e testes físicos nos aparelhos identificados. Riscos: expor endpoint e tokens se TLS/origem/IAM inadequados, escrita cruzada se credenciais comerciais reutilizadas, concessão indevida se grant sem conta/prazo e concorrência física de stream não comprovada. A auditoriaCI revelou permissões comerciais de escrita da identidade existente; não copiá-la ao host. Não pedir segredos nochat.
