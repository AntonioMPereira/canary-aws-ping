# EXEMPLO PRÁTICO: MIGRAÇÃO NODE 18 → NODE 22

## 🎯 CENÁRIO REAL

Você tem uma função em **Node 18** rodando em produção e quer migrar para **Node 22** com segurança usando canary deployment.

## 📋 PRÉ-REQUISITOS

```bash
# Dependências necessárias
aws --version       # AWS CLI
serverless --version # Serverless Framework
jq --version        # JSON processor
bc --version        # Calculator

# Permissões AWS necessárias
# - Lambda: CreateFunction, UpdateFunction, PublishVersion
# - API Gateway: CreateDeployment, UpdateStage
# - CloudFormation: CreateStack, UpdateStack
# - IAM: PassRole
```

## 🚀 PASSO A PASSO COMPLETO

### PASSO 1: Deploy Inicial Multi-Runtime

```bash
# 1. Deploy ambas as funções (Node 18 + Node 22)
npm run deploy:multi-prod

# O que acontece:
# ✅ Função ping-stable-prod (Node 18) criada
# ✅ Função ping-canary-prod (Node 22) criada  
# ✅ API Gateway configurado (100% Node 18)
# ✅ CloudWatch alarms criados para ambas
```

**Resultado esperado:**
```
✅ Stack: canary-aws-ping-multi-prod deployed
📋 API Endpoint: https://abc123.execute-api.us-east-1.amazonaws.com/prod/ping
📊 Traffic: 100% Node 18 (stable)
```

### PASSO 2: Ativar Canary (10% Node 22)

```bash
# 2. Ativar canary deployment com 10% Node 22
npm run deploy:runtime-canary

# Ou manualmente:
./scripts/deploy-runtime-canary.sh 10 prod
```

**O que acontece internamente:**
```bash
# 1. Update API Gateway method integration for canary
# 2. Create deployment with canary settings
# 3. Configure 10% traffic to Node 22 function
# 4. 90% traffic continues to Node 18 function
```

**Resultado:**
```
🎯 Deployment Summary:
   API Endpoint: https://abc123.execute-api.us-east-1.amazonaws.com/prod/ping
   Stable Runtime: Node 18 (90% traffic)
   Canary Runtime: Node 22 (10% traffic)
```

### PASSO 3: Testar Traffic Splitting

```bash
# 3. Testar se o traffic splitting está funcionando
for i in {1..20}; do
  curl -s https://abc123.execute-api.us-east-1.amazonaws.com/prod/ping | jq -r '.message'
  sleep 0.5
done

# Resultado esperado (aproximadamente):
# ping v18.x.x  ← Node 18 (18x)
# ping v22.x.x  ← Node 22 (2x)
```

### PASSO 4: Monitorar Deployment

```bash
# 4. Monitorar métricas e alarms
npm run monitor:runtime-canary

# Ou manualmente:
./scripts/monitor-runtime-canary.sh prod 300  # Monitor por 5 minutos
```

**Output esperado:**
```
📈 10:30:45 - Multi-Runtime Metrics (last 5 minutes):

   🏠 STABLE (Node 18):
      Invocations: 180
      Errors: 0 (0.00%)
      Avg Duration: 45ms
      Error Alarm: OK
      Latency Alarm: OK

   🐤 CANARY (Node 22):
      Invocations: 20
      Errors: 0 (0.00%)
      Avg Duration: 38ms
      Error Alarm: OK
      Latency Alarm: OK
```

### PASSO 5: Aumentar Traffic Gradualmente

```bash
# 5a. Se métricas OK, aumentar para 30%
./scripts/promote-runtime-canary.sh 30 prod

# 5b. Continuar aumentando se estável
./scripts/promote-runtime-canary.sh 50 prod  # 50% Node 22
./scripts/promote-runtime-canary.sh 80 prod  # 80% Node 22
```

### PASSO 6: Promotion Completo

```bash
# 6. Full promotion (100% Node 22)
npm run promote:runtime-canary

# Ou manualmente:
./scripts/promote-runtime-canary.sh 100 prod
```

**Resultado:**
```
✅ Full promotion completed!
📊 All traffic (100%) now goes to Node 22 runtime
```

### PASSO 7: Rollback (Se Necessário)

```bash
# 7. Se algo der errado, rollback imediato
npm run rollback:runtime-canary

# Ou manualmente:
./scripts/rollback-runtime-canary.sh prod
```

**Resultado:**
```
✅ Rollback completed!
📊 All traffic (100%) now goes to stable runtime (Node 18)
```

## 📊 VALIDAÇÃO DO SUCESSO

### Verificar Node Version na Response:

```bash
# Antes da migração (Node 18)
curl https://api.example.com/prod/ping | jq
{
  "message": "ping v18.20.4",
  "timestamp": "2025-09-25T15:30:00.000Z",
  "version": "1.0.1",
  "environment": "prod"
}

# Depois da migração (Node 22)  
curl https://api.example.com/prod/ping | jq
{
  "message": "ping v22.5.1",
  "timestamp": "2025-09-25T15:30:00.000Z", 
  "version": "1.0.1",
  "environment": "prod"
}
```

### Verificar CloudWatch Metrics:

```bash
# Ver métricas comparativas
aws logs filter-log-events \
  --log-group-name /aws/lambda/ping-stable-prod \
  --start-time 1695650000000 \
  --filter-pattern "REPORT"

aws logs filter-log-events \
  --log-group-name /aws/lambda/ping-canary-prod \
  --start-time 1695650000000 \
  --filter-pattern "REPORT"
```

## ⚡ COMANDOS RÁPIDOS

```bash
# Deploy completo multi-runtime
npm run deploy:multi-prod

# Canary 10% Node 22
npm run deploy:runtime-canary

# Monitor por 5 minutos
npm run monitor:runtime-canary  

# Promote para 100% Node 22
npm run promote:runtime-canary

# Rollback para Node 18
npm run rollback:runtime-canary
```

## 🎯 MÉTRICAS DE SUCESSO

### Performance Esperada:

- **Node 18**: ~45ms avg latency
- **Node 22**: ~38ms avg latency (15% improvement)
- **Cold Start**: Node 22 pode ser ligeiramente mais rápido
- **Memory Usage**: Similar entre versões

### Sinais de Problemas:

```bash
# ❌ Error rate aumentou
Error Alarm: ALARM

# ❌ Latência piorou significativamente  
Latency Alarm: ALARM

# ❌ Muitos cold starts
Duration > 1000ms

# → AÇÃO: Rollback imediato!
npm run rollback:runtime-canary
```

## 🎉 SUCESSO COMPLETO!

Após completar todos os passos:

- ✅ **Migração Node 18 → Node 22** completa
- ✅ **Zero downtime** durante a migração
- ✅ **Traffic splitting** validado
- ✅ **Rollback capability** testada  
- ✅ **Monitoring** implementado
- ✅ **Production ready** multi-runtime canary deployment

**Você agora tem uma implementação completa de canary deployment para diferentes runtimes!** 🚀