# CHANGELOG — pre-flight

## v1.2.0 (2026-04-07)

- Adição de comando grep no Step 2 para detecção de scripts dual-use sem guard.
- Verificação obrigatória no Step 3 para presença do guard `[[ "${BASH_SOURCE[0]}" != "$0" ]] && return 0`.
- Inclusão de `**/*.sh` nos globs monitorados pela skill.

## v1.0.0 (2026-03-31)

- Versão inicial da skill
