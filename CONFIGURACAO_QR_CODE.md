# 🔧 Configuração do QR Code - FTW Soluções

## Problema Identificado
O QR code não está aparecendo porque o backend não está rodando e há problemas de configuração.

## 🚨 Erro Específico: "Collector user without key enabled for QR render"

### Causa do Problema
Este erro indica que a conta do Mercado Pago não tem as permissões necessárias para gerar QR codes PIX. Isso pode acontecer por:

1. **Conta não habilitada para PIX**: A conta do Mercado Pago precisa estar habilitada para receber pagamentos PIX
2. **Chaves de API incorretas**: As chaves de acesso (Access Token) podem estar inválidas ou expiradas
3. **Configuração incompleta**: Dados da conta não foram completamente configurados
4. **Ambiente de teste**: Conta em modo sandbox sem permissões para PIX

### Soluções

#### 1. Verificar Configuração da Conta Mercado Pago
```bash
# Acesse o painel do Mercado Pago
# Vá em: Configurações > Credenciais
# Verifique se as chaves estão ativas
```

#### 2. Habilitar PIX na Conta
```bash
# No painel do Mercado Pago:
# 1. Vá em: Configurações > Meios de Pagamento
# 2. Procure por "PIX" e habilite
# 3. Configure os dados bancários
```

#### 3. Verificar Token de Acesso
```bash
# No arquivo .env do backend:
MP_ACCESS_TOKEN=APP_USR-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx

# Teste o token:
curl -X GET "https://api.mercadopago.com/v1/payment_methods" \
  -H "Authorization: Bearer APP_USR-xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

#### 4. Configurar Endpoint de Teste
Adicione ao backend um endpoint para testar a configuração:

```javascript
// backend/routes/config.js
app.get('/config-test', async (req, res) => {
  try {
    const response = await fetch('https://api.mercadopago.com/v1/payment_methods', {
      headers: {
        'Authorization': `Bearer ${process.env.MP_ACCESS_TOKEN}`
      }
    });
    
    if (response.ok) {
      res.json({ status: 'ok', message: 'Mercado Pago configurado corretamente' });
    } else {
      res.status(400).json({ 
        status: 'error', 
        message: 'Token do Mercado Pago inválido ou sem permissões' 
      });
    }
  } catch (error) {
    res.status(500).json({ 
      status: 'error', 
      message: 'Erro ao verificar configuração do Mercado Pago' 
    });
  }
});
```

#### 5. Alternativa: Usar Pagamento com Cartão
Se o PIX não funcionar, o usuário pode usar pagamento com cartão como alternativa.

## ✅ Soluções Implementadas

### 1. Centralização das URLs do Backend
- Criado arquivo `ftw_solucoes/lib/utils/backend_url.dart`
- Todas as URLs hardcoded foram substituídas por referências centralizadas
- Facilita mudança entre desenvolvimento local e produção

### 2. Script de Inicialização do Backend
- Criado `backend/start.sh` para facilitar o início do servidor
- Instala dependências automaticamente
- Cria arquivo `.env` se não existir
- Configura token do Mercado Pago

### 3. Correções no Payment Screen
- Atualizadas todas as URLs hardcoded
- Melhorada a lógica de exibição do QR code
- Adicionados logs para debug
- **NOVO**: Tratamento específico para erro de configuração do Mercado Pago
- **NOVO**: Botão para alternar para pagamento com cartão quando PIX falha
- **NOVO**: Verificação de configuração do Mercado Pago antes de tentar gerar QR

## 🚀 Como Iniciar o Backend

### Opção 1: Usando o Script (Recomendado)
```bash
cd backend
./start.sh
```

### Opção 2: Manual
```bash
cd backend
npm install
npm start
```

## 🔧 Configuração do QR Code

### 1. Verificar se o Backend está Rodando
- Acesse: http://localhost:3001
- Deve retornar uma resposta (mesmo que seja erro 404)

### 2. Testar o Endpoint de Pagamento
```bash
curl -X POST http://localhost:3001/create-payment \
  -H "Content-Type: application/json" \
  -d '{
    "amount": 50.00,
    "description": "Teste PIX",
    "payer": {
      "email": "teste@email.com",
      "firstName": "Teste",
      "lastName": "Usuario",
      "cpf": "12345678900"
    }
  }'
