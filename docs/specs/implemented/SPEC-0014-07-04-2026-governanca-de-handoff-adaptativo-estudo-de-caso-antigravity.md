---
id: SPEC-0014-07-04-2026
title: Governança de Handoff Adaptativo — Estudo de Caso Antigravity
domain: arquitetura
status: implemented
priority: critical
owner: team-core
created_at: 2026-04-07
updated_at: 2026-04-07
source: manual
related_tasks: ["TASK-HANDOFF-ANTIGRAVITY"]
related_files: ["lib/handoff.sh", "prompts/antigravity.md", "docs/specs/2026-04-07-estudo-caso-antigravity.md"]
---

# Spec: Governança de Handoff Adaptativo (Antigravity)

## 1. Problema
O editor **Antigravity** possui heurísticas de geração de artefatos que frequentemente ignoram (bypass) os contratos definidos em arquivos de configuração local (como as regras de Front Matter do DEVORQ), priorizando seus próprios templates internos.

## 2. Objetivo
Estabelecer um protocolo de **Handoff Explícito** que force o Antigravity a aderir aos contratos do DEVORQ através de comandos diretivos de alta prioridade ("System Overrides").

## 3. Dinâmica de Lapidação
1. **Mapeamento de Falhas:** Identificar quais campos o Antigravity ignora (ex: `id:`, `status:`).
2. **Injeção de Contexto:** O Handoff deve conter um bloco de `CRITICAL_CONSTRAINTS` específico para o Antigravity.
3. **Validação de Retorno:** Ao retornar para outro LLM (como o Gemini), o primeiro passo deve ser uma auditoria de conformidade com a v2.1.

## 4. Requisitos de Implementação
- **Prompt Adaptativo:** Criar `prompts/antigravity.md` com instruções de "Strict Mode".
- **Handoff Metadata:** Incluir a tag `target_llm: antigravity` no JSON de Handoff para disparar os alertas de contrato.

## 5. Critérios de Aceite
- [x] O Antigravity gera uma SPEC com Front Matter 100% canônico. *(Evidência: LESSON-2026-04-07-002 — 11/11 campos obrigatórios presentes)*
- [x] O Handoff para o Antigravity é validado sem "N/A" no índice de specs após o retorno. *(Evidência: `grep -c 'N/A' _index.md` = 0, 13/13 specs presentes)*
- [x] Documentação de "Lições Aprendidas" sobre o comportamento do editor. *(Evidência: `docs/specs/2026-04-07-lesson-antigravity-behavior.md` — 6 seções documentadas)*
