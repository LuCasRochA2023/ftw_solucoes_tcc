#!/bin/bash

# 🚀 Script de Preparação para Release - Google Play Store
# Execute este script para preparar seu app para publicação

echo "🚀 Preparando app para release na Google Play Store..."

# 1. Limpar cache
echo "📦 Limpando cache..."
flutter clean

# 2. Atualizar dependências
echo "📥 Atualizando dependências..."
flutter pub get

# 3. Executar testes
echo "🧪 Executando testes..."
flutter test

# 4. Verificar se há erros de lint
echo "🔍 Verificando código..."
flutter analyze

# 5. Build de teste
echo "🏗️ Testando build de release..."
flutter build appbundle --release --target-platform android-arm64

# 6. Verificar tamanho do arquivo
echo "📊 Informações do build:"
ls -lh build/app/outputs/bundle/release/app-release.aab

echo ""
echo "✅ Preparação concluída!"
echo ""
echo "📋 Próximos passos:"
echo "1. Configure o keystore (veja GUIDE_PLAYSTORE.md)"
echo "2. Atualize o applicationId no build.gradle"
echo "3. Crie conta no Google Play Console"
echo "4. Faça upload do arquivo .aab"
echo ""
echo "📁 Arquivo gerado: build/app/outputs/bundle/release/app-release.aab"
