const AWS = require('aws-sdk');
const secretsManager = new AWS.SecretsManager();
const stripe = require('stripe');

let stripeClient = null;

/**
 * Inicializa o cliente Stripe com a chave API armazenada no AWS Secrets Manager
 */
async function initializeStripe() {
  if (stripeClient) {
    return stripeClient;
  }

  try {
    // Recupera a chave API do Stripe do Secrets Manager
    const secretData = await secretsManager.getSecretValue({
      SecretId: process.env.STRIPE_SECRET_KEY_ARN
    }).promise();
    
    const secretString = JSON.parse(secretData.SecretString);
    const apiKey = secretString.api_key;
    
    // Inicializa o cliente Stripe
    stripeClient = stripe(apiKey);
    
    console.log('Cliente Stripe inicializado com sucesso');
    return stripeClient;
  } catch (error) {
    console.error('Erro ao inicializar o cliente Stripe:', error);
    throw new Error('Falha ao inicializar o gateway de pagamento');
  }
}

/**
 * Processa um pagamento via Stripe
 */
async function processPayment(paymentData) {
  try {
    const stripe = await initializeStripe();
    
    // Cria um token de pagamento
    const paymentMethod = await stripe.paymentMethods.create({
      type: 'card',
      card: {
        number: paymentData.cardNumber,
        exp_month: paymentData.expMonth,
        exp_year: paymentData.expYear,
        cvc: paymentData.cvc
      }
    });
    
    // Cria um cliente (opcional, mas útil para pagamentos recorrentes)
    const customer = await stripe.customers.create({
      email: paymentData.email,
      name: paymentData.name,
      payment_method: paymentMethod.id
    });
    
    // Cria a intenção de pagamento
    const paymentIntent = await stripe.paymentIntents.create({
      amount: paymentData.amount, // em centavos
      currency: paymentData.currency || 'brl',
      customer: customer.id,
      payment_method: paymentMethod.id,
      description: paymentData.description || 'Compra online',
      confirm: true,
      return_url: paymentData.returnUrl,
      metadata: {
        orderId: paymentData.orderId,
        environment: process.env.ENVIRONMENT
      }
    });
    
    console.log('Pagamento processado com sucesso:', paymentIntent.id);
    
    return {
      success: true,
      paymentIntentId: paymentIntent.id,
      status: paymentIntent.status,
      clientSecret: paymentIntent.client_secret
    };
  } catch (error) {
    console.error('Erro ao processar pagamento:', error);
    
    return {
      success: false,
      error: error.message,
      code: error.code || 'unknown_error'
    };
  }
}

/**
 * Função principal do Lambda
 */
exports.handler = async (event) => {
  console.log('Evento recebido:', JSON.stringify(event));
  
  try {
    // Verifica se o corpo da requisição está presente
    if (!event.body) {
      return formatResponse(400, { error: 'Corpo da requisição ausente' });
    }
    
    // Parse do corpo da requisição
    const body = JSON.parse(event.body);
    
    // Validação básica dos dados de pagamento
    if (!body.cardNumber || !body.expMonth || !body.expYear || !body.cvc || !body.amount) {
      return formatResponse(400, { error: 'Dados de pagamento incompletos' });
    }
    
    // Processa o pagamento
    const result = await processPayment(body);
    
    if (result.success) {
      return formatResponse(200, result);
    } else {
      return formatResponse(400, result);
    }
  } catch (error) {
    console.error('Erro ao processar a requisição:', error);
    return formatResponse(500, { error: 'Erro interno do servidor' });
  }
};

/**
 * Formata a resposta da API
 */
function formatResponse(statusCode, body) {
  return {
    statusCode,
    headers: {
      'Content-Type': 'application/json',
      'Access-Control-Allow-Origin': '*',
      'Access-Control-Allow-Headers': 'Content-Type,Authorization',
      'Access-Control-Allow-Methods': 'POST,OPTIONS'
    },
    body: JSON.stringify(body)
  };
}
