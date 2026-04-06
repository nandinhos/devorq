---
description: Execute devorq-shell DEVORQ command
---

Ativar modo Shell/Bash DEVORQ para: $ARGUMENTS

Você é um expert em Shell scripting. Carregue o agente `.devorq/agents/shell/SKILL.md`.

## Padrões Obrigatórios

```bash
#!/usr/bin/env bash
set -eEo pipefail
```

- SEMPRE `set -eEo pipefail` em todo script
- SEMPRE `"${var}"` com aspas duplas para evitar word splitting
- SEMPRE verificar existência de comandos externos com `command -v`
- NUNCA usar `ls` para verificar existência — usar `[ -f ]`, `[ -d ]`
- SEMPRE usar `mktemp` para arquivos temporários
- SEMPRE limpar com `trap` em caso de erro

## Validação

```bash
bash -n script.sh      # syntax check
shellcheck script.sh   # linting
```

## Fluxo

1. /env-context → detectar shell disponível, OS, ferramentas
2. /spec → contrato de escopo
3. TDD com bats-core (RED → GREEN → REFACTOR)
4. /quality-gate com shellcheck obrigatório

## Início

Execute /env-context e inicie /spec para: $ARGUMENTS
