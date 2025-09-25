# MÚLTIPLOS RUNTIMES COM LAMBDA ALIAS - A VERDADE TÉCNICA

## SUA PERGUNTA ORIGINAL:
> "eu poderia rodar uma em node 18 e outra node 22 para uma atualização de runtime?"

## RESPOSTA: ✅ **SIM, MAS NÃO COM WEIGHTED ROUTING**

## LIMITAÇÃO CRÍTICA DO AWS LAMBDA:

### O que NÃO funciona (Weighted Routing):
```yaml
# IMPOSSÍVEL: Runtime por versão
Function: minha-funcao
├── Version 1: nodejs18.x  ❌
└── Version 2: nodejs22.x  ❌

# REALIDADE: Runtime é da função inteira
Function: minha-funcao
  Runtime: nodejs20.x  ← Todas as versões usam esse runtime
├── Version 1: nodejs20.x
└── Version 2: nodejs20.x
```

### Por que não funciona:
- Runtime é propriedade da **função**, não da **versão**
- `aws lambda publish-version` cria snapshot do **código**, não do runtime
- Todas as versões herdam o runtime atual da função

## SOLUÇÃO: DUAS FUNÇÕES + API GATEWAY CANARY

### Arquitetura Correta para Diferentes Runtimes:

```yaml
# serverless.yml
service: multi-runtime-canary

functions:
  # Função estável (Node 18)
  ping-stable:
    name: ping-stable-${self:provider.stage}
    runtime: nodejs18.x
    handler: src/handlers/ping.handler
    # SEM eventos HTTP (controlado pelo API Gateway)
    
  # Função canary (Node 22)  
  ping-canary:
    name: ping-canary-${self:provider.stage}
    runtime: nodejs22.x
    handler: src/handlers/ping.handler
    # SEM eventos HTTP (controlado pelo API Gateway)

# API Gateway com canary deployment
resources:
  Resources:
    # REST API
    ApiGatewayRestApi:
      Type: AWS::ApiGateway::RestApi
      Properties:
        Name: multi-runtime-api
        
    # Deployment
    ApiGatewayDeployment:
      Type: AWS::ApiGateway::Deployment
      Properties:
        RestApiId: !Ref ApiGatewayRestApi
        StageName: !Ref AWS::NoValue
        
    # Stage com Canary Settings
    ApiGatewayStage:
      Type: AWS::ApiGateway::Stage
      Properties:
        RestApiId: !Ref ApiGatewayRestApi
        DeploymentId: !Ref ApiGatewayDeployment
        StageName: ${self:provider.stage}
        # AQUI está o canary deployment
        CanarySettings:
          PercentTraffic: 10  # 10% para canary
          StageVariableOverrides:
            lambdaAlias: canary  # Variável que muda a função
```

### Implementação do Resource/Method:

```yaml
# Method /ping
PingResource:
  Type: AWS::ApiGateway::Resource
  Properties:
    RestApiId: !Ref ApiGatewayRestApi
    ParentId: !GetAtt ApiGatewayRestApi.RootResourceId
    PathPart: ping

PingMethod:
  Type: AWS::ApiGateway::Method
  Properties:
    RestApiId: !Ref ApiGatewayRestApi
    ResourceId: !Ref PingResource
    HttpMethod: GET
    Integration:
      Type: AWS_PROXY
      IntegrationHttpMethod: POST
      # URI dinâmica baseada na stage variable
      Uri: !Sub 
        - arn:aws:apigateway:${AWS::Region}:lambda:path/2015-03-31/functions/${FunctionArn}/invocations
        - FunctionArn: !Sub
          - ping-${LambdaAlias}-${self:provider.stage}
          - LambdaAlias: ${stageVariables.lambdaAlias}
```

## IMPLEMENTAÇÃO PRÁTICA:

### 1. Deploy Inicial (Node 18):
```bash
# serverless.yml: runtime nodejs18.x
serverless deploy --stage prod
# Resultado: ping-stable-prod (Node 18)
# API Gateway: 100% tráfego → ping-stable-prod
```

### 2. Deploy Canary (Node 22):
```bash
# Adicionar função canary no serverless.yml
# runtime: nodejs22.x
serverless deploy --stage prod
# Resultado: 
# - ping-stable-prod (Node 18) 
# - ping-canary-prod (Node 22)
```

### 3. Ativar Canary no API Gateway:
```bash
aws apigateway update-stage \
  --rest-api-id $API_ID \
  --stage-name prod \
  --patch-ops op=replace,path=/canarySettings/percentTraffic,value=10

# Resultado:
# 90% requests → ping-stable-prod (Node 18)
# 10% requests → ping-canary-prod (Node 22)
```

### 4. Promotion/Rollback:
```bash
# Aumentar canary
aws apigateway update-stage \
  --patch-ops op=replace,path=/canarySettings/percentTraffic,value=50

# Full promotion (trocar função principal)
aws apigateway update-stage \
  --patch-ops op=remove,path=/canarySettings
  # E atualizar integration URI para ping-canary-prod
```

## SCRIPT COMPLETO DE IMPLEMENTAÇÃO:

### deploy-runtime-canary.sh:
```bash
#!/bin/bash

OLD_RUNTIME="nodejs18.x"
NEW_RUNTIME="nodejs22.x"
CANARY_PERCENT=${1:-10}

echo "🚀 Multi-runtime canary deployment"
echo "   Old: $OLD_RUNTIME (stable function)"
echo "   New: $NEW_RUNTIME (canary function)"
echo "   Traffic: ${CANARY_PERCENT}% canary"

# Step 1: Deploy both functions
serverless deploy --stage prod

# Step 2: Configure API Gateway canary
API_ID=$(aws apigateway get-rest-apis \
  --query "items[?name=='multi-runtime-api'].id" \
  --output text)

aws apigateway update-stage \
  --rest-api-id $API_ID \
  --stage-name prod \
  --patch-ops op=replace,path=/canarySettings/percentTraffic,value=${CANARY_PERCENT}

echo "✅ Canary deployment active!"
echo "📊 ${CANARY_PERCENT}% → Node 22, $((100-CANARY_PERCENT))% → Node 18"
```

## VANTAGENS DESTA ABORDAGEM:

✅ **Diferentes Runtimes**: Node 18 vs Node 22 realmente funcionando  
✅ **Traffic Splitting**: API Gateway controla percentuais  
✅ **Monitoring**: CloudWatch por função separada  
✅ **Rollback**: Remover canary settings instantly  
✅ **Gradual Migration**: 10% → 50% → 100%  

## DESVANTAGENS:

❌ **Complexidade**: Mais recursos AWS para gerenciar  
❌ **Custo**: Duas funções Lambda ativas  
❌ **Deployment**: Serverless Framework não tem template pronto  
❌ **Cold Start**: Ambas as funções podem ter cold start  

## CONCLUSÃO:

**SUA IDEIA É VÁLIDA E POSSÍVEL!**

A implementação requer:
1. **Duas funções Lambda** (não duas versões)
2. **API Gateway Canary Deployment** (não Lambda Weighted Routing)  
3. **Stage Variables** para roteamento dinâmico
4. **Scripts customizados** para gerenciar o canary

**Nossa implementação atual** (weighted routing) é **excelente para mudanças de código** no mesmo runtime, mas **não funciona para diferentes runtimes**.

**Quer que eu implemente esta solução multi-runtime?**