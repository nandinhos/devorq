---
name: pre-flight
description: Validação de schema/enums/tipos antes de implementar código de domínio
triggers:
  - "pre-flight"
  - "schema"
  - "enums"
  - "validar antes"
  - "tipos"
globs:
  - "**/*.php"
  - "**/*.js"
  - "**/*.ts"
---

# /pre-flight - Validação Pré-Implementação

> **Regra de Ouro**: Se não verificou o schema, não escreveu código

## Quando Usar

**OBRIGATÓRIO** antes de:
- Criar/modificar migrations
- Criar novos models
- Criar novos enums/types
- Escrever testes unitários
- Implementar regras de negócio

## Propósito

1. **Eliminar tipos errados**: Evitar D8 (enums/tipos incorretos)
2. **Validar consistência**: Schema реальный vs código
3. **Documentar fontes**: De onde veio cada informação de tipo

## Processo

### Step 1: Identificar Domínio
- Qual módulo/feature?
- Quais tabelas/models afetados?
- Quais enums relevantes?

### Step 2: Carregar Artefatos

```bash
# Laravel/PHP
php artisan tinker
DB::getSchema()->getColumnListing('tabela')
App\Enums\*

# Node/JS
cat src/types/*.ts
cat prisma/schema.prisma
```

### Step 3: Validar Cada Tipo
Para cada tipo usado no código:
- ✅ Enum existe com esse nome?
- ✅ Valor usado está na lista válida?
- ✅ Campo existe com esse tipo?
- ✅ Foreign key aponta para tabela existente?

### Step 4: Report
```markdown
## PRE-FLIGHT REPORT

### Enum UserStatus
- Valores: ['active', 'inactive', 'suspended']
- Usado: UserStatus::active ✅

### Table: orders
- Colunas: id, user_id, total, status, created_at
- Status: ✅ VÁLIDO

### Operation: ADD COLUMN order_id
- References: orders(id) ✅
- Status: ✅ PERMITIDO
```

### Step 5: Bloqueio
Se inconsistency:
```
🛑 PRE-FLIGHT FALHOU!
- Problema: [descrição]
- Ação: PARAR e perguntar correção
```

## Anti-Patterns

| Errado | Certo |
|--------|-------|
| Usar enum sem verificar | Verificar existência |
| Assumir tipo de campo | Consultar schema |
| Não perguntar quando dúvida | Perguntar é melhor |

---

> **Débito que previne**: D8 (TDD sem validação de schema), D7 (constraints)