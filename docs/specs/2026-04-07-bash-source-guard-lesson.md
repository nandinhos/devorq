---
id: SPEC-2026-04-07-001
title: Incorporar Lição Bash Source Guard nas Skills
domain: arquitetura | operacao
status: draft
priority: high
owner: team-core
created_at: 2026-04-07
updated_at: 2026-04-07
source: manual
related_tasks: []
related_files:
  - ".devorq/skills/quality-gate/SKILL.md"
  - ".devorq/skills/pre-flight/SKILL.md"
---

# Spec — Incorporar Lição Bash Source Guard

**Data**: 2026-04-07
**Status**: draft
**Autor**: Antigravity

## Objetivo

Implementar a lição aprendida em `2026-04-07-bash-dual-use-source-guard.md` para evitar que scripts Bash que funcionam como biblioteca e executável (dual-use) executem lógicas de CLI indesejadas quando forem carregados via `source`.

## Fora do Escopo

- Refatoração de scripts existentes em `lib/` (a correção real dos scripts será feita em outra sessão).
- Alteração de outros checklists não relacionados ao Bash.

## Regras de Negócio

1. **Quality Gate**: Todo script Bash dual-use **deve** conter o guard `[[ "${BASH_SOURCE[0]}" != "$0" ]] && return 0` antes de qualquer bloco `case` ou execução direta.
2. **Pre-flight**: O sistema deve alertar sobre a ausência deste guard em arquivos dentro de `lib/**/*.sh` durante a fase de planejamento.
3. **Versionamento**: Ambas as skills (`quality-gate` e `pre-flight`) devem ter suas versões incrementadas (minor bump) após a implementação.

## Páginas / Telas (Skills)

| Skill | Modificação | Comportamento Esperado |
|-------|-------------|-------------------------|
| `quality-gate` | Novo item no checklist | Bloquear commit se o guard estiver ausente em scripts dual-use. |
| `pre-flight` | Nova verificação em `lib/` | Avisar o desenvolvedor sobre scripts vulneráveis antes da implementação. |

## Gate de Aprovação

Revise esta especificação.
- Algo está incorreto ou faltando?
- Posso prosseguir para os reports de Pre-flight?

[AGUARDANDO APROVAÇÃO]
