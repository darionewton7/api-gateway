variable "project" {
  description = "Nome do projeto"
  type        = string
}

variable "environment" {
  description = "Ambiente (staging ou production)"
  type        = string
}

variable "vpc_id" {
  description = "ID da VPC"
  type        = string
}

variable "private_subnets" {
  description = "Lista de IDs das subnets privadas"
  type        = list(string)
}

variable "lambda_security_group_id" {
  description = "ID do security group para o Lambda"
  type        = string
}

variable "stripe_api_key" {
  description = "Chave de API do Stripe"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags adicionais para recursos"
  type        = map(string)
  default     = {}
}

locals {
  name = "${var.project}-${var.environment}"
  
  tags = merge(
    {
      Project     = var.project
      Environment = var.environment
      Terraform   = "true"
    },
    var.tags
  )
}

# IAM Role para o Lambda
resource "aws_iam_role" "lambda" {
  name = "${local.name}-payment-lambda-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })
  
  tags = local.tags
}

# Política para o Lambda acessar recursos necessários
resource "aws_iam_policy" "lambda" {
  name        = "${local.name}-payment-lambda-policy"
  description = "Política para o Lambda de processamento de pagamentos"
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "arn:aws:logs:*:*:*"
      },
      {
        Effect = "Allow"
        Action = [
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DeleteNetworkInterface"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue"
        ]
        Resource = aws_secretsmanager_secret.stripe.arn
      }
    ]
  })
  
  tags = local.tags
}

resource "aws_iam_role_policy_attachment" "lambda" {
  role       = aws_iam_role.lambda.name
  policy_arn = aws_iam_policy.lambda.arn
}

# Secret para armazenar a chave de API do Stripe
resource "aws_secretsmanager_secret" "stripe" {
  name        = "${local.name}/stripe-api-key"
  description = "Chave de API do Stripe para o gateway de pagamento"
  
  tags = local.tags
}

resource "aws_secretsmanager_secret_version" "stripe" {
  secret_id     = aws_secretsmanager_secret.stripe.id
  secret_string = jsonencode({
    api_key = var.stripe_api_key
  })
}

# CloudWatch Log Group para o Lambda
resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${local.name}-payment-processor"
  retention_in_days = 30
  
  tags = local.tags
}

# Lambda Function para processamento de pagamentos
resource "aws_lambda_function" "payment_processor" {
  function_name = "${local.name}-payment-processor"
  description   = "Função Lambda para processamento de pagamentos via Stripe"
  
  filename      = "${path.module}/lambda_function.zip"
  handler       = "index.handler"
  runtime       = "nodejs18.x"
  
  role          = aws_iam_role.lambda.arn
  
  memory_size   = 256
  timeout       = 30
  
  vpc_config {
    subnet_ids         = var.private_subnets
    security_group_ids = [var.lambda_security_group_id]
  }
  
  environment {
    variables = {
      STRIPE_SECRET_KEY_ARN = aws_secretsmanager_secret.stripe.arn
      ENVIRONMENT           = var.environment
    }
  }
  
  depends_on = [
    aws_cloudwatch_log_group.lambda,
    aws_iam_role_policy_attachment.lambda
  ]
  
  tags = local.tags
}

# API Gateway para expor o Lambda
resource "aws_apigatewayv2_api" "payment_api" {
  name          = "${local.name}-payment-api"
  protocol_type = "HTTP"
  
  cors_configuration {
    allow_origins = ["*"]
    allow_methods = ["POST", "OPTIONS"]
    allow_headers = ["Content-Type", "Authorization"]
    max_age       = 300
  }
  
  tags = local.tags
}

resource "aws_apigatewayv2_stage" "payment_api" {
  api_id      = aws_apigatewayv2_api.payment_api.id
  name        = var.environment
  auto_deploy = true
  
  access_log_settings {
    destination_arn = aws_cloudwatch_log_group.api_gateway.arn
    format = jsonencode({
      requestId      = "$context.requestId"
      ip             = "$context.identity.sourceIp"
      requestTime    = "$context.requestTime"
      httpMethod     = "$context.httpMethod"
      routeKey       = "$context.routeKey"
      status         = "$context.status"
      protocol       = "$context.protocol"
      responseLength = "$context.responseLength"
      integrationError = "$context.integrationErrorMessage"
    })
  }
  
  tags = local.tags
}

resource "aws_cloudwatch_log_group" "api_gateway" {
  name              = "/aws/apigateway/${local.name}-payment-api"
  retention_in_days = 30
  
  tags = local.tags
}

resource "aws_apigatewayv2_integration" "payment_processor" {
  api_id             = aws_apigatewayv2_api.payment_api.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.payment_processor.invoke_arn
  integration_method = "POST"
  payload_format_version = "2.0"
}

resource "aws_apigatewayv2_route" "payment_processor" {
  api_id    = aws_apigatewayv2_api.payment_api.id
  route_key = "POST /process-payment"
  target    = "integrations/${aws_apigatewayv2_integration.payment_processor.id}"
}

resource "aws_lambda_permission" "api_gateway" {
  statement_id  = "AllowExecutionFromAPIGateway"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.payment_processor.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.payment_api.execution_arn}/*/*"
}

output "payment_api_endpoint" {
  description = "Endpoint da API de pagamento"
  value       = "${aws_apigatewayv2_stage.payment_api.invoke_url}/process-payment"
}

output "lambda_function_name" {
  description = "Nome da função Lambda de processamento de pagamentos"
  value       = aws_lambda_function.payment_processor.function_name
}

output "cloudwatch_log_group" {
  description = "Nome do grupo de logs do CloudWatch para o Lambda"
  value       = aws_cloudwatch_log_group.lambda.name
}
