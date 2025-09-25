# AWS LAMBDA ALIAS WEIGHTED ROUTING - EXPLICAÇÃO COMPLETA

## O QUE É ALIAS WEIGHTED ROUTING?

**Definição**: Feature nativa da AWS Lambda que permite distribuir tráfego entre diferentes versões de uma função usando um único alias com configuração de pesos.

## CONCEITOS FUNDAMENTAIS

### 1. Lambda Versions
```
$LATEST  →  Código mais recente (não versionado)
Version 1 → Snapshot imutável do código
Version 2 → Nova versão com alterações
Version 3 → Próxima versão...
```

### 2. Lambda Alias
```
Alias = Ponteiro nomeado que pode apontar para:
- Uma versão específica (Version 1)
- Múltiplas versões com pesos (Version 1 + Version 2)
```

### 3. Weighted Routing Config
```json
{
  "FunctionVersion": "1",           // Versão primária (90%)
  "RoutingConfig": {
    "AdditionalVersionWeights": {
      "2": 0.10                     // Version 2 recebe 10%
    }
  }
}
```

## COMO FUNCIONA NA PRÁTICA

### Cenário: Canary Deployment 10%

#### STEP 1: Setup Inicial
```bash
# Função existe com código atual
Function: canary-aws-ping-prod-ping
Version 1: Código estável atual
Alias Live: Aponta para Version 1 (100%)
```

#### STEP 2: Deploy Nova Versão
```bash
# Publicamos nova versão com código alterado
aws lambda publish-version \
  --function-name canary-aws-ping-prod-ping \
  --description "New feature X"

# Resultado: Version 2 criada
```

#### STEP 3: Configurar Weighted Routing
```bash
# Configuramos alias Live para distribuir tráfego
aws lambda update-alias \
  --function-name canary-aws-ping-prod-ping \
  --name Live \
  --routing-config 'AdditionalVersionWeights={"2":0.1}'

# Resultado:
# - 90% tráfego → Version 1 (código antigo)  
# - 10% tráfego → Version 2 (código novo)
```

## FLUXO DE EXECUÇÃO DETALHADO

### Request Flow:
```
1. Client → API Gateway: GET /prod/ping

2. API Gateway → Lambda: Invoke Live alias

3. AWS Lambda (internamente):
   - Gera número aleatório: 0.0 - 1.0
   - Se número < 0.1 (10%) → executa Version 2
   - Se número >= 0.1 (90%) → executa Version 1

4. Lambda executa código correspondente

5. Response volta para client
```

### Exemplo Prático:
```
100 requests simultâneos:
- Request 1: random=0.05 → Version 2 (novo código)
- Request 2: random=0.87 → Version 1 (código antigo)
- Request 3: random=0.03 → Version 2 (novo código)
- Request 4: random=0.45 → Version 1 (código antigo)
...
Resultado: ~10 requests Version 2, ~90 requests Version 1
```

## CONFIGURAÇÕES POSSÍVEIS

### Canary 10%
```json
{
  "FunctionVersion": "1",
  "RoutingConfig": {
    "AdditionalVersionWeights": {"2": 0.10}
  }
}
```

### Canary 50% (A/B Testing)
```json
{
  "FunctionVersion": "1", 
  "RoutingConfig": {
    "AdditionalVersionWeights": {"2": 0.50}
  }
}
```

### Blue/Green 100% (Full Promotion)
```json
{
  "FunctionVersion": "2"
  // Sem RoutingConfig = 100% Version 2
}
```

### Rollback (Remove Canary)
```json
{
  "FunctionVersion": "1"
  // Remove RoutingConfig = 100% Version 1
}
```

## VANTAGENS DO WEIGHTED ROUTING

### 1. Transparência para Cliente
```
Client sempre chama: https://api.example.com/prod/ping
AWS Lambda decide internamente qual versão executar
Cliente não sabe que há múltiplas versões
```

### 2. Controle Granular
```bash
# Aumentar gradualmente
./promote-canary.sh 20 prod  # 20% canary
./promote-canary.sh 50 prod  # 50% canary  
./promote-canary.sh 100 prod # 100% canary
```

### 3. Rollback Instantâneo
```bash
# Remove weighted routing em segundos
./rollback.sh prod
# Resultado: 100% volta para versão estável
```

### 4. Monitoring Unificado
```
CloudWatch Metrics:
- Invocations: Total de chamadas
- Errors: Erros por versão  
- Duration: Latência por versão
- Concurrent Executions: Concorrência
```

## IMPLEMENTAÇÃO NO NOSSO PROJETO

### serverless.yml:
```yaml
functions:
  ping:
    events:
      - http:
          qualifier: Live  # API Gateway chama sempre Live alias
```

### deploy-canary.sh:
```bash
# Publica Version 2
aws lambda publish-version ...

# Configura 10% para Version 2
aws lambda update-alias \
  --name Live \
  --routing-config "AdditionalVersionWeights={\"2\":0.1}"
```

### promote-canary.sh:
```bash
# Aumenta para 50%
aws lambda update-alias \
  --name Live \
  --routing-config "AdditionalVersionWeights={\"2\":0.5}"
```

### rollback.sh:
```bash
# Remove weighted routing (100% Version 1)
aws lambda update-alias \
  --name Live \
  --function-version "1"
```

## LIMITAÇÕES E CONSIDERAÇÕES

### Limitações:
- Máximo 2 versões simultâneas no weighted routing
- Peso deve ser decimal entre 0.0 e 1.0  
- Não funciona com $LATEST (apenas versões numeradas)

### Best Practices:
- Sempre monitorar CloudWatch durante canary
- Configurar alarms para rollback automático
- Testar versões antes de aplicar weighted routing
- Manter logs detalhados das mudanças

## CONCLUSÃO

**Alias Weighted Routing** é uma solução elegante da AWS que:
- Elimina necessidade de múltiplos endpoints
- Simplifica canary deployments  
- Oferece controle granular de tráfego
- Permite rollback instantâneo
- É transparente para clientes

**Nossa implementação usa essa feature corretamente para canary deployment real!**