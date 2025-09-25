/**
 * AWS Lambda handler for ping service
 * Returns ping response with Node.js version
 */

exports.handler = async (event) => {
  try {
    const nodeVersion = process.version;
    const timestamp = new Date().toISOString();
    
    const response = {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Headers': 'Content-Type',
        'Access-Control-Allow-Methods': 'GET, OPTIONS'
      },
      body: JSON.stringify({
        message: `ping ${nodeVersion}`,
        timestamp: timestamp,
        version: process.env.APP_VERSION || '1.0.0',
        environment: process.env.SERVERLESS_STAGE || 'unknown',
        requestId: event.requestContext?.requestId || 'local'
      })
    };

    console.log('Ping response:', JSON.stringify(response.body));
    return response;

  } catch (error) {
    console.error('Error in ping handler:', error);
    
    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        error: 'Internal Server Error',
        message: 'Failed to process ping request',
        timestamp: new Date().toISOString()
      })
    };
  }
};