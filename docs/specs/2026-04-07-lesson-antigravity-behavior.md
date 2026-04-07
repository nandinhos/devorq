---
id: LESSON-2026-04-07-002
title: Comportamento do Antigravity em Governança de Front Matter
domain: arquitetura
status: validated
priority: medium
owner: team-core
created_at: 2026-04-07
updated_at: 2026-04-07
source: manual
related_tasks: ["TASK-HANDOFF-ANTIGRAVITY"]
related_files:
  - docs/specs/2026-04-07-estudo-caso-antigravity.md
  - bin/spec-index
  - prompts/antigravity.md
---

# Lição Aprendida: Comportamento do Antigravity em Governança Estrita

## Contexto

Durante o estudo de caso SPEC-2026-04-07-004, o Antigravity foi ativado via Handoff Adaptativo para operar sob a governança DEVORQ v2.1 e validar/corrigir specs com Front Matter canônico.

## Falhas Identificadas no Ecossistema (Pré-Antigravity)

Ao receber o handoff, o Antigravity identificou 5 problemas de conformidade em specs geradas por **outros LLMs**:

| Spec | Problema | LLM Originador |
|------|----------|----------------|
| `debitos-tecnicos-code-review.md` | `status: rascunho` (pt-BR, não é enum) | Outro |
| `spec-manager-skill.md` | ID duplicado (`SPEC-2026-04-06-002`) | Outro |
| `normatizacao-padroes-sistema.md` | ID sem prefixo `SPEC-`, domain `governance` inválido | Gemini CLI |
| `bash-source-guard-lesson.md` | Campos `category/tags` ao invés do Front Matter canônico | Outro |
| `estudo-caso-antigravity.md` | `domain: arquitetura | governança` (pipe literal) | Outro |

## Falhas no Script de Indexação

| Bug | Causa Raiz |
|-----|-----------|
| `extract_front_matter()` capturava exemplos YAML do corpo | `grep "^field:"` sem escopo — não diferenciava Front Matter de code blocks |
| Timestamp vazio no índice | `$ts_` ao invés de `${ts}` — bash interpretava como variável `ts_` inexistente |

## O Que Funcionou no Protocolo

1. **Bloco `CRITICAL_CONSTRAINTS` no Handoff** — forçou aderência ao contrato local.
2. **Validação pós-correção via `./bin/spec-index`** — ciclo de feedback imediato.
3. **Auditoria exaustiva antes da ação** — ler todas as 12 specs antes de tocar em qualquer uma.

## O Que Deve Ser Reforçado

1. **Todo LLM deve validar o enum de `status` e `domain`** antes de salvar — usar checklist do SKILL.md do `/spec`.
2. **O script `bin/spec-index` deve validar enums** e emitir alertas (não apenas renderizar).
3. **IDs devem ser verificados contra colisão** antes de salvar uma nova spec.
4. **Campos com pipe `|`** no YAML são armadilha — representam alternativas na documentação, mas são valores literais no Front Matter.

## Regra Para Skills

> Ao gerar qualquer spec, o LLM DEVE validar que:
> - `domain:` contém exatamente UM valor do enum canônico
> - `status:` contém exatamente UM valor do enum canônico
> - `id:` não colide com nenhum ID existente em `docs/specs/`
> - Nenhum campo extra (fora do contrato) é incluído no Front Matter
