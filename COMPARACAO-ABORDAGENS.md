# DUAS ABORDAGENS DE CANARY DEPLOYMENT

## 🎯 QUANDO USAR CADA ABORDAGEM

### ABORDAGEM 1: Lambda Weighted Routing (Implementação Atual)
**Arquivo**: `serverless.yml` + `scripts/deploy-canary.sh`

#### ✅ Use quando:
- **Mesmo runtime** (Node 20 → Node 20)
- **Mudanças de código** (features, bug fixes)
- **Mudanças de configuração** (env vars)
- **Simplicidade** é prioridade
- **Custos baixos** (uma função)

#### ❌ NÃO use quando:
- **Runtimes diferentes** (Node 18 → Node 22)
- **Memory/timeout diferentes** por versão
- **Dependências conflitantes**

```bash
# Comandos da Abordagem 1
npm run deploy:canary        # 10% canary
./scripts/promote-canary.sh 50 prod
npm run promote:canary       # 100% promotion
npm run rollback            # Emergency rollback
```

---

### ABORDAGEM 2: API Gateway Multi-Runtime (Nova Implementação)
**Arquivo**: `serverless-multi-runtime.yml` + `scripts/deploy-runtime-canary.sh`

#### ✅ Use quando:
- **Runtimes diferentes** (Node 18 → Node 22, Python 3.9 → 3.12)
- **Memory sizes diferentes** (128MB vs 512MB)
- **Arquiteturas diferentes** (x86 vs arm64)
- **Major version migrations**
- **Breaking changes** que requerem isolamento

#### ❌ NÃO use quando:
- **Mudanças pequenas** de código
- **Custos** são críticos (duas funções ativas)
- **Simplicidade** é prioridade

```bash
# Comandos da Abordagem 2
./scripts/deploy-runtime-canary.sh 10 prod    # 10% Node 22
./scripts/promote-runtime-canary.sh 50 prod   # 50% Node 22
./scripts/promote-runtime-canary.sh 100 prod  # 100% Node 22
./scripts/rollback-runtime-canary.sh prod     # Back to Node 18
```

## 🏗️ ARQUITETURAS COMPARADAS

### Weighted Routing (Abordagem 1):
```
API Gateway → Live Alias → Version 1 (90%) + Version 2 (10%)
                ↓              ↓               ↓
            Node 20.x      Node 20.x       Node 20.x
            Old Code      New Code        Same Runtime
```

### Multi-Runtime (Abordagem 2):
```
API Gateway → Canary Deployment → Stable Function (90%) + Canary Function (10%)
                ↓                      ↓                        ↓
            Traffic Split          Node 18.x                 Node 22.x
            by API Gateway         Old Runtime              New Runtime
```

## 📊 COMPARAÇÃO TÉCNICA

| Aspecto | Weighted Routing | Multi-Runtime |
|---------|------------------|---------------|
| **Runtimes** | ❌ Mesmo sempre | ✅ Diferentes |
| **Complexity** | ✅ Simples | ❌ Complexo |
| **Cost** | ✅ Uma função | ❌ Duas funções |
| **Cold Start** | ✅ Menor impact | ❌ Ambas podem ter |
| **Monitoring** | ✅ Unified | ❌ Separado |
| **Rollback** | ✅ Instantâneo | ✅ Rápido |
| **Setup** | ✅ Serverless native | ❌ Manual API Gateway |

## 🚀 EXEMPLO PRÁTICO: MIGRAÇÃO NODE 18 → NODE 22

### CENÁRIO: Você tem uma função em Node 18 e quer migrar para Node 22

#### ❌ ERRADO - Tentar usar Weighted Routing:
```bash
# Isso NÃO funciona para diferentes runtimes!
serverless deploy --stage prod  # Muda TODAS as versões para Node 22
./scripts/deploy-canary.sh 10 prod  # Version 1 e 2 são Node 22!
```

#### ✅ CORRETO - Usar Multi-Runtime:
```bash
# Deploy inicial (Node 18 stable + Node 22 canary)
./scripts/deploy-runtime-canary.sh 10 prod
# Resultado: 90% Node 18, 10% Node 22

# Validar e aumentar gradualmente
./scripts/promote-runtime-canary.sh 30 prod  # 70% Node 18, 30% Node 22
./scripts/promote-runtime-canary.sh 50 prod  # 50% Node 18, 50% Node 22
./scripts/promote-runtime-canary.sh 100 prod # 100% Node 22

# Se problemas, rollback para Node 18
./scripts/rollback-runtime-canary.sh prod
```

## 📁 ESTRUTURA DE ARQUIVOS

```
canary-aws-ping/
├── serverless.yml                    # Weighted routing (same runtime)
├── serverless-multi-runtime.yml      # Multi-runtime deployment
├── scripts/
│   # Weighted Routing Scripts
│   ├── deploy-canary.sh              # Lambda weighted routing
│   ├── promote-canary.sh             # Adjust weights
│   ├── rollback.sh                   # Remove routing
│   └── monitor-canary.sh             # Monitor single function
│   
│   # Multi-Runtime Scripts  
│   ├── deploy-runtime-canary.sh      # API Gateway canary
│   ├── promote-runtime-canary.sh     # Adjust API Gateway %
│   ├── rollback-runtime-canary.sh    # Remove API Gateway canary
│   └── monitor-runtime-canary.sh     # Monitor both functions
```

## 🎯 DECISÃO RÁPIDA

### Para mudanças de código (mesmo runtime):
```bash
# Use Weighted Routing (simples)
npm run deploy:canary
```

### Para migração de runtime:
```bash
# Use Multi-Runtime (complex mas funciona)
./scripts/deploy-runtime-canary.sh 10 prod
```

## 🔍 MONITORING DIFERENÇAS

### Weighted Routing:
- **Uma função**: Metrics consolidados
- **CloudWatch**: Logs unificados  
- **Alarms**: Baseado em version tags

### Multi-Runtime:
- **Duas funções**: Metrics separados
- **CloudWatch**: Logs separados por função
- **Alarms**: Por função individual
- **Comparação**: Node 18 vs Node 22 side-by-side

## 💡 RECOMENDAÇÕES

### Para equipes iniciantes:
**Use Weighted Routing** - Mais simples, menos moving parts

### Para production crítica:
**Use Multi-Runtime** - Isolamento completo, rollback mais seguro

### Para CI/CD automated:
**Ambas** - Scripts bem definidos para diferentes cenários

---

## 🎯 RESUMO EXECUTIVO

**VOCÊ AGORA TEM DUAS FERRAMENTAS:**

1. **`serverless.yml`**: Para canary deployment de código (mesmo runtime)
2. **`serverless-multi-runtime.yml`**: Para canary deployment com diferentes runtimes

**AMBAS FUNCIONAM!** Use a que faz sentido para seu caso de uso específico.