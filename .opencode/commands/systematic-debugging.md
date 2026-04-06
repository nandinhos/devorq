Iniciar investigação sistemática de bug: $ARGUMENTS

Leia `.devorq/skills/systematic-debugging/SKILL.md` para instruções completas.

**Regra**: Nunca propor fix sem entender a causa raiz primeiro.

## Protocolo de Investigação

### Fase 1 — Observar (não tocar no código)
1. Reproduzir o bug com passos claros
2. Capturar stack trace / logs / erro exato
3. Identificar: quando começou? última mudança relevante?

### Fase 2 — Hipóteses
Listar 3-5 hipóteses ordenadas por probabilidade:
```
H1 (mais provável): [hipótese]
H2: [hipótese]
H3: [hipótese]
```

### Fase 3 — Isolar
Para cada hipótese (da mais provável):
1. Adicionar log/dump para confirmar/refutar
2. Verificar com `git log --oneline -10` se foi introduzido recentemente
3. Testar em isolamento

### Fase 4 — Confirmar Causa Raiz
Antes de qualquer fix:
- Confirmar que a hipótese explica 100% do comportamento
- Se não explica — voltar para Fase 2

### Fase 5 — Fix Cirúrgico
- Corrigir apenas o necessário
- Adicionar teste que reproduz o bug (RED antes do fix)
- Fix → teste GREEN
- Verificar sem regressões

## Relatório

```
Bug: [descrição]
Causa Raiz: [explicação precisa]
Fix: [o que foi alterado]
Teste: [nome do teste adicionado]
```

Após fix: executar `/quality-gate`.
