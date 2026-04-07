# CHANGELOG — quality-gate

## v1.2.0 (2026-04-07)

- Adição de regra obrigatória para o guard de source `[[ "${BASH_SOURCE[0]}" != "$0" ]] && return 0` em scripts dual-use.
- Inclusão de `**/*.sh` nos globs monitorados pela skill.

## v1.0.0 (2026-03-31)

- Versão inicial da skill
