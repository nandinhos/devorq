Inicializar projeto DEVORQ v2.1.

Execute a sequência de inicialização completa:

## Step 1 — Detecção de Stack

Executar:
```bash
./bin/devorq init
./bin/devorq context
```

Se o binário não existir, detectar manualmente:
- `composer.json` → PHP/Laravel
- `package.json` → Node/JS
- `requirements.txt` / `pyproject.toml` → Python
- `Makefile` + `Dockerfile` → infra

## Step 2 — Classificar Projeto

Responder:
- **Greenfield**: sem código existente
- **Brownfield**: código existente + testes
- **Legacy**: código existente sem testes

## Step 3 — Detectar Runtime

Para Laravel:
```bash
# Verificar qual runtime usar:
[ -f vendor/bin/sail ] && echo "Sail disponível"
[ -f artisan ] && echo "artisan local"
docker ps 2>/dev/null && echo "Docker ativo"
```

## Step 4 — Criar Contexto

Salvar resultado em `.devorq/state/context.json`:
```json
{
  "stack": "laravel|python|nodejs|php|shell",
  "runtime": "sail|artisan|python|node|bash",
  "database": "mysql|postgres|sqlite",
  "llm": "claude|gemini|antigravity|opencode",
  "type": "greenfield|brownfield|legacy",
  "date": "YYYY-MM-DD"
}
```

## Step 5 — Resumo

Apresentar resumo de inicialização e confirmar se o usuário quer prosseguir para `/spec`.
