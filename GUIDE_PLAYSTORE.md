# 🚀 Guia Completo - Publicação na Google Play Store

## 📋 Pré-requisitos

### 1. Conta Google Play Console
- Acesse [Google Play Console](https://play.google.com/console)
- Crie uma conta (taxa única de $25 USD)
- Complete a verificação de identidade

### 2. Preparação do App

## 🔧 Configurações Necessárias

### 1. Atualizar `pubspec.yaml`
```yaml
name: ftw_solucoes
description: "Sistema de soluções FTW - Gerenciamento completo de serviços"
publish_to: 'none'  # Mantenha 'none' para apps privados

version: 1.0.0+1  # Incremente a cada release
```

### 2. Configurar `android/app/build.gradle`
```gradle
android {
    namespace = "com.ftw.solucoes"  // Mude para seu domínio
    compileSdk = 36
    
    defaultConfig {
        applicationId = "com.ftw.solucoes"  // ID único do seu app
        minSdkVersion flutter.minSdkVersion
        targetSdk = 36
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }
    
    buildTypes {
        release {
            // IMPORTANTE: Configurar assinatura de release
            signingConfig = signingConfigs.release
            minifyEnabled = true
            proguardFiles getDefaultProguardFile('proguard-android.txt'), 'proguard-rules.pro'
        }
    }
    
    signingConfigs {
        release {
            keyAlias keystoreProperties['keyAlias']
            keyPassword keystoreProperties['keyPassword']
            storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
            storePassword keystoreProperties['storePassword']
        }
    }
}
```

### 3. Criar Keystore para Assinatura
```bash
# Gerar keystore (execute apenas UMA vez)
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload

# Mover para o projeto
mv ~/upload-keystore.jks android/app/upload-keystore.jks
```

### 4. Criar `android/key.properties`
```properties
storePassword=sua_senha_aqui
keyPassword=sua_senha_aqui
keyAlias=upload
storeFile=upload-keystore.jks
```

### 5. Atualizar `android/app/build.gradle`
```gradle
// Adicionar no início do arquivo
def keystoreProperties = new Properties()
def keystorePropertiesFile = rootProject.file('key.properties')
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
}
```

## 🏗️ Preparação para Release

### 1. Testar Build de Release
```bash
# Testar se compila
flutter build apk --release

# Ou para App Bundle (recomendado)
flutter build appbundle --release
```

### 2. Otimizações Recomendadas
```bash
# Limpar cache
flutter clean

# Atualizar dependências
flutter pub get

# Build otimizado
flutter build appbundle --release --target-platform android-arm64
```

## 📱 Preparação de Assets

### 1. Ícones Obrigatórios
- **512x512 px** (Play Store)
- **1024x1024 px** (Play Store)
- **Adaptive Icon** (Android 8.0+)

### 2. Screenshots Obrigatórios
- **Phone**: 1080x1920 px (mínimo 2, máximo 8)
- **7-inch Tablet**: 1200x1920 px
- **10-inch Tablet**: 1920x1200 px

### 3. Imagens Promocionais
- **Feature Graphic**: 1024x500 px
- **Banner**: 320x180 px

## 🎯 Configuração no Google Play Console

### 1. Criar App
1. Acesse [Google Play Console](https://play.google.com/console)
2. Clique em "Criar app"
3. Preencha informações básicas:
   - **Nome do app**: FTW Soluções
   - **Idioma padrão**: Português (Brasil)
   - **App ou game**: App
   - **Gratuito ou pago**: Gratuito

### 2. Configurações do App
```
Informações do app:
- Nome: FTW Soluções
- Descrição curta: Sistema completo de gerenciamento de serviços
- Descrição completa: [Descrição detalhada do seu app]
- Categoria: Negócios
- Tags: gerenciamento, serviços, negócios
```

### 3. Classificação de Conteúdo
- Responda o questionário de classificação
- Defina faixa etária apropriada

### 4. Preços e Distribuição
- **Países**: Selecionar onde distribuir
- **Preço**: Gratuito
- **Disponibilidade**: Disponível para todos

## 📤 Upload do APK/AAB

### 1. Versão Interna (Teste)
1. Vá para "Produção" > "Versões do app"
2. Clique em "Criar nova versão"
3. Faça upload do arquivo `.aab` (App Bundle)
4. Adicione notas de versão
5. Salve e teste

### 2. Versão de Produção
1. Após testes na versão interna
2. Promova para "Produção"
3. Configure rollout gradual (opcional)

## 🔍 Checklist Final

### ✅ Preparação Técnica
- [ ] Keystore configurado
- [ ] `key.properties` criado
- [ ] `build.gradle` atualizado
- [ ] App compila em release
- [ ] Testes passando

### ✅ Assets
- [ ] Ícones em todos os tamanhos
- [ ] Screenshots de todas as telas
- [ ] Feature graphic
- [ ] Descrições em português

### ✅ Google Play Console
- [ ] Conta criada e verificada
- [ ] App criado
- [ ] Informações preenchidas
- [ ] Classificação definida
- [ ] APK/AAB uploadado
- [ ] Política de privacidade (se necessário)

### ✅ Legal
- [ ] Política de privacidade
- [ ] Termos de uso
- [ ] Conformidade com GDPR (se aplicável)

## 🚨 Problemas Comuns

### 1. "App not found" no Firebase
- Verifique se o `applicationId` no `build.gradle` corresponde ao configurado no Firebase

### 2. Erro de assinatura
- Verifique se o `key.properties` está correto
- Confirme se o keystore existe no local correto

### 3. App rejeitado
- Verifique se todas as permissões são necessárias
- Confirme se o app não viola políticas da Google

## 📞 Suporte

- **Google Play Console Help**: https://support.google.com/googleplay/android-developer
- **Flutter Documentation**: https://flutter.dev/docs/deployment/android
- **Firebase Support**: https://firebase.google.com/support

## ⏱️ Timeline Estimada

1. **Preparação técnica**: 1-2 dias
2. **Configuração Play Console**: 1 dia
3. **Upload e revisão**: 1-7 dias (Google Play)
4. **Publicação**: Imediata após aprovação

**Total estimado**: 3-10 dias
