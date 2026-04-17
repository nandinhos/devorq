# CHANGELOG — quality-gate

## v1.4.0 (2026-04-17)

- Passo 8 (Bash Dual-use Scripts): adicionadas regras para `set -eEo pipefail` dentro de `main()` e source guard com `if/fi`
- Previne falhas silenciosas ao fazer source de hooks em testes bats
- Referência: LESSON-0014-17-04-2026

## v1.3.0 (2026-04-16)

- Adição de Etapa 9 (validação manual da feature) com diálogo canônico
- Adição de Etapa 10 (preview do commit) com diálogo de aprovação literal
- Gate 3 v2: impossível pular — OK/N/A obrigatório na Etapa 9, A/Aprovado obrigatório na Etapa 10
- Referência: SPEC-0070

## v1.2.0 (2026-04-07)

- Adição de regra obrigatória para o guard de source `[[ "${BASH_SOURCE[0]}" != "$0" ]] && return 0` em scripts dual-use.
- Inclusão de `**/*.sh` nos globs monitorados pela skill.

## v1.0.0 (2026-03-31)

- Versão inicial da skill
