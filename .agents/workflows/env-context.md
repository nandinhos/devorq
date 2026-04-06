---
description: Execute env-context DEVORQ command
---

Detectar e reportar contexto completo do ambiente do projeto.

Leia `.devorq/skills/env-context/SKILL.md` para instruções completas.

## Detecções Automáticas

Execute os seguintes checks:

```bash
# Stack
[ -f composer.json ] && cat composer.json | grep '"laravel/framework"'
[ -f package.json ] && cat package.json | grep '"name"'
[ -f requirements.txt ] && head -5 requirements.txt
[ -f pyproject.toml ] && grep "^name" pyproject.toml

# Runtime Laravel
[ -f vendor/bin/sail ] && vendor/bin/sail --version
[ -f artisan ] && php artisan --version

# Docker
docker ps 2>/dev/null | grep -E "laravel|app|web"

# Git
git branch --show-current
git log --oneline -1

# Banco de dados
[ -f .env ] && grep "DB_" .env | grep -v PASSWORD
```

## Relatório

```markdown
# ENV CONTEXT — [data]

## Stack
- Framework: [laravel|symfony|django|fastapi|express|none]
- Versão: [x.y.z]
- PHP/Python/Node: [versão]

## Runtime
- Comando base: [php artisan | vendor/bin/sail artisan | python | node]
- Docker: [sim/não — container name se sim]
- Portas: app=[porta] db=[porta]

## Banco de Dados
- Driver: [mysql|postgres|sqlite]
- Porta: [3306|5432]

## LLM Atual
- [claude|gemini|antigravity|opencode]

## Tipo de Projeto
- [greenfield|brownfield|legacy]
```

Salvar em `.devorq/state/context.json` e apresentar resumo.