```

### 3. Verificar Logs do Backend
O backend deve mostrar logs como:
```
=== DEBUG: Recebendo requisição de pagamento ===
=== DEBUG: Enviando dados para Mercado Pago ===
=== DEBUG: Resposta do Mercado Pago ===
```

## 📱 Configuração do Flutter

### 1. URL do Backend
No arquivo `ftw_solucoes/lib/utils/backend_url.dart`:

```dart
// Para desenvolvimento local
static String get baseUrl {
  return localUrl; // http://localhost:3001
}
```

### 2. Para Emulador Android
```dart
// Para emulador Android
static String get baseUrl {
  return androidEmulatorUrl; // http://10.0.2.2:3001
}
```

### 3. Para Dispositivo Físico
```dart
// Para dispositivo físico (substitua pelo seu IP)
static String get baseUrl {
  return deviceUrl; // http://192.168.1.100:3001
}
```

## 🔍 Debug do QR Code

### 1. Verificar Logs do Flutter
No console do Flutter, procure por:
```
=== DEBUG: Iniciando requisição para criar pagamento PIX ===
URL: http://localhost:3001/create-payment
QR recebido: [dados do QR]
```

### 2. Verificar Resposta do Backend
O backend deve retornar:
```json
{
  "id": "123456789",
  "status": "pending",
  "point_of_interaction": {
    "transaction_data": {
      "qr_code": "00020126580014br.gov.bcb.pix0136...",
      "qr_code_base64": "iVBORw0KGgoAAAANSUhEUgAA..."
    }
  }
}
```

### 3. Verificar Exibição do QR Code
No `payment_screen.dart`, o QR code é exibido quando:
- `_pixQrCode != null`
- `_pixQrCode!.isNotEmpty`

## 🐛 Problemas Comuns

### 1. "QR Code não recebido"
- Verificar se o backend está rodando
- Verificar logs do backend
- Verificar se o token do Mercado Pago está correto

### 2. "Erro ao criar pagamento"
- Verificar se todos os parâmetros estão sendo enviados
- Verificar se o CPF está no formato correto
- Verificar se o email é válido

### 3. "Connection refused"
- Verificar se o backend está na porta correta
- Verificar se a URL está correta para o ambiente
- Verificar firewall/antivírus

### 4. "Collector user without key enabled for QR render" ⚠️ NOVO
- **Causa**: Conta do Mercado Pago sem permissões para PIX
- **Solução**: Habilitar PIX na conta do Mercado Pago
- **Alternativa**: Usar pagamento com cartão
- **Debug**: Verificar token de acesso e configuração da conta

## ✅ Checklist de Configuração

- [ ] Backend rodando na porta 3001
- [ ] Arquivo `.env` criado com token do Mercado Pago
- [ ] Dependências do backend instaladas
- [ ] URL do backend configurada corretamente no Flutter
- [ ] **NOVO**: Conta do Mercado Pago habilitada para PIX
- [ ] **NOVO**: Token de acesso válido e com permissões
- [ ] Teste de pagamento funcionando
- [ ] QR code aparecendo na tela
- [ ] Logs de debug funcionando

## 🎯 Próximos Passos

1. Iniciar o backend usando `./start.sh`
2. **NOVO**: Verificar se a conta do Mercado Pago está habilitada para PIX
3. **NOVO**: Testar a configuração com endpoint `/config-test`
4. Testar um pagamento PIX
5. Verificar se o QR code aparece
6. Se não aparecer, verificar logs de debug
7. **NOVO**: Se PIX falhar, usar pagamento com cartão como alternativa
8. Ajustar configurações conforme necessário 