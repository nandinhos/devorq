---
name: env-context
description: Detectar automaticamente stack, ambiente, binários e gotchas na primeira mensagem
triggers:
  - "env-context"
  - "ambiente"
  - "Docker"
  - "portas"
  - "stack"
---

# /env-context - Contexto Automático de Ambiente

> **Regra de Ouro**: Primeira mensagem = contexto, sempre

## Quando Usar

**OBRIGATÓRIO** - primeira mensagem de toda nova sessão ou após 30min de inatividade

## Propósito

1. **Eliminar debugging evitável**: Docker, portas, binários
2. **Detectar stack**: Laravel, Node, Python, etc
3. **Identificar ambiente**: Local, staging, produção
4. **Mapear gotchas**: Armadilhas conhecidas do projeto

## Processo

### Step 1: Detectar Projeto
```bash
# Identificar projeto
ls -la
cat .env 2>/dev/null | head -10
cat composer.json 2>/dev/null | head -5
cat package.json 2>/dev/null | head -5
```

### Step 2: Detectar Stack
```bash
# PHP/Laravel
php -v
cat artisan 2>/dev/null | head -3

# Node
node -v
npm -v

# Detectar via arquivos
ls *.{json,php,py,rs,go} 2>/dev/null
```

### Step 3: Detectar Ambiente
```bash
# Docker?
docker ps 2>/dev/null
docker-compose.yml

# Ports?
docker-compose ps 2>/dev/null

# Binários disponíveis?
which php node python mysql mysqldump 2>/dev/null
```

### Step 4: Detectar Gotchas
```bash
# Known issues do projeto
cat .env 2>/dev/null | grep -E "WWWUSER|DB_|APP_"
cat docker-compose.yml 2>/dev/null | grep -E "ports:|image:"
```

### Step 5: Gerar Contexto
```markdown
=== DEVORQ ENVIRONMENT CONTEXT ===

Project: [nome-do-projeto]
Stack: [PHP 8.x / Laravel 12.x / MySQL 8.x]
Runtime: [Docker/Sail/Local/Host]
Commands Prefix: [vendor/bin/sail | docker exec | npm run]
Ports: [80:8080, 3306:3306]
Binários Disponíveis: [php, composer, artisan, npm, mysql]
GOTCHAS: [
  - "Docker: usar WWWUSER=no usuário",
  - "Vite: npm run build após assets",
  - "DB: local=MySQL, prod=PostgreSQL"
]

LLM Atual: [Antigravity/Gemini/MiniMax/Claude]
===
```

## Exemplo de Output

```
=== DEVORQ ENVIRONMENT CONTEXT ===

Project: gacpac-ti
Stack: Laravel 12, PHP 8.4, MySQL 8.4
Runtime: Docker (Sail)
Commands: vendor/bin/sail [comando]
Ports: 80->8080, 3306->3306
GOTCHAS: [
  - PERMISSÃO: WWWUSER=1000 no .env
  - VITE: sempre npm run build após assets
  - DB: não usar SQLite (prod usa PostgreSQL)
]

LLM Atual: Antigravity (detectado via prompt)
===
```

## Decisão de Stack (Greenfield vs Brownfield vs Legado)

### Greenfield
- PRD existe?
- ERD existe?
- Estrutura inicial a criar

### Brownfield (Projeto em andamento)
- Analisar código existente
- Respeitar padrões encontrados
- Usar /learned-lesson para documentar armadilhas

### Legado (Refatoração necessária)
- Identificar tech debt
- Mapear dependências
- Planejar refatoração incremental

---

> **Débito que previne**: D17 (Environment não declarado), D2 (Docker permissions)