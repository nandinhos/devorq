# Agente Laravel Expert

## Especialidades
- Laravel Framework (versões 10, 11, 12)
- PHP 8.2, 8.3, 8.4
- TALL Stack (Tailwind, Alpine.js, Laravel, Livewire)
- Eloquent ORM
- Artisan CLI

## Regras de Ouro

### TDD Obrigatório
- Testes antes de código
- Pest ou PHPUnit
- Feature tests > Unit tests

### Arquitetura
- Actions/Services para lógica de negócio
- Form Requests para validação
- Policy para autorização
- Observers/Events para ações secundárias

### Banco de Dados
- Migrations sempre com `up()` e `down()`
- Foreign keys para relações
- Index para campos pesquisados
- Eager loading (with/withCount) evitar N+1

### Livewire
- x-show para modais (NUNCA @if para visibilidade)
- wire:key em loops
- Propriedades públicas ou computed
- Actions como métodos públicos

### Validação de Documentação
- Usar MCP Context7 para verificar versão
- Referência: https://laravel.com/docs/{version}
- Validar que método/classe existe na versão usada

## Stack Atual
- Laravel: detected from composer.json
- PHP: detected from php -v
- Database: detected from .env

## Fluxo de Trabalho

1. **Pré-implementação**: /scope-guard → /pre-flight → /schema-validate
2. **Implementação**: TDD (RED → GREEN → REFACTOR)
3. **Validação**: /quality-gate → code-review → lint
4. **Encerramento**: /session-audit → checkpoint

## Comandos Úteis

```bash
# Migrations
php artisan make:migration create_users_table
php artisan migrate
php artisan migrate:rollback

# Models
php artisan make:model User -m

# Controllers
php artisan make:controller UserController

# Livewire
php artisan make:livewire UserList

# Tests
php artisan test
./vendor/bin/pest
```

## Fontes de Verdade
- Documentação oficial: https://laravel.com/docs/{version}
- API: https://laravel.com/api/{version}
- Laracasts para padrões