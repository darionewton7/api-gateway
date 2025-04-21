# Projeto DevOps com AWS, Terraform e GitHub Actions

## Visão Geral

Este projeto implementa uma solução completa de DevOps que inclui:

1. **Infraestrutura como Código (IaC)** usando Terraform para provisionar recursos na AWS
2. **Gateway de Pagamento** integrado com Stripe para processamento de transações
3. **Pipeline CI/CD** automatizado usando GitHub Actions para testes, validação e deploy

A solução foi projetada seguindo as melhores práticas de DevOps, com foco em segurança, escalabilidade e automação.

## Arquitetura

![Arquitetura](diagrama-arquitetura.png)

### Componentes Principais

- **VPC**: Rede isolada com subnets públicas e privadas em múltiplas zonas de disponibilidade
- **ECS/Fargate**: Serviço gerenciado para execução de containers
- **RDS**: Banco de dados relacional gerenciado para armazenamento de dados
- **Lambda**: Função serverless para processamento de pagamentos
- **API Gateway**: Endpoint HTTP para integração com o gateway de pagamento
- **S3**: Armazenamento de estado do Terraform e logs
- **CloudWatch**: Monitoramento e logs
- **GitHub Actions**: Pipeline CI/CD para automação de testes e deploy

## Estrutura do Projeto

```
devops-project/
├── terraform/
│   ├── modules/
│   │   ├── vpc/
│   │   ├── security/
│   │   ├── ecs/
│   │   ├── alb/
│   │   ├── rds/
│   │   ├── terraform-state/
│   │   └── payment-gateway/
│   └── environments/
│       ├── staging/
│       └── production/
├── payment-gateway/
│   ├── index.js
│   ├── index.test.js
│   ├── package.json
│   ├── package.sh
│   └── test.sh
├── .github/
│   ├── workflows/
│   │   ├── ci-cd.yml
│   │   ├── terraform-lint.yml
│   │   ├── payment-tests.yml
│   │   ├── security-scan.yml
│   │   └── drift-detection.yml
│   └── SECRETS.md
└── test-solution.sh
```

## Infraestrutura como Código (Terraform)

### Módulos

1. **VPC**: Configura a rede virtual com subnets públicas e privadas, Internet Gateway, NAT Gateway, tabelas de rotas e NACLs.

2. **Security**: Define grupos de segurança para controle de tráfego entre os componentes.

3. **ECS**: Configura o cluster ECS/Fargate para execução de containers, incluindo IAM roles e CloudWatch logs.

4. **ALB**: Configura o Application Load Balancer para distribuição de tráfego, incluindo listeners HTTP/HTTPS e logs.

5. **RDS**: Configura o banco de dados PostgreSQL gerenciado, incluindo subnet groups, parameter groups e backups.

6. **Terraform-State**: Configura o armazenamento remoto do estado do Terraform usando S3 e DynamoDB.

7. **Payment-Gateway**: Configura a função Lambda e API Gateway para processamento de pagamentos.

### Ambientes

- **Staging**: Ambiente de homologação com configurações otimizadas para custo (single NAT Gateway, RDS sem Multi-AZ).
- **Production**: Ambiente de produção com configurações otimizadas para alta disponibilidade (múltiplos NAT Gateways, RDS com Multi-AZ).

## Gateway de Pagamento

O gateway de pagamento é implementado como uma função Lambda que se integra com a API do Stripe para processamento de transações. A função:

1. Recebe dados de pagamento via API Gateway
2. Valida os dados recebidos
3. Recupera a chave de API do Stripe do AWS Secrets Manager
4. Processa o pagamento usando a API do Stripe
5. Retorna o resultado da transação

### Segurança

- Chaves de API armazenadas no AWS Secrets Manager
- Função Lambda executada dentro da VPC em subnets privadas
- Acesso controlado por IAM roles com permissões mínimas necessárias
- Logs detalhados no CloudWatch para auditoria

## Pipeline CI/CD

O pipeline CI/CD é implementado usando GitHub Actions e inclui:

### Workflows Principais

1. **CI/CD Pipeline (ci-cd.yml)**:
   - Executa testes automatizados
   - Valida configurações do Terraform
   - Planeja e aplica mudanças de infraestrutura
   - Faz deploy da função Lambda
   - Notifica sobre o status do pipeline

2. **Terraform Lint (terraform-lint.yml)**:
   - Verifica a qualidade e conformidade do código Terraform

3. **Payment Tests (payment-tests.yml)**:
   - Executa testes específicos do gateway de pagamento

4. **Security Scan (security-scan.yml)**:
   - Verifica vulnerabilidades nas dependências
   - Analisa a segurança das configurações do Terraform

5. **Drift Detection (drift-detection.yml)**:
   - Detecta diferenças entre a infraestrutura atual e o estado desejado no Terraform

### Ambientes

O pipeline suporta dois ambientes:
- **Staging**: Ativado automaticamente em merges para a branch `develop`
- **Production**: Ativado automaticamente em merges para a branch `main`

### Secrets

Os secrets necessários para o pipeline estão documentados em `.github/SECRETS.md`.

## Como Usar

### Pré-requisitos

- Conta AWS
- Conta Stripe
- Repositório GitHub

### Configuração Inicial

1. Clone o repositório:
   ```
   git clone https://github.com/seu-usuario/devops-project.git
   cd devops-project
   ```

2. Configure os secrets no GitHub conforme documentado em `.github/SECRETS.md`.

3. Inicialize o estado remoto do Terraform:
   ```
   cd terraform/environments/staging
   terraform init
   ```

4. Aplique a infraestrutura de staging:
   ```
   terraform apply
   ```

5. Repita os passos 3 e 4 para o ambiente de produção.

### Fluxo de Trabalho

1. Desenvolva novas features em branches de feature:
   ```
   git checkout -b feature/nova-funcionalidade
   ```

2. Faça commit das mudanças e abra um Pull Request para a branch `develop`.

3. O pipeline CI/CD executará automaticamente os testes e validações.

4. Após aprovação, faça merge do PR para `develop` para deploy em staging.

5. Teste as mudanças no ambiente de staging.

6. Abra um PR de `develop` para `main` para deploy em produção.

7. Após aprovação, faça merge do PR para `main` para deploy em produção.

## Monitoramento e Manutenção

### Logs

- Logs da função Lambda: CloudWatch Logs (`/aws/lambda/payment-gateway-{environment}-payment-processor`)
- Logs do ALB: S3 (`{environment}-alb-logs`)
- Logs do API Gateway: CloudWatch Logs (`/aws/apigateway/payment-gateway-{environment}-payment-api`)

### Alertas

- Configure alertas no CloudWatch para monitorar:
  - Erros na função Lambda
  - Latência da API
  - Utilização de recursos do RDS
  - Falhas no pipeline CI/CD

### Backup e Recuperação

- Backups do RDS são configurados automaticamente
- Estado do Terraform é versionado no S3
- Código fonte é versionado no GitHub

## Considerações de Segurança

1. **Rotação de Credenciais**: Implemente rotação regular de credenciais da AWS e do Stripe.

2. **Atualizações de Segurança**: Mantenha as dependências atualizadas usando o workflow de security scan.

3. **Princípio do Privilégio Mínimo**: Todas as IAM roles seguem o princípio do privilégio mínimo.

4. **Criptografia**: Dados em repouso e em trânsito são criptografados.

5. **Segmentação de Rede**: Componentes sensíveis estão em subnets privadas.

## Conclusão

Esta solução DevOps fornece uma base sólida para desenvolvimento, teste e deploy contínuos de aplicações com processamento de pagamentos. A arquitetura é segura, escalável e automatizada, seguindo as melhores práticas da indústria.

---

## Apêndice

### Comandos Úteis

#### Terraform

```bash
# Inicializar
terraform init

# Validar
terraform validate

# Planejar mudanças
terraform plan

# Aplicar mudanças
terraform apply

# Destruir infraestrutura
terraform destroy
```

#### GitHub Actions

```bash
# Executar workflow manualmente
gh workflow run ci-cd.yml

# Verificar status dos workflows
gh run list

# Visualizar logs de uma execução
gh run view <run-id> --log
```

#### AWS CLI

```bash
# Listar funções Lambda
aws lambda list-functions

# Invocar função Lambda
aws lambda invoke --function-name payment-gateway-staging-payment-processor output.json

# Verificar logs
aws logs get-log-events --log-group-name /aws/lambda/payment-gateway-staging-payment-processor
```
