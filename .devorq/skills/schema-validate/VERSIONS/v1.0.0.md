---
name: schema-validate
description: Validar estrutura de banco antes de operações de dados
triggers:
  - "schema-validate"
  - "validar banco"
  - "validar migrations"
  - "constraints"
globs:
  - "database/migrations/*.php"
  - "**/Enums/*.php"
  - "app/Models/*.php"
---

# /schema-validate - Validação de Schema

> **Regra de Ouro**: Validate schema antes de qualquer operação de dados

## Quando Usar

**OBRIGATÓRIO** antes de:
- Criar/modificar migrations
- Queries com joins/foreign keys
- Adicionar/modificar dados em produção
- Criar novos models/relationships

## Validações

| Operação | Validar |
|----------|---------|
| Criar tabela | Colunas, tipos, indexes, FK |
| Adicionar coluna | Já existe? Tipo compatível? |
| Criar FK | Tabela/coluna referenciada existe? |
| Criar enum | Valores já existem? |
| Insert/Update | Constraints permite? Unique? |

## Report

```markdown
## SCHEMA VALIDATION

### Tabela: [nome]
- Colunas: [lista com tipos]
- Status: ✅ VÁLIDO / ❌ INVÁLIDO

### Enum: [nome]
- Valores: [lista]
- Status: ✅ VÁLIDO / ❌ INVÁLIDO

### Operação: [operação]
- Status: ✅ PERMITIDO / ❌ BLOQUEADO
```

---

> **Débito que previne**: D5, D6, D7