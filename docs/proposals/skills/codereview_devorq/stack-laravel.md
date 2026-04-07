# Referência: Laravel / PHP — Regras Específicas de Code Review

Aplique estas regras **além** das regras universais do SKILL.md principal.

---

## VERSÕES & COMPATIBILIDADE

```bash
# Verificar versões declaradas
grep -E '"php"|"laravel/framework"' composer.json
cat .php-version 2>/dev/null

# Packages desatualizados
composer outdated --direct 2>/dev/null | head -20

# Vulnerabilidades conhecidas
composer audit 2>/dev/null
```

Alertas:
- PHP < 8.2 em projeto novo → débito imediato
- Laravel < 10 sem plano de upgrade → risco de segurança
- Packages com `abandoned` no Packagist

---

## ELOQUENT & BANCO DE DADOS

### N+1 Queries (crítico em Laravel)
```bash
# Procurar relações carregadas dentro de loops
grep -rn "foreach\|->each" app/ --include="*.php" | head -20
# Verificar se usa ->with() ou ->load() antes dos loops

# Procurar lazy loading sem eager load configurado
grep -rn "\$model->" app/ --include="*.php" | grep -v "->where\|->select\|->with\|->load" | head -15
```

Padrões problemáticos:
```php
// ❌ N+1 clássico
foreach ($orders as $order) {
    echo $order->user->name; // query por iteração
}

// ✅ Correto
$orders = Order::with('user')->get();
```

### Migrations
```bash
# Migrations sem índices em colunas de busca
grep -rn "foreignId\|->string\|->integer" database/migrations/ | grep -v "index\|unique\|primary" | head -20

# Migrations com operações destrutivas sem down() seguro
grep -rn "dropColumn\|dropTable\|drop(" database/migrations/ | head -10
```

Verificar:
- `->index()` em todas as colunas de FK e campos usados em WHERE
- `->nullable()` justificado (não usado como escape de validação)
- Migrations reversíveis — método `down()` coerente com `up()`
- Nenhuma lógica de negócio dentro de migrations

### Scopes & Queries
```php
// ❌ Lógica espalhada nos controllers
User::where('active', 1)->where('role', 'admin')->where('created_at', '>', now()->subDays(30))

// ✅ Escopo semântico e reutilizável
User::active()->admin()->recentlyCreated()
```

---

## ARQUITETURA LARAVEL

### Controllers
```bash
# Controllers muito grandes (> 150 linhas é alerta)
find app/Http/Controllers -name "*.php" | xargs wc -l | sort -rn | head -10

# Lógica de negócio vazando para controllers
grep -rn "DB::\|Mail::\|Queue::\|Storage::" app/Http/Controllers/ | grep -v vendor | head -15
```

Sinais de alerta:
- Controller com mais de 7 métodos públicos
- Lógica condicional complexa dentro de controller
- Acesso direto a `DB::` no controller (deveria estar em Repository/Service)
- Request manipulada dentro de múltiplas camadas

### Services & Actions
Verificar se existe separação clara:
```
app/
├── Actions/         # Single-responsibility actions
├── Services/        # Domain services
├── Http/Controllers # Thin controllers
└── Models/          # Eloquent sem lógica de negócio
```

### Form Requests
```bash
# Validação inline em controller (deveria estar em FormRequest)
grep -rn "\$request->validate(" app/Http/Controllers/ | head -10

# FormRequests sem authorize() implementado
grep -rn "return true" app/Http/Requests/ | head -10
```

---

## SEGURANÇA LARAVEL-ESPECÍFICA

### Mass Assignment
```bash
# Models sem $fillable ou com $guarded = []
grep -rn "protected \$guarded = \[\]" app/Models/ | head -10
grep -rn "protected \$fillable" app/Models/ | head -20
```

### Policies & Authorization
```bash
# Endpoints de resource sem policy
grep -rn "Route::" routes/ | grep -E "resource|apiResource" | head -10
# Verificar se Policy correspondente existe em app/Policies/

# Controllers sem autorização
grep -rn "public function " app/Http/Controllers/ | grep -v "vendor\|__construct\|middleware" | head -20
# Verificar se cada método tem $this->authorize() ou Gate::authorize()
```

### SQL Injection
```php
// ❌ Vulnerável
DB::select("SELECT * FROM users WHERE email = '$email'");

// ✅ Parametrizado
DB::select("SELECT * FROM users WHERE email = ?", [$email]);
// ou
User::where('email', $email)->first();
```

```bash
grep -rn 'DB::select.*\$\|DB::statement.*\$\|whereRaw.*\$' app/ | grep -v vendor | head -10
```

### CSRF
```bash
# Rotas POST sem proteção CSRF (fora de API)
grep -rn "Route::post\|Route::put\|Route::delete\|Route::patch" routes/web.php | head -20
# Verificar se estão dentro de grupo com middleware 'web'
grep -rn "->withoutMiddleware\|'csrf'" routes/ app/ | head -10
```

---

## FILAMENT V4 (se detectado)

```bash
# Verificar versão
grep "filament/filament" composer.json

# Resources sem policies registradas
find app/Filament/Resources -name "*Resource.php" | xargs grep -l "canCreate\|canEdit\|canDelete" | head -10

# Widgets sem cache configurado
grep -rn "class.*Widget" app/Filament/Widgets/ | head -10
```

Padrões a verificar:
- `Resource::getPages()` com rotas desnecessárias expostas
- Actions sem confirmação em operações destrutivas
- Bulk actions sem autorização granular
- Forms sem `disabled()` em campos que não devem ser editados
- Falta de `->searchable()->sortable()` em colunas de listagem importantes

---

## LIVEWIRE (se detectado)

```bash
# Componentes Livewire
find app/Livewire app/Http/Livewire -name "*.php" 2>/dev/null | head -20
```

Padrões problemáticos:
```php
// ❌ Propriedade pública com dado sensível (exposto ao front)
public $userPassword;

// ❌ Query sem autorização dentro de render()
public function render() {
    return view('livewire.orders', [
        'orders' => Order::all() // sem filtro do usuário atual
    ]);
}

// ❌ Ação sem validação
public function save() {
    $this->user->update($this->all()); // mass assignment sem validação
}
```

Verificar:
- `#[Locked]` em propriedades que não devem ser alteradas pelo usuário
- `#[Validate]` ou `$rules` definidos em todos os components com formulário
- Métodos `mount()` validando que o usuário tem acesso ao recurso passado
- Eventos Livewire não exposindo dados além do necessário

---

## QUEUES & JOBS

```bash
grep -rn "implements ShouldQueue" app/ | grep -v vendor | head -10
```

Verificar em cada Job:
- `$tries` definido (não infinito)
- `$timeout` configurado
- `failed()` método implementado com logging/notificação
- Idempotência — re-executar o job não causa duplicação
- Dados mínimos no constructor (não serializar Models inteiros desnecessariamente)

---

## TESTES COM PEST (se detectado)

```bash
# Ver cobertura de Features críticas
find tests/Feature -name "*.php" | head -20
find tests/Unit -name "*.php" | head -20

# Testes sem assertions reais
grep -rn "->assertTrue(true)\|expect(true)" tests/ | head -5
```

Padrões a verificar:
- Cada endpoint de API tem teste de `Feature`?
- Policies testadas com usuários com e sem permissão?
- Edge cases: usuário sem dados, payload vazio, IDs inválidos?
- Factories cobrindo todos os estados relevantes do Model?
- Testes usando `RefreshDatabase` ou `DatabaseTransactions` corretamente?

```php
// ❌ Teste sem valor
it('creates a user', function () {
    $user = User::factory()->create();
    expect($user)->not->toBeNull(); // óbvio, não testa comportamento
});

// ✅ Teste com valor real
it('prevents duplicate email registration', function () {
    User::factory()->create(['email' => 'test@test.com']);
    
    $response = $this->postJson('/api/register', ['email' => 'test@test.com']);
    
    $response->assertUnprocessable()
             ->assertJsonValidationErrors(['email']);
    expect(User::count())->toBe(1);
});
```

---

## CONFIGURAÇÃO & AMBIENTE

```bash
# Config hardcoded que deveria ser .env
grep -rn "localhost\|127\.0\.0\.1\|root\|password" config/ | grep -v ".env\|example" | head -10

# Cache de config em produção
cat .env | grep APP_ENV
# Se APP_ENV=production, verificar se config:cache está no deploy

# Debug mode em produção
grep "APP_DEBUG" .env | head -3
```

Verificar:
- `APP_DEBUG=false` em produção
- `APP_ENV=production` com configurações corretas
- Logs não expostos publicamente (`storage/logs` fora do `public/`)
- `php artisan key:generate` foi executado (APP_KEY configurado)
