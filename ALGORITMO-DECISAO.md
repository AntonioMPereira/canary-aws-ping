# ALGORITMO DE DECISÃO DO AWS LAMBDA WEIGHTED ROUTING

## PROCESSO INTERNO DA AWS (Simplificado)

```python
# Pseudo-código de como AWS Lambda decide internamente
def invoke_with_weighted_routing(alias_config, request):
    # Configuração do alias Live
    primary_version = alias_config.function_version  # "1"
    routing_config = alias_config.routing_config     # {"2": 0.10}
    
    # Gerar número aleatório para decisão
    random_value = random.uniform(0.0, 1.0)  # 0.0 a 1.0
    
    # Decidir qual versão executar
    cumulative_weight = 0.0
    for version, weight in routing_config.additional_version_weights.items():
        cumulative_weight += weight
        if random_value < cumulative_weight:
            return execute_version(version)  # Execute Version 2
    
    # Se não caiu em nenhum peso adicional, executa versão primária
    return execute_version(primary_version)  # Execute Version 1

# Exemplo com 1000 requests:
requests = 1000
version_1_count = 0
version_2_count = 0

for i in range(requests):
    random_val = random.uniform(0.0, 1.0)
    if random_val < 0.10:  # 10% weight
        version_2_count += 1
    else:
        version_1_count += 1

print(f"Version 1: {version_1_count} requests (~90%)")
print(f"Version 2: {version_2_count} requests (~10%)")
```

## CONFIGURAÇÃO REAL NO NOSSO PROJETO

### Estado Inicial (Após primeiro deploy):
```json
{
  "AliasName": "Live",
  "FunctionVersion": "1",
  "RoutingConfig": null
}
```
**Resultado**: 100% tráfego → Version 1

### Após Canary Deploy (10%):
```json
{
  "AliasName": "Live", 
  "FunctionVersion": "1",
  "RoutingConfig": {
    "AdditionalVersionWeights": {
      "2": 0.10
    }
  }
}
```
**Resultado**: 90% tráfego → Version 1, 10% tráfego → Version 2

### Após Promotion (50%):
```json
{
  "AliasName": "Live",
  "FunctionVersion": "1", 
  "RoutingConfig": {
    "AdditionalVersionWeights": {
      "2": 0.50
    }
  }
}
```
**Resultado**: 50% tráfego → Version 1, 50% tráfego → Version 2

### Após Full Promotion (100%):
```json
{
  "AliasName": "Live",
  "FunctionVersion": "2",
  "RoutingConfig": null
}
```
**Resultado**: 100% tráfego → Version 2

### Após Rollback:
```json
{
  "AliasName": "Live",
  "FunctionVersion": "1", 
  "RoutingConfig": null
}
```
**Resultado**: 100% tráfego → Version 1 (versão estável)