const AWS = require('aws-sdk');
const codedeploy = new AWS.CodeDeploy();
const https = require('https');
const util = require('util');

exports.handler = async (event) => {
  console.log('Post-traffic validation started');
  console.log('Event:', JSON.stringify(event, null, 2));
  
  try {
    // Add your post-traffic validation logic here
    // For example: integration tests, performance validation, etc.
    
    // Example: Test the endpoint
    const endpointUrl = process.env.ENDPOINT_URL;
    if (endpointUrl) {
      await testEndpoint(endpointUrl);
    }
    
    console.log('Post-traffic validation passed');
    
    await codedeploy.putLifecycleEventHookExecutionStatus({
      deploymentId: event.DeploymentId,
      lifecycleEventHookExecutionId: event.LifecycleEventHookExecutionId,
      status: 'Succeeded'
    }).promise();
    
    return {
      statusCode: 200,
      body: JSON.stringify({
        message: 'Post-traffic validation completed successfully'
      })
    };
    
  } catch (error) {
    console.error('Post-traffic validation failed:', error);
    
    await codedeploy.putLifecycleEventHookExecutionStatus({
      deploymentId: event.DeploymentId,
      lifecycleEventHookExecutionId: event.LifecycleEventHookExecutionId,
      status: 'Failed'
    }).promise();
    
    return {
      statusCode: 500,
      body: JSON.stringify({
        message: 'Post-traffic validation failed',
        error: error.message
      })
    };
  }
};

// Helper function to test endpoint
async function testEndpoint(url) {
  return new Promise((resolve, reject) => {
    const request = https.get(url, (response) => {
      let data = '';
      
      response.on('data', (chunk) => {
        data += chunk;
      });
      
      response.on('end', () => {
        if (response.statusCode === 200) {
          console.log('Endpoint test successful:', data);
          resolve(data);
        } else {
          reject(new Error(`Endpoint test failed with status ${response.statusCode}`));
        }
      });
    });
    
    request.on('error', (error) => {
      reject(error);
    });
    
    request.setTimeout(5000, () => {
      request.destroy();
      reject(new Error('Request timeout'));
    });
  });
}