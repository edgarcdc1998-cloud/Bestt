# Best Player

Best Player é um aplicativo reprodutor de IPTV, VOD (filmes e séries) e canais de TV ao vivo com suporte a EPG, desenvolvido em Flutter para Android.

## Funcionalidades
- Suporte a Xtream Codes API e listas M3U/M3U8.
- Reprodução de alta performance via VLC Player (`flutter_vlc_player_16kb`) compatível com páginas de 16 KB no Android 15+.
- Grade de programação eletrônica (EPG).
- Gerenciamento de favoritos e histórico de reprodução.
- Retomada de posição para filmes e episódios de séries.
- Interface moderna com controles de áudio, legendas, proporção de tela e modo imersivo.

## Assinatura Release e Publicação

Para que novos APKs sejam instalados como atualização sobre versões anteriores (sem exigir desinstalação e preservando todos os dados), o aplicativo obedece à regra do Android:

```
applicationId igual
+
mesma chave de assinatura
+
novo versionCode maior
=
possibilidade de atualização sobre a instalação existente
```

### Gerando a Keystore Release (Executar uma única vez)
```bash
keytool -genkey -v -keystore bestplayer-release.jks -keyalg RSA -keysize 2048 -validity 10000 -alias bestplayer
```

### Configuração no GitHub Actions (Secrets)
Adicione os seguintes segredos no repositório (**Settings > Secrets and variables > Actions**):

1. `ANDROID_KEYSTORE_BASE64`: Conteúdo da keystore codificado em base64 (`base64 -w 0 bestplayer-release.jks` ou `base64 -i bestplayer-release.jks`).
2. `ANDROID_KEYSTORE_PASSWORD`: Senha da keystore.
3. `ANDROID_KEY_ALIAS`: Alias da chave (ex: `bestplayer`).
4. `ANDROID_KEY_PASSWORD`: Senha da chave.

### Configuração Local (`android/key.properties`)
Para builds locais assinados:
```properties
storeFile=../bestplayer-release.jks
storePassword=sua_senha_keystore
keyAlias=bestplayer
keyPassword=sua_senha_chave
```
