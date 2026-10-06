# Rocha+ • Inventário de Dados e Permissões

Documento de trabalho para Google Play e App Store. Deve ser revisado novamente quando o login oficial Google/Apple for integrado.

## Estado atual do aplicativo

O Rocha+ ainda não possui autenticação oficial ativa. Os botões de login existentes são placeholders de desenvolvimento e não coletam credenciais.

## Dados armazenados localmente

- Favoritos do usuário: persistidos no aparelho com `shared_preferences`.
- Cache do catálogo de canais: persistido localmente para permitir fallback quando a fonte remota estiver indisponível.
- Não há banco de dados próprio de contas no estado atual da V2.
- Não há coleta de senha no estado atual da V2.

## Rede e conteúdo

- O aplicativo consulta um catálogo remoto de canais públicos/autorizados.
- O player acessa diretamente URLs de mídia dos canais selecionados.
- Para Cast, o aplicativo descobre dispositivos compatíveis na rede local.
- Em alguns fluxos HLS, o aplicativo pode criar temporariamente um relay local no próprio aparelho para facilitar a reprodução em um dispositivo Cast. Esse relay é encerrado ao final/falha da sessão.

## Dados que NÃO estão implementados atualmente

- Analytics próprios.
- Publicidade.
- Rastreamento entre aplicativos.
- Compra dentro do app.
- Geolocalização.
- Lista de contatos.
- Microfone.
- Câmera.
- Upload de fotos ou arquivos pessoais.
- Perfil persistente em servidor.

## Permissões / capacidades Android atuais

- INTERNET: necessária para catálogo, reprodução de vídeo e Cast.
- Google Cast / descoberta de dispositivos compatíveis na rede local por meio do SDK utilizado.
- FOREGROUND_SERVICE_MEDIA_PLAYBACK: utilizada pela infraestrutura de mídia/Cast quando aplicável.
- Compatibilidade Android TV / Google TV com Leanback e touchscreen opcional.

## Antes do lançamento

Revisar este documento depois de:

1. integração do Sign in with Google;
2. integração do Sign in with Apple;
3. definição final de analytics, se houver;
4. definição final de suporte/contato;
5. revisão de todas as permissões no APK/AAB e no build iOS;
6. preenchimento de Data Safety no Google Play;
7. preenchimento de App Privacy no App Store Connect.

## Regra de segurança

CNPJ, documentos pessoais, certificados, chaves de assinatura, client secrets e credenciais nunca devem ser armazenados neste repositório.
