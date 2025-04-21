# Configuração de Secrets do GitHub

Para que os workflows do GitHub Actions funcionem corretamente, é necessário configurar os seguintes secrets no repositório:

## Secrets Globais

- `AWS_ACCESS_KEY_ID`: ID da chave de acesso da AWS
- `AWS_SECRET_ACCESS_KEY`: Chave secreta de acesso da AWS
- `SLACK_WEBHOOK_URL`: URL do webhook do Slack para notificações

## Secrets do Ambiente de Staging

- `DB_PASSWORD_STAGING`: Senha do banco de dados para o ambiente de staging
- `STRIPE_API_KEY_STAGING`: Chave de API do Stripe para o ambiente de staging

## Secrets do Ambiente de Production

- `DB_PASSWORD_PRODUCTION`: Senha do banco de dados para o ambiente de produção
- `STRIPE_API_KEY_PRODUCTION`: Chave de API do Stripe para o ambiente de produção

## Como configurar

1. Acesse o repositório no GitHub
2. Vá para "Settings" > "Secrets and variables" > "Actions"
3. Clique em "New repository secret" para adicionar os secrets globais
4. Para adicionar secrets específicos de ambiente:
   - Vá para "Settings" > "Environments"
   - Crie os ambientes "staging" e "production" se ainda não existirem
   - Adicione os secrets específicos para cada ambiente
