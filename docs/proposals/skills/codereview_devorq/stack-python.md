# Referência: Python / Django / FastAPI — Regras Específicas de Code Review

Aplique estas regras **além** das regras universais do SKILL.md principal.

---

## VERSÕES & AMBIENTE

```bash
python --version 2>/dev/null; cat .python-version 2>/dev/null
cat requirements.txt pyproject.toml 2>/dev/null | head -20

# Vulnerabilidades
pip-audit 2>/dev/null | head -20
safety check 2>/dev/null | head -10
```

---

## DJANGO (se detectado)

### ORM & Queries
```bash
# N+1 em Django
grep -rn "for.*in.*\.objects\|for.*in.*queryset\|for.*in.*all()" . --include="*.py" | grep -v migrations | grep -v test | head -10
```

```python
# ❌ N+1 clássico
for order in Order.objects.all():
    print(order.user.name)  # query por iteração

# ✅ Correto
for order in Order.objects.select_related('user').all():
    print(order.user.name)

# ❌ ManyToMany sem prefetch
for post in Post.objects.all():
    print(post.tags.all())  # N+1

# ✅ Correto
for post in Post.objects.prefetch_related('tags').all():
    print(post.tags.all())
```

### Segurança Django
```bash
# Settings de segurança
grep -E "DEBUG|SECRET_KEY|ALLOWED_HOSTS|CSRF|SECURE_" settings.py config/settings*.py 2>/dev/null

# SQL raw sem parametrização
grep -rn "\.raw(\|execute(" . --include="*.py" | grep -v migrations | grep "%\|format\|f'" | head -10
```

Verificar:
- `DEBUG = False` em produção
- `SECRET_KEY` não hardcoded (via env)
- `ALLOWED_HOSTS` não é `['*']` em produção
- `CSRF_COOKIE_SECURE = True` com HTTPS
- `SECURE_HSTS_SECONDS` configurado

### Views & Permissions
```bash
grep -rn "def get\|def post\|def put\|def delete" . --include="*.py" | grep -v test | grep -v migrations | head -20
# Verificar se cada view tem @login_required ou permission_classes
```

---

## FASTAPI (se detectado)

### Tipagem & Validação
```python
# ❌ Sem validação de input
@app.post("/users")
async def create_user(data: dict):  # dict aceita qualquer coisa
    ...

# ✅ Pydantic valida automaticamente
@app.post("/users")
async def create_user(data: UserCreateSchema):
    ...
```

```bash
# Rotas sem schema de resposta (response_model)
grep -rn "@app\.\|@router\." . --include="*.py" | grep -v "response_model\|include_router" | head -10
```

### Async Correto
```python
# ❌ Operação bloqueante em contexto async
@app.get("/data")
async def get_data():
    time.sleep(1)  # BLOQUEIA o event loop
    data = requests.get(url)  # sync dentro de async

# ✅ Usar await com bibliotecas async
@app.get("/data")
async def get_data():
    await asyncio.sleep(1)
    async with httpx.AsyncClient() as client:
        data = await client.get(url)
```

---

## PYTHON GERAL

### Tratamento de Exceções
```bash
grep -rn "except:\|except Exception:" . --include="*.py" | grep -v test | grep -v vendor | head -10
```

```python
# ❌ Catch-all silencia tudo
try:
    result = risky_operation()
except:  # pega KeyboardInterrupt, SystemExit, etc.
    pass

# ✅ Específico e com logging
try:
    result = risky_operation()
except (ValueError, ConnectionError) as e:
    logger.error("Operation failed", exc_info=True)
    raise
```

### Type Hints
```bash
# Funções sem type hints (em projeto que usa tipos)
grep -rn "^def \|^    def " . --include="*.py" | grep -v "def __\|-> \|test_\|#" | head -15
```

### Variáveis de Ambiente
```bash
grep -rn "os\.environ\['\|os\.getenv(" . --include="*.py" | grep -v test | head -10
# Verificar se há fallback seguro ou falha explícita se var não definida
```

```python
# ❌ KeyError se DATABASE_URL não definida
db_url = os.environ['DATABASE_URL']

# ✅ Falha explícita com mensagem útil
db_url = os.environ.get('DATABASE_URL')
if not db_url:
    raise ValueError("DATABASE_URL environment variable is required")
```

---

## TESTES (Pytest)

```bash
find . -name "test_*.py" -o -name "*_test.py" | grep -v node_modules | head -20

# Fixtures compartilhadas
cat conftest.py 2>/dev/null | head -30
```

Verificar:
- Fixtures limpam estado após cada teste? (`yield` com cleanup)
- Testes de integração usam banco de testes separado?
- `mock.patch` aplicado no lugar correto (onde o objeto é usado, não onde é definido)?
- Parametrize usado para evitar código duplicado em testes similares?
