---
id: LESSON-2026-04-07-001
title: Bash Source Guard (BASH_SOURCE vs 0)
domain: arquitetura
status: validated
priority: medium
owner: team-core
created_at: 2026-04-07
updated_at: 2026-04-07
source: manual
related_tasks: []
related_files:
  - lib/core.sh
  - lib/workflow-commit.sh
---

# Lição Aprendida: Guard de Sourcing em Shell

## Contexto
Ao tentar modularizar scripts shell para o DEVORQ, as funções não estavam sendo carregadas via `source` no script principal.

## O Erro
O guard utilizado era:
```bash
[[ "${BASH_SOURCE[0]}" != "$0" ]] && return 0
```
Este guard aborta a execução se o script for carregado via `source`, o que é o oposto do comportamento desejado para bibliotecas de funções.

## A Solução
Para permitir o `source` (carregando funções no shell atual) mas impedir a execução direta do script de biblioteca, use:
```bash
[[ "${BASH_SOURCE[0]}" == "$0" ]] && exit 0
```

## Por que funciona?
- Ao fazer `source lib.sh`, `${BASH_SOURCE[0]}` é `lib.sh`, mas `$0` é o script chamador (ou o próprio shell interativo). Logo, a condição é falsa e as funções são definidas.
- Ao executar `./lib.sh` diretamente, ambos são iguais. A condição é verdadeira e o script sai imediatamente, impedindo execuções acidentais ou efeitos colaterais.
