---
id: LESSON-0014-17-04-2026
title: set -eEo pipefail global quebra source de hooks em testes bats
domain: arquitetura
status: applied
priority: high
owner: team-core
created_at: 2026-04-17
updated_at: 2026-04-17
source: spec-completion
related_tasks: []
related_files:
  - .devorq/hooks/post-commit
  - tests/post-commit.bats
applied_to: "skill:quality-gate"
spec_origin: SPEC-0071-16-04-2026
---

# Lição Aprendida — LESSON-0014-17-04-2026

## O QUE FOI IMPLEMENTADO

Hook post-commit dual-use (executável diretamente + sourceable via testes bats).

## DESAFIOS ENCONTRADOS

Dois problemas consecutivos ao tentar source o hook no setup() do bats:

**Problema 1** — `set -eEo pipefail` no nível global do script.
Quando o hook é carregado via `source` pelo bats, o `set -e` passa a valer
no shell do bats. Qualquer comando que retorne falso após o source falha
silenciosamente ou derruba o test case.

**Problema 2** — `[[ "${BASH_SOURCE[0]}" == "$0" ]] && main "$@"` com `set -e` ativo.
Quando sourced, a condição `[[...]]` é falsa → o `&&` não executa `main`.
Com `set -e` ativo, uma expressão que retorna código != 0 aborta o shell.
Resultado: `source "$HOOK"` retornava exit 1, falhando todos os 15 testes.

## FIX APLICADO

1. Mover `set -eEo pipefail` para dentro de `main()` — não afeta o shell
   que faz source.
2. Substituir `[[ cond ]] && cmd` por `if [[ cond ]]; then cmd; fi` — a
   forma `if/fi` não propaga exit code da condição falsa para `set -e`.

## LIÇÕES PRINCIPAIS

- [ ] `set -eEo pipefail` nunca deve ficar no nível global de scripts
  dual-use (executável + sourceable). Sempre mover para `main()`.
- [ ] Source guard deve usar `if/fi`, nunca `[[ cond ]] && cmd`, quando
  `set -e` pode estar ativo no shell chamador.
- [ ] Padrão correto para hook dual-use:
  ```bash
  # Nível global: apenas definições de funções
  funcao_a() { ... }
  funcao_b() { ... }

  main() {
      set -eEo pipefail
      [ -t 1 ] || exit 0   # guards aqui
      ...
  }

  if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then main "$@"; fi
  ```

## PRÓXIMOS PASSOS

Avaliar se essa regra deve entrar no checklist do quality-gate para
scripts Bash marcados como dual-use.
