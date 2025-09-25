# ARQUITETURAS DE CANARY DEPLOYMENT - COMPARAÇÃO

## OPÇÃO 1: MULTIPLE ALIASES (O que você está pensando)
```
API Gateway → Stage Variables ou Base Path Mapping
              ↓                    ↓
         Live Alias (90%)    Canary Alias (10%)
              ↓                    ↓
          Version 1            Version 2
```

### Como funcionaria:
- Criar 2 aliases: Live + Canary
- API Gateway tem 2 endpoints ou usa stage variables
- 90% requests → /live, 10% requests → /canary
- Complexo de configurar e gerenciar

## OPÇÃO 2: SINGLE ALIAS WEIGHTED ROUTING (Implementação atual)
```
API Gateway (qualifier=Live) → Live Alias (weighted routing)
                                     ↓
                               Version 1 (90%) + Version 2 (10%)
```

### Como funciona (AWS Native):
- **Single alias `Live`** com RoutingConfig
- **API Gateway chama sempre o mesmo alias**
- **AWS Lambda internamente** faz o traffic splitting
- **AdditionalVersionWeights** define os percentuais

## COMPARAÇÃO TÉCNICA:

### Multiple Aliases:
❌ **Complexidade**: API Gateway precisa gerenciar routing  
❌ **Configuração**: Stage variables ou base path mapping
❌ **Management**: 2 aliases para manter sincronizados
❌ **Endpoints**: Potencialmente 2 URLs diferentes

### Single Alias Weighted Routing:
✅ **Simplicidade**: AWS Lambda faz o routing internamente
✅ **Single endpoint**: Sempre o mesmo URL
✅ **Native AWS**: Feature nativa do Lambda
✅ **Management**: Apenas 1 alias para gerenciar

## COMO O TRAFFIC SPLITTING REALMENTE FUNCIONA:

### Request Flow:
1. **Client** → API Gateway `/ping`
2. **API Gateway** → Lambda function `Live` alias
3. **AWS Lambda** (internamente):
   - 90% das invocações → executa Version 1 code
   - 10% das invocações → executa Version 2 code
4. **Response** volta normalmente

### AWS CLI Example:
```bash
# Configura weighted routing no alias Live
aws lambda update-alias \
  --function-name my-function \
  --name Live \
  --routing-config 'AdditionalVersionWeights={"2":0.1}'
  
# Resultado: Live alias = 90% Version 1 + 10% Version 2
```

## POR QUE ESCOLHEMOS SINGLE ALIAS:

1. **AWS Best Practice**: Documentação oficial recomenda
2. **Serverless Framework**: Melhor integração  
3. **Operacional**: Mais simples de gerenciar
4. **Monitoring**: CloudWatch metrics mais claros
5. **Rollback**: Mais rápido e seguro

## CONCLUSÃO:
A implementação atual está CORRETA e segue AWS best practices.
O API Gateway não precisa "saber" sobre traffic splitting - 
AWS Lambda faz isso transparentemente via weighted routing.