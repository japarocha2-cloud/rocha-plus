# Auditoria Flutter — impedimento de integração do gate no LAB

Data: 2026-10-31. Branch: `lab/trial-expiry-isolated-20261031`.

## Código verificado
- `lib/main.dart`: com `ROCHA_LAB_ONLY=true`, executa `RochaLabApp` e **não** `RochaPlusApp`.
- `lib/src/screens/lab_entry_screen.dart`: o `RochaLabApp` carrega o catálogo de laboratório e `PlayerLabScreen`; não instancia `SubscriptionGate`.
- `lib/src/app.dart`: somente o fluxo `RochaPlusApp` instancia `SubscriptionGate` quando `RochaReleasePolicy.paidSubscriptionRequired`.
- `lib/src/app_release_policy.dart`: `ROCHA_EXPERIMENTAL_SUBSCRIPTIONS` habilita a exigência de assinatura no fluxo normal; não muda a seleção de aplicativo em `main.dart`.
- `lib/src/auth/subscription_gate.dart`: permite injetar `verifyAccess`, `recheckInterval`, `stopRemotePlayback` e `playbackPermission`; isso permite ensaio local sem Firebase, desde que a UI do LAB instancie explicitamente o gate.

## Conclusão
O gerador `tools/lab/generate_lab_defines.py` produz configurações pré-validadas, mas **não ativa o gate no RochaLabApp**. Um APK compilado apenas com essas defines não constitui teste físico de expiração. O teste de pré-compilação tampouco prova isolamento de rede em runtime.

## Implementação segura necessária
1. Criar uma tela/entrada específica de laboratório para o `SubscriptionGate`, injetando um `verifyAccess` **local e determinístico** que devolva permitido/negado com relógio fictício controlado dentro do LAB; não usar `SubscriptionAccess.isAllowed` padrão.
2. A tela deve deixar claro que é LAB e não representa assinatura real. Não modificar a identidade visual oficial.
3. Incluir testes Flutter de concessão, expiração, revogação e recuperação, sem repetir testes já verdes de backend.
4. Auditar rede e inicialização nativa Android para garantir que a variante LAB não inicialize Firebase real nem provedores de pagamento.
5. Manter `com.rochaplus.app.candidate` e a candidata .6 completamente intactos; assinar eventual APK LAB apenas com identidade separada aprovada.

## Estado
🟢 Auditoria de rotas Flutter concluída. 🟡 Gate de laboratório não implementado; nenhum APK gerado, instalado ou testado fisicamente. Sem merge/publicação.
