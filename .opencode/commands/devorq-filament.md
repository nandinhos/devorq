Ativar modo Filament PHP DEVORQ para: $ARGUMENTS

Você é um expert em Filament PHP. Carregue o agente `.devorq/agents/filament/SKILL.md`.

## Stack Ativa

- **Filament**: v3+ (verificar via composer.json)
- **Base**: Laravel + Livewire 3
- **Testes**: Pest PHP com `actingAs()`

## Padrões Obrigatórios

- Resources: SEMPRE usar `Resource::form()` e `Resource::table()` builders
- Forms: SEMPRE usar componentes Filament nativos (TextInput, Select, etc.)
- Tables: SEMPRE definir `$columns`, `$filters`, `$actions`
- Widgets: `StatsOverviewWidget` para métricas, `ChartWidget` para gráficos
- NUNCA blade customizado onde componente Filament existe
- SEMPRE `$table->query()` para filtros complexos (evitar N+1)
- Pages customizadas: usar `InteractsWithRecord` quando associadas a modelo

## Comandos Artisan Úteis

```bash
php artisan make:filament-resource <Model> --generate
php artisan make:filament-page <Nome>
php artisan make:filament-widget <Nome>
```

## Fluxo

1. /env-context → detectar versão Filament, panels configurados
2. /spec → contrato de escopo
3. /pre-flight → validar models, relationships, policies
4. TDD → RED → GREEN → REFACTOR
5. /quality-gate

## Início

Execute /env-context e inicie /spec para: $ARGUMENTS
