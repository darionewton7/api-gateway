const AWS = require('aws-sdk-mock');
const { handler } = require('./index');

describe('Payment Gateway Lambda', () => {
  beforeEach(() => {
    // Mock do AWS Secrets Manager
    AWS.mock('SecretsManager', 'getSecretValue', (params, callback) => {
      callback(null, {
        SecretString: JSON.stringify({ api_key: 'sk_test_mockStripeKey' })
      });
    });
    
    // Mock do módulo Stripe
    jest.mock('stripe', () => {
      return () => ({
        paymentMethods: {
          create: jest.fn().mockResolvedValue({
            id: 'pm_mock123456789'
          })
        },
        customers: {
          create: jest.fn().mockResolvedValue({
            id: 'cus_mock123456789'
          })
        },
        paymentIntents: {
          create: jest.fn().mockResolvedValue({
            id: 'pi_mock123456789',
            status: 'succeeded',
            client_secret: 'pi_mock123456789_secret_mock987654321'
          })
        }
      });
    });
  });
  
  afterEach(() => {
    AWS.restore();
    jest.resetModules();
  });
  
  test('Deve retornar erro 400 quando o corpo da requisição estiver ausente', async () => {
    const event = {};
    const response = await handler(event);
    
    expect(response.statusCode).toBe(400);
    expect(JSON.parse(response.body)).toHaveProperty('error', 'Corpo da requisição ausente');
  });
  
  test('Deve retornar erro 400 quando os dados de pagamento estiverem incompletos', async () => {
    const event = {
      body: JSON.stringify({
        cardNumber: '4242424242424242',
        // Faltando outros campos obrigatórios
      })
    };
    
    const response = await handler(event);
    
    expect(response.statusCode).toBe(400);
    expect(JSON.parse(response.body)).toHaveProperty('error', 'Dados de pagamento incompletos');
  });
  
  test('Deve processar o pagamento com sucesso', async () => {
    const event = {
      body: JSON.stringify({
        cardNumber: '4242424242424242',
        expMonth: 12,
        expYear: 2025,
        cvc: '123',
        amount: 1000,
        currency: 'brl',
        email: 'cliente@exemplo.com',
        name: 'Cliente Teste',
        description: 'Compra de teste',
        orderId: 'order_123456789'
      })
    };
    
    const response = await handler(event);
    
    expect(response.statusCode).toBe(200);
    const body = JSON.parse(response.body);
    expect(body).toHaveProperty('success', true);
    expect(body).toHaveProperty('paymentIntentId');
    expect(body).toHaveProperty('status', 'succeeded');
    expect(body).toHaveProperty('clientSecret');
  });
  
  test('Deve lidar com erros do Stripe', async () => {
    // Redefine o mock do Stripe para simular um erro
    jest.mock('stripe', () => {
      return () => ({
        paymentMethods: {
          create: jest.fn().mockRejectedValue({
            message: 'Cartão inválido',
            code: 'card_error'
          })
        }
      });
    });
    
    const event = {
      body: JSON.stringify({
        cardNumber: '4242424242424242',
        expMonth: 12,
        expYear: 2025,
        cvc: '123',
        amount: 1000
      })
    };
    
    const response = await handler(event);
    
    expect(response.statusCode).toBe(400);
    const body = JSON.parse(response.body);
    expect(body).toHaveProperty('success', false);
    expect(body).toHaveProperty('error');
  });
});
