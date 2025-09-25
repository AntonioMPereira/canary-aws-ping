const AWS = require('aws-sdk');
const codedeploy = new AWS.CodeDeploy();

exports.handler = async (event) => {
  console.log('Pre-traffic validation started');
  console.log('Event:', JSON.stringify(event, null, 2));
  
  try {
    // Add your pre-traffic validation logic here
    // For example: health checks, smoke tests, etc.
    
    console.log('Pre-traffic validation passed');
    
    await codedeploy.putLifecycleEventHookExecutionStatus({
      deploymentId: event.DeploymentId,
      lifecycleEventHookExecutionId: event.LifecycleEventHookExecutionId,
      status: 'Succeeded'
    }).promise();
    
    return {
      statusCode: 200,
      body: JSON.stringify({
        message: 'Pre-traffic validation completed successfully'
      })
    };
    
  } catch (error) {
    console.error('Pre-traffic validation failed:', error);
    
    await codedeploy.putLifecycleEventHookExecutionStatus({
      deploymentId: event.DeploymentId,
      lifecycleEventHookExecutionId: event.LifecycleEventHookExecutionId,
      status: 'Failed'
    }).promise();
    
    return {
      statusCode: 500,
      body: JSON.stringify({
        message: 'Pre-traffic validation failed',
        error: error.message
      })
    };
  }
};