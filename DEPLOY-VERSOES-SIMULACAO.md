# SIMULAÇÃO PRÁTICA - DEPLOY PRIMÁRIO vs ADICIONAL

## CENÁRIO INICIAL - DEPLOY PRIMEIRA VEZ

```bash
# Estado inicial: Função não existe ainda
λ Functions: [ VAZIA ]
```

### PASSO 1: Deploy Inicial (Versão Primária)
```bash
serverless deploy --stage prod
```

**AWS internamente faz:**
```yaml
# 1. Cria a função Lambda
Function: canary-aws-ping-prod-ping
  Runtime: nodejs20.x
  Code: (código do $LATEST)

# 2. CloudFormation cria Version 1
Version: 1  
  Runtime: nodejs20.x
  Code: (snapshot imutável do $LATEST)
  CreatedDate: 2025-09-25T10:00:00Z

# 3. Cria alias Live → Version 1  
Alias: Live
  FunctionVersion: 1
  RoutingConfig: NONE (100% para Version 1)

# 4. API Gateway  
HTTP Endpoint → qualifier=Live → Version 1
```

**Estado após deploy inicial:**
```
┌─────────────────┐    ┌──────────────┐    ┌─────────────┐
│   API Gateway   │───▶│  Live Alias  │───▶│  Version 1  │ 100%
│ GET /ping       │    │ (no routing) │    │ (runtime:   │
│ qualifier=Live  │    │              │    │  nodejs20.x)│
└─────────────────┘    └──────────────┘    └─────────────┘
                                           
                       ┌──────────────┐    
                       │   $LATEST    │    
                       │ (same as v1) │    
                       └──────────────┘    
```

## CENÁRIO CANARY - NOVA VERSÃO (Versão Adicional)

### PASSO 1: Desenvolver Nova Feature
```bash
# Desenvolvedor modifica código
echo "console.log('Nova feature X')" >> src/handlers/ping.js
git add . && git commit -m "feat: nova funcionalidade X"
```

### PASSO 2: Deploy Canary (Versão Adicional)
```bash
./scripts/deploy-canary.sh 20 prod  # 20% canary
```

**O que acontece internamente:**

#### Sub-passo 2.1: Serverless Deploy
```bash
serverless deploy --stage prod
```
```yaml
# AWS atualiza $LATEST com novo código
$LATEST:
  Runtime: nodejs20.x  
  Code: (NOVO código com feature X)
  UpdatedDate: 2025-09-25T11:00:00Z

# Version 1 permanece inalterada (imutável!)
Version: 1
  Runtime: nodejs20.x
  Code: (código ANTIGO - não muda nunca)
  CreatedDate: 2025-09-25T10:00:00Z

# Live alias ainda aponta 100% para Version 1
Alias: Live
  FunctionVersion: 1  # AINDA o código antigo
  RoutingConfig: NONE
```

#### Sub-passo 2.2: Publish New Version
```bash
aws lambda publish-version --function-name canary-aws-ping-prod-ping
```
```yaml
# AWS cria Version 2 (snapshot do $LATEST atual)
Version: 2  
  Runtime: nodejs20.x
  Code: (NOVO código com feature X - copiado do $LATEST)
  CreatedDate: 2025-09-25T11:05:00Z

# Agora temos:
# Version 1: código antigo (stable)
# Version 2: código novo (canary)  
# $LATEST: mesmo que Version 2
```

#### Sub-passo 2.3: Configure Weighted Routing
```bash
aws lambda update-alias \
  --name Live \
  --function-version 1 \
  --routing-config '{"AdditionalVersionWeights":{"2":0.20}}'
```

```yaml
# Live alias agora faz weighted routing:
Alias: Live
  FunctionVersion: 1        # Versão PRIMÁRIA (80%)
  RoutingConfig:
    AdditionalVersionWeights:
      "2": 0.20            # Versão ADICIONAL (20%)
```

**Estado após deploy canary:**
```
┌─────────────────┐    ┌──────────────┐    ┌─────────────┐
│   API Gateway   │───▶│  Live Alias  │───▶│  Version 1  │ 80%
│ GET /ping       │    │ (weighted)   │    │ (old code)  │ 
│ qualifier=Live  │    │              │    │             │
└─────────────────┘    └──────────────┘    └─────────────┘
                                      │    ┌─────────────┐
                                      └───▶│  Version 2  │ 20%
                                           │ (new code)  │
                                           └─────────────┘
```

## ALGORITMO DE DECISÃO AWS

Para cada request HTTP, AWS faz:

```python
import random

def route_request():
    # Peso configurado: Version 2 = 20%
    random_number = random.random()  # 0.0 a 1.0
    
    if random_number < 0.20:        # 20% das vezes
        return "Version 2"           # Nova feature
    else:                           # 80% das vezes  
        return "Version 1"           # Código estável
```

**Exemplo prático com 10 requests:**
```
Request 1: random=0.15 → Version 2 (canary)
Request 2: random=0.67 → Version 1 (primary)  
Request 3: random=0.12 → Version 2 (canary)
Request 4: random=0.89 → Version 1 (primary)
Request 5: random=0.34 → Version 1 (primary)
Request 6: random=0.91 → Version 1 (primary)
Request 7: random=0.05 → Version 2 (canary) 
Request 8: random=0.78 → Version 1 (primary)
Request 9: random=0.23 → Version 1 (primary)
Request 10: random=0.45 → Version 1 (primary)

Resultado: 3 requests → Version 2 (30%)
          7 requests → Version 1 (70%)
```

## RESPOSTA À SUA PERGUNTA: DIFERENTES RUNTIMES

### ❌ NÃO FUNCIONA com Weighted Routing

**Por que não?**
```yaml
# Runtime é propriedade da FUNÇÃO, não da VERSÃO
Function: canary-aws-ping-prod-ping
  Runtime: nodejs20.x  # ← Isso se aplica a TODAS as versões

# Quando você muda runtime:
serverless.yml:
  provider:
    runtime: nodejs22.x  # ← Mudança retroativa!

# Após deploy:
Version 1: nodejs22.x  # ← MUDOU retroativamente!
Version 2: nodejs22.x  # ← Nova versão  
$LATEST: nodejs22.x
```

**O que acontece na prática:**
```bash
# Deploy inicial
serverless deploy  # Runtime: Node 20
# → Version 1: Node 20

# Mudar runtime no serverless.yml para Node 22
serverless deploy  # Runtime: Node 22  
# → Version 1: AGORA É Node 22 (retroativo!)
# → Version 2: Node 22 (nova)

# Resultado: AMBAS as versões usam Node 22
# Não conseguimos ter Version 1: Node 20 + Version 2: Node 22
```

### ✅ ALTERNATIVA: Blue/Green Manual

Para migrar runtime (Node 18 → 22):

```bash
# 1. Deploy completo com novo runtime
# serverless.yml: runtime: nodejs22.x
serverless deploy --stage prod

# 2. Todas as versões agora são Node 22
# 3. Use canary para validar se Node 22 funciona bem
./scripts/deploy-canary.sh 10 prod

# 4. Se OK, promote para 100%
./scripts/promote-canary.sh 100 prod

# 5. Se problema, rollback imediato
./scripts/rollback.sh prod
```

## RESUMO FINAL

**Versão Primária vs Adicional:**
- **Primária**: Version sempre estável (80% traffic)
- **Adicional**: Version nova para teste (20% traffic)  
- **Same Runtime**: Ambas sempre usam mesmo runtime (limitação AWS)

**Para diferentes runtimes:**
- Use **duas funções separadas** (não duas versões)
- Configure **API Gateway manual routing** entre elas
- Ou faça **Blue/Green deployment completo**

**Nossa implementação atual é perfeita para:**
- ✅ Code changes (features, bugs)
- ✅ Configuration changes  
- ❌ Runtime changes (precisa estratégia diferente)

Quer que eu mostre como implementar migração de runtime com funções separadas?