---
name: integrity-guardian
description: Validar padrões Livewire e Alpine.js em arquivos Blade antes de commitar — bloqueia o Gate 3 se encontrar violações
triggers:
  - "integrity-guardian"
  - "validar livewire"
  - "validar alpine"
  - "integrity"
globs:
  - "resources/views/**/*.blade.php"
  - "resources/views/**/*.php"
---

# integrity-guardian — Guardião de Integridade TALL Stack

> **Regra de Ouro**: Nenhum commit com violações de padrão Livewire ou Alpine. Integrado ao /quality-gate para stack Laravel/TALL.

## Quando Usar

Executado automaticamente como etapa do `/quality-gate` quando a stack detectada é Laravel/TALL.
Pode ser chamado manualmente antes de qualquer commit com alterações em arquivos Blade.

## Verificações

### Nível ERRO — Bloqueiam o Gate 3

| Verificação | Padrão inválido | Padrão correto |
|-------------|-----------------|----------------|
| `@foreach` sem `wire:key` | `@foreach($items as $item)` sem `wire:key` | `@foreach($items as $item) <div wire:key="{{ $item->id }}">` |
| `wire:key` não único | `wire:key="item"` fixo em loop | `wire:key="{{ $loop->index }}-{{ $item->id }}"` |
| Alpine.js duplicado | Dois `x-data` no mesmo componente Livewire | Um único `x-data` por componente |
| `x-data` inline com lógica complexa | `x-data="{ open: false, toggle() {...} }"` em Blade | Extrair para `window.componentName = () => ({...})` |

### Nível AVISO — Reportar mas não bloquear

| Verificação | Situação | Recomendação |
|-------------|----------|--------------|
| `x-show` vs `x-if` | `x-show` em elementos grandes | Usar `x-if` para elementos raramente visíveis |
| `wire:model` sem `.live` | Formulários que precisam de reatividade imediata | Verificar se `.live` é necessário |
| `@entangle` sem `defer` | Sincronização desnecessária | Adicionar `.defer` se não precisar de tempo real |
| Componente sem `wire:key` em rotas dinâmicas | Componente dentro de loop sem key | Adicionar `wire:key` único |

## Execução

O LLM deve inspecionar todos os arquivos Blade modificados na sessão e verificar cada item acima.

### Report de Saída

```
=== INTEGRITY GUARDIAN ===
Stack: Laravel + Livewire 4 + Alpine.js

Arquivos verificados: 3
  - resources/views/livewire/contract-list.blade.php
  - resources/views/livewire/payable-form.blade.php
  - resources/views/components/card.blade.php

ERROS (bloqueiam Gate 3):
  ❌ contract-list.blade.php:15 — @foreach sem wire:key
     Linha: @foreach($contracts as $contract)
     Fix: adicionar wire:key="{{ $contract->id }}" no elemento filho

AVISOS (não bloqueiam):
  ⚠️ payable-form.blade.php:42 — x-show em elemento grande (considerar x-if)

Resultado: BLOQUEADO — corrigir 1 erro antes de commitar
==========================
```

Se tudo estiver correto:

```
=== INTEGRITY GUARDIAN ===
Arquivos verificados: 3
Erros: 0 | Avisos: 1

Resultado: APROVADO ✅ (1 aviso registrado)
==========================
```

## Integração com /quality-gate

O `/quality-gate` deve incluir o integrity-guardian como etapa adicional para stack TALL:

```
/quality-gate executa:
  1. Testes passando? (contagem exata)
  2. Lint passou? (Pint/ESLint)
  3. Escopo respeitado? (arquivos permitidos)
  4. DONE_CRITERIA atendido?
  5. [se TALL Stack] integrity-guardian ← esta etapa
  6. → Gate 3: usuário aprova antes de commitar
```

---

> **Débito que previne**: Bugs de Morph DOM do Livewire, duplicação de Alpine.js, wire:key ausente causando comportamento imprevisível em listas dinâmicas
