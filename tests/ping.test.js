const { handler } = require('../src/handlers/ping');

describe('Ping Handler', () => {
  beforeEach(() => {
    // Mock environment variables
    process.env.APP_VERSION = '1.0.0';
    process.env.SERVERLESS_STAGE = 'test';
  });

  afterEach(() => {
    // Clean up environment variables
    delete process.env.APP_VERSION;
    delete process.env.SERVERLESS_STAGE;
  });

  test('should return ping with Node.js version', async () => {
    const event = {
      requestContext: {
        requestId: 'test-request-id'
      }
    };

    const result = await handler(event);
    const body = JSON.parse(result.body);

    expect(result.statusCode).toBe(200);
    expect(body.message).toMatch(/^ping v\d+\.\d+\.\d+$/);
    expect(body.version).toBe('1.0.0');
    expect(body.environment).toBe('test');
    expect(body.requestId).toBe('test-request-id');
    expect(body.timestamp).toMatch(/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\.\d{3}Z$/);
  });

  test('should include CORS headers', async () => {
    const event = {};
    const result = await handler(event);

    expect(result.headers['Access-Control-Allow-Origin']).toBe('*');
    expect(result.headers['Access-Control-Allow-Headers']).toBe('Content-Type');
    expect(result.headers['Access-Control-Allow-Methods']).toBe('GET, OPTIONS');
    expect(result.headers['Content-Type']).toBe('application/json');
  });

  test('should handle missing requestContext', async () => {
    const event = {};
    const result = await handler(event);
    const body = JSON.parse(result.body);

    expect(result.statusCode).toBe(200);
    expect(body.requestId).toBe('local');
  });

  test('should use default values for missing env vars', async () => {
    delete process.env.APP_VERSION;
    delete process.env.SERVERLESS_STAGE;

    const event = {};
    const result = await handler(event);
    const body = JSON.parse(result.body);

    expect(body.version).toBe('1.0.0');
    expect(body.environment).toBe('unknown');
  });
});