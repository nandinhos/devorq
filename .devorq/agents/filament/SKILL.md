# Agente Filament Expert

## Especialidades
- Filament v2 e v3
- Admin panels Laravel
- Form Builders
- Table Builders
- Resource Eloquent
- Widgets

## Regras de Ouro

### Estrutura de Resource
- Um Resource para cada entidade
- Schemas organizados em grupos
- Columns para listagem
- Actions para operações (Create, Edit, Delete, View)

### Form Fields
- Sempre usar Field::make() com método chain
- Validação via rules() method
- Relationships via relationship() ou belongsToMany()
- File uploads via FileUpload

### Tables
- Columns::make() com métodos de formatação
- Filters para pesquisas comuns
- Actions com confirmação para operações destructivas
- Pagination configurável

### Relatórios
- Widgets para dashboards
- StatsOverviewWidget para métricas
- ChartWidget para gráficos

## Validação de Documentação
- Referência: https://filamentphp.com/docs/{version}
- MCP Context7 para buscar documentação específica
- Validar que método existe na versão do Filament instalada

## Stack Atual
- Filament: detected from composer.json
- Laravel: detected from composer.json
- PHP: detected from php -v

## Fluxo de Trabalho

1. **Planejamento**: /scope-guard define o que o panel precisa
2. **Model**: Criar migration e model primeiro
3. **Resource**: Gerar Resource com php artisan make:filament-resource
4. **Customização**: Adicionar campos, relações, actions
5. **Validação**: /quality-gate antes de commit

## Comandos Úteis

```bash
# Resources
php artisan make:filament-resource User
php artisan make:filament-relation-manager User posts

# Widgets
php artisan make:filament-widget StatsOverview

# Forms
php artisan make:filament-form UserForm

# Tables
php artisan make:filament-table UserTable
```

## Padrões Importantes

```php
// Resource completo
class UserResource extends Resource
{
    protected static ?string $model = User::class;
    
    public static function form(Form $form): Form
    {
        return $form
            ->schema([
                // Fields aqui
            ]);
    }
    
    public static function table(Table $table): Table
    {
        return $table
            ->columns([
                // Columns aqui
            ])
            ->filters([
                // Filters aqui
            ])
            ->actions([
                // Actions aqui
            ]);
    }
}
```

## Fontes de Verdade
- Documentação: https://filamentphp.com/docs/
- GitHub: https://github.com/filamentphp/filament