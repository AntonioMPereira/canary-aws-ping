# DIAGNÓSTICO: Problemas Críticos Identificados

## 1. PROBLEMA PRINCIPAL: API Gateway não usa Lambda Aliases

### Situação Atual (INCORRETA):
```
API Gateway → Lambda Function ($LATEST sempre)
```
- Aliases `Live` e `Canary` existem mas não são usados pelo API Gateway
- Traffic sempre vai para $LATEST, não há splitting

### Situação Correta Necessária:
```
API Gateway → Lambda Alias (Live/Canary com weighted routing)
```

## 2. OPÇÕES PARA CORREÇÃO:

### OPÇÃO A: Lambda Alias Weighted Routing (RECOMENDADA)
- Single Lambda alias com routing configuration
- AdditionalVersionWeights para splitting
- API Gateway chama o alias diretamente

### OPÇÃO B: Stage Variables (COMPLEXA)
- API Gateway Stage Variables apontam para aliases
- Requer configuração manual complexa
- Menos flexível para automation

### OPÇÃO C: Custom Domains (OVERKILL)
- Base path mapping para diferentes aliases
- Muito complexo para este caso

## 3. IMPLEMENTAÇÃO CORRETA (OPÇÃO A):

### serverless.yml necessário:
```yaml
functions:
  ping:
    handler: src/handlers/ping.handler
    # Remover versioning: true (causa confusão)
    events:
      - http:
          path: ping
          method: get
          # ADICIONAR: qualifier para usar alias
          qualifier: Live
```

### CloudFormation Resources:
```yaml
# Alias principal (Live) com weighted routing
PingLambdaAliasLive:
  Type: AWS::Lambda::Alias
  Properties:
    FunctionName: !Ref PingLambdaFunction
    FunctionVersion: "1"  # versão específica, não $LATEST
    Name: Live
    RoutingConfig:
      AdditionalVersionWeights:
        "2": 0.1  # 10% para versão 2 (canary)
```

### Scripts corretos:
```bash
# Update routing config (não criar novos aliases)
aws lambda update-alias \
  --function-name $FUNCTION_NAME \
  --name Live \
  --routing-config "AdditionalVersionWeights={\"$NEW_VERSION\":0.1}"
```

## 4. PROBLEMAS ATUAIS ESPECÍFICOS:

1. **API Gateway não configurado para usar qualifier**
   - Missing: qualifier: Live na configuração HTTP event

2. **Aliases apontam para $LATEST**
   - Problema: FunctionVersion: $LATEST para ambos
   - Solução: Versões específicas (1, 2, 3...)

3. **Scripts assumem multiple aliases**
   - Erro: Tentam gerenciar Live + Canary separadamente
   - Correto: Single alias Live com weighted routing

4. **Versionamento automático não configurado**
   - Missing: Como criar versões numeradas (1, 2, 3...)
   - Serverless Framework precisa de configuration específica

## 5. PLANO DE CORREÇÃO:

1. Remover aliases separados Live/Canary
2. Criar single alias Live com weighted routing
3. Configurar API Gateway qualifier
4. Corrigir scripts para weighted routing
5. Implementar versionamento correto

## CONCLUSÃO: 
Arquitetura atual está fundamentalmente incorreta. 
Precisa ser reescrita usando weighted routing em single alias.