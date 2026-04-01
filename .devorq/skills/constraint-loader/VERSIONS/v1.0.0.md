---
name: constraint-loader
description: Carregar automaticamente artefatos relevantes do projeto por tipo de task antes de implementar
triggers:
  - "constraint-loader"
  - "carregar constraints"
  - "carregar contexto"
globs:
  - ".devorq/state/context.json"
  - "app/Models/"
  - "app/Enums/"
  - "routes/"
  - "database/migrations/"
---

# /constraint-loader — Carregador de Artefatos por Tipo de Task

> **Regra de Ouro**: Nunca implementar com contexto parcial. Esta skill é chamada automaticamente pelo /pre-flight.

## Quando Usar

Chamado automaticamente pelo `/pre-flight` antes de qualquer implementação.
Pode ser chamado manualmente quando o tipo de task mudar durante a sessão.

## Tipos de Task e Artefatos

### Feature Livewire

Artefatos a carregar:
- Componentes Livewire existentes em `app/Livewire/` ou `app/Http/Livewire/`
- Models relacionados à feature (ler propriedades e relacionamentos)
- Enums usados pela feature (valores exatos)
- Views Blade do componente se já existir

Verificações obrigatórias:
- Todo `@foreach` em Blade tem `wire:key`?
- Componentes Alpine.js inicializados corretamente (sem duplicação)?

### Feature API / Controller

Artefatos a carregar:
- Rotas existentes em `routes/api.php` e `routes/web.php`
- Form Requests relacionados em `app/Http/Requests/`
- Resources em `app/Http/Resources/`
- Policies relevantes em `app/Policies/`

### Migration / Schema

Artefatos a carregar:
- Schema atual das tabelas afetadas (últimas migrations)
- Foreign keys existentes
- Enums de banco (se MySQL 8+)
- Seeds relacionados

### Bugfix

Artefatos a carregar:
- Arquivo(s) suspeitos apontados no /scope-guard
- Testes que cobrem a funcionalidade afetada
- Log de erro completo (se disponível)

### Refactor / Extract

Artefatos a carregar:
- Arquivo a refatorar (completo)
- Classes que dependem do arquivo
- Testes existentes (não podem quebrar)

## Output

Após carregar, apresentar resumo:

```
=== CONSTRAINT LOADER ===
Tipo de task: Feature Livewire
Stack: Laravel 12 + Livewire 4

Artefatos carregados:
- Enums: CashflowType (ENTRADA|SAIDA|TRANSFERENCIA), ContractStatus (PENDING|ACTIVE|COMPLETED)
- Models: Contract (id, value, status, cashflow_type), Payable (id, contract_id, due_date)
- Componentes existentes: ContractList, PayableForm
- Rotas disponíveis: /contracts, /contracts/{id}/payables

Verificações:
- wire:key: presente em todos os @foreach ✅
- Alpine.js: sem duplicação detectada ✅

Contexto pronto para /pre-flight.
=========================
```

## Integração com /pre-flight

O `/pre-flight` deve chamar o `/constraint-loader` como primeira etapa:

```
/pre-flight executa:
  1. constraint-loader (carrega artefatos por tipo)
  2. valida enums declarados contra enums carregados
  3. valida tipos e propriedades
  4. apresenta relatório → Gate 2
```

---

> **Débito que previne**: Enums errados, propriedades inexistentes, redeclaração de código existente
