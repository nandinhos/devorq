# Regras de Desenvolvimento - Laravel/TALL Stack

## Stack
- **Framework**: Laravel 10, 11, 12
- **PHP**: 8.2, 8.3, 8.4
- **Frontend**: Tailwind CSS + Alpine.js
- **Interactive**: Livewire
- **Admin**: Filament (quando aplicável)

## Regras de Ouro

### 1. TDD Obrigatório
- Testes primeiro, código depois
- Pest ou PHPUnit
- Feature tests para fluxos completos
- Coverage mínimo: 80% em features novas

### 2. Arquitetura Clean
```
Controllers/   → Receber request, retornar response
Actions/      → Lógica de negócio
Services/     → Lógica reutilizável
Repositories/ → Acesso a dados
Models/       → Representação de dados (NUNCA lógica)
```

### 3. Livewire Rules
- **SEMPRE** `x-show` para modais e dropdowns
- **NUNCA** `@if` para visibilidade de elementos
- **SEMPRE** `wire:key` em loops
- Props públicas ou `$get` computed
- Actions como métodos públicos da classe

### 4. Tailwind Rules
- Utility classes first
- Components em `resources/views/components/`
- Não usar CSS customizado se Tailwind resolver

### 5. Alpine.js Rules
- Só usar se Livewire não resolver
- dados() para estado local
- x-model para two-way binding

### 6. Database Rules
- **SEMPRE** eager loading com `with()` ou `withCount()`
- **NUNCA** acesso em loop (N+1)
- Migrations reversíveis (up/down)
- Foreign keys para relações
- Index em campos pesquisados

### 7. Form Requests
- **SEMPRE** FormRequest para validação
- **NUNCA** `$request->validate()` inline no controller

### 8. Git/Lint
- Pre-commit hook com Pint
- Pre-commit hook com PHPStan (nível 6)
- Conventional Commits (pt-BR)

## Checklist Pré-Commit

- [ ] Testes passando
- [ ] Pint passou
- [ ] PHPStan passou (nível 6)
- [ ] Nenhum N+1 query
- [ ] Form Request para validação
- [ ] Livewire usa x-show (não @if)
- [ ] Arquivos modificados estão no escopo

## Comandos de Verificação

```bash
# Testes
php artisan test
./vendor/bin/pest --coverage

# Lint
./vendor/bin/pint
./vendor/bin/phpstan analyse --level=6

# Cache
php artisan optimize:clear
```

## Fontes de Verdade

- Laravel: https://laravel.com/docs/{version}
- Livewire: https://livewire.dev/docs/
- Tailwind: https://tailwindcss.com/docs
- Alpine: https://alpinejs.dev/upgrade-from-v2

> **Regra**: Validar documentação com MCP Context7 antes de implementar