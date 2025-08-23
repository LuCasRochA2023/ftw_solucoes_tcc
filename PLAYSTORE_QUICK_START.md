# 🚀 Guia Rápido - Google Play Store

## ✅ Status Atual
- ✅ **App compilando**: 25.5MB (tamanho otimizado)
- ✅ **115 testes passando**: 100% de sucesso
- ✅ **Script de preparação**: Funcionando
- ✅ **Estrutura pronta**: Para publicação

## 🎯 Próximos Passos (Ordem de Prioridade)

### 1. 🔐 Configurar Keystore (OBRIGATÓRIO)
```bash
# Gerar keystore (execute UMA vez)
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# Mover para o projeto
mv ~/upload-keystore.jks android/app/upload-keystore.jks

# Criar key.properties
cp android/key.properties.template android/key.properties
# Edite android/key.properties com suas senhas
```

### 2. 📝 Atualizar Configurações
```gradle
// Em android/app/build.gradle, mude:
applicationId = "com.ftw.solucoes"  // Seu domínio real
namespace = "com.ftw.solucoes"
```

### 3. 🎨 Preparar Assets
- **Ícone**: 512x512 px e 1024x1024 px
- **Screenshots**: 1080x1920 px (mínimo 2)
- **Feature Graphic**: 1024x500 px

### 4. 🌐 Google Play Console
1. Acesse [play.google.com/console](https://play.google.com/console)
2. Pague $25 USD (taxa única)
3. Crie o app "FTW Soluções"
4. Faça upload do arquivo `.aab`

## 📁 Arquivos Importantes

### ✅ Já Criados
- `GUIDE_PLAYSTORE.md` - Guia completo
- `scripts/prepare_release.sh` - Script de preparação
- `android/key.properties.template` - Template de keystore

### 📋 Para Criar
- `android/key.properties` - Suas senhas
- `android/app/upload-keystore.jks` - Seu keystore
- Assets (ícones, screenshots)

## ⚡ Comandos Rápidos

```bash
# Preparar para release
./scripts/prepare_release.sh

# Build final para upload
flutter build appbundle --release

# Arquivo gerado
build/app/outputs/bundle/release/app-release.aab
```

## 🚨 Importante

### ⚠️ Segurança
- **NUNCA** commite `key.properties` ou `*.jks`
- Faça backup do keystore
- Use senhas fortes

### 📊 Tamanho do App
- **Atual**: 25.5MB (otimizado)
- **Limite Play Store**: 150MB
- ✅ **Dentro do limite**

### ⏱️ Timeline
- **Configuração**: 1-2 horas
- **Upload**: 10 minutos
- **Revisão Google**: 1-7 dias
- **Publicação**: Imediata após aprovação

## 🆘 Suporte

- **Guia Completo**: `GUIDE_PLAYSTORE.md`
- **Google Play Help**: https://support.google.com/googleplay/android-developer
- **Flutter Docs**: https://flutter.dev/docs/deployment/android

---

**🎉 Seu app está pronto para a Play Store!**
