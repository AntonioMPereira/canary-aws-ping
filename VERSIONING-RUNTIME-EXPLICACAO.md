# DEPLOY VERSÃO PRIMÁRIA vs ADICIONAL - EXPLICAÇÃO COMPLETA

## COMO FUNCIONA O VERSIONAMENTO LAMBDA

### CONCEITO FUNDAMENTAL
```
Lambda Function = Container que armazena múltiplas versões do código
┌─────────────────────────────────────────────────────────┐
│  canary-aws-ping-prod-ping                             │
│  ├── $LATEST (sempre o código mais recente)            │
│  ├── Version 1 (snapshot imutável)                    │
│  ├── Version 2 (snapshot imutável)                    │
│  └── Version 3 (snapshot imutável)                    │
└─────────────────────────────────────────────────────────┘
```

## FLUXO DE DEPLOY - PASSO A PASSO

### DEPLOY INICIAL (Versão Primária)
```bash
# 1. serverless deploy
serverless deploy --stage prod
```

**O que acontece:**
```
1. Serverless cria/atualiza código em $LATEST
2. CloudFormation cria Version 1 automaticamente (PingLambdaVersion)
3. Cria alias Live → Version 1
4. API Gateway → Live alias

Resultado:
┌─────────────────┐    ┌─────────────┐    ┌─────────────┐
│   API Gateway   │───▶│ Live Alias  │───▶│  Version 1  │
│ (qualifier=Live)│    │             │    │ (Node 20.x) │
└─────────────────┘    └─────────────┘    └─────────────┘
```

### CANARY DEPLOY (Versão Adicional)
```bash
# 2. deploy-canary.sh
./scripts/deploy-canary.sh 10 prod
```

**O que acontece:**
```bash
# Passo 1: Deploy novo código
serverless deploy --stage prod
# → Atualiza $LATEST com novo código

# Passo 2: Publish versão adicional
aws lambda publish-version \
  --function-name canary-aws-ping-prod-ping
# → Cria Version 2 (snapshot do $LATEST atual)

# Passo 3: Configurar weighted routing
aws lambda update-alias \
  --name Live \
  --routing-config "AdditionalVersionWeights={\"2\":0.10}"
# → Live alias: 90% Version 1 + 10% Version 2
```

**Resultado final:**
```
┌─────────────────┐    ┌─────────────┐    ┌─────────────┐
│   API Gateway   │───▶│ Live Alias  │───▶│  Version 1  │ 90%
│ (qualifier=Live)│    │ (weighted)  │    │ (código old)│
└─────────────────┘    └─────────────┘    └─────────────┘
                                          ┌─────────────┐
                                          │  Version 2  │ 10%
                                          │ (código new)│
                                          └─────────────┘
```

## PERGUNTA: DIFERENTES RUNTIMES (Node 18 vs Node 22)?

### RESPOSTA: ❌ NÃO É POSSÍVEL DIRETAMENTE

**Por que não funciona:**
```yaml
# serverless.yml define runtime para toda a função
provider:
  runtime: nodejs20.x  # Aplica para TODAS as versões

functions:
  ping:
    runtime: nodejs20.x  # Não pode ser diferente por versão
```

**Limitação técnica:**
- Runtime é definido no **function level**, não no **version level**
- Todas as versões (1, 2, 3...) usam o mesmo runtime
- AWS Lambda não permite diferentes runtimes por versão

### ALTERNATIVAS PARA MIGRAÇÃO DE RUNTIME

#### OPÇÃO 1: Blue/Green com Funções Separadas
```yaml
# serverless.yml
functions:
  ping-v1:
    runtime: nodejs18.x
    handler: src/handlers/ping.handler
    events:
      - http:
          path: ping
          method: get
          qualifier: Live
          
  ping-v2:
    runtime: nodejs22.x  
    handler: src/handlers/ping.handler
    # Sem eventos HTTP (controlado via scripts)
```

**Gerenciamento manual:**
```bash
# Script customizado para alternar entre funções
# 90% → ping-v1 (Node 18)
# 10% → ping-v2 (Node 22)
```

#### OPÇÃO 2: Container Images (Recomendado)
```dockerfile
# Dockerfile.node18
FROM public.ecr.aws/lambda/nodejs:18
COPY . .
CMD ["src/handlers/ping.handler"]

# Dockerfile.node22  
FROM public.ecr.aws/lambda/nodejs:22
COPY . .
CMD ["src/handlers/ping.handler"]
```

```yaml
# serverless.yml
functions:
  ping:
    image: 
      uri: ${self:custom.ecrUri}
    # Versões podem usar diferentes container images
```

#### OPÇÃO 3: Staged Migration (Mais Simples)
```bash
# 1. Deploy completo com novo runtime
# serverless.yml: runtime: nodejs22.x
serverless deploy --stage prod

# 2. Isso cria nova Version com Node 22
# 3. Usar canary deployment normalmente
./scripts/deploy-canary.sh 10 prod

# Resultado: 
# Version 1: Node 20 (antigo)
# Version 2: Node 22 (novo) 
```

**❌ PROBLEMA**: Não funciona porque todas as versões assumem o novo runtime retroativamente.

## SOLUÇÃO RECOMENDADA PARA RUNTIME MIGRATION

### APPROACH: "Function Replacement Strategy"

#### Fase 1: Preparar Nova Função
```yaml
# serverless-node22.yml
service: canary-aws-ping-v2

provider:
  runtime: nodejs22.x

functions:
  ping:
    handler: src/handlers/ping.handler
    # Sem eventos HTTP ainda
```

#### Fase 2: Deploy Paralelo
```bash
# Deploy nova função com Node 22
serverless deploy -c serverless-node22.yml --stage prod

# Resultado: Duas funções coexistem:
# - canary-aws-ping-prod-ping (Node 20)
# - canary-aws-ping-v2-prod-ping (Node 22)
```

#### Fase 3: Traffic Splitting Manual
```bash
# Script customizado para dividir tráfego entre funções
# API Gateway → weighted routing entre duas funções diferentes
```

#### Fase 4: Migration Complete
```bash
# Remover função antiga após validação
serverless remove --stage prod  # Remove Node 20 version
```

## LIMITAÇÕES E CONSIDERAÇÕES

### Weighted Routing Normal:
✅ **Funciona para**: Código, configuração, variáveis ambiente  
❌ **NÃO funciona para**: Runtime, memory size, timeout (configurações de função)

### Runtime Migration:
- **Simples**: Blue/Green deployment completo
- **Complexo**: Canary com diferentes runtimes  
- **Recomendado**: Testar Node 22 em staging primeiro

### Nossa Implementação Atual:
```yaml
# Todas as versões usarão nodejs20.x
provider:
  runtime: nodejs20.x
  
# Para canary deployment de CÓDIGO apenas
# Version 1: Código antigo (Node 20)  
# Version 2: Código novo (Node 20)
```

## CONCLUSÃO

**Para migração de runtime (Node 18 → Node 22):**
- ❌ **Weighted routing não funciona** (limitação AWS)
- ✅ **Blue/Green deployment** completo funciona
- ✅ **Container images** oferecem mais flexibilidade
- ✅ **Funções separadas** com traffic splitting manual

**Nossa implementação atual é ideal para:**
- ✅ **Code changes** (features, bug fixes)
- ✅ **Configuration changes** (env vars)
- ✅ **Logic updates** (business rules)
- ❌ **Runtime changes** (requer estratégia diferente)

**Recomendação**: Mantenha runtime migration como processo separado do canary deployment regular.