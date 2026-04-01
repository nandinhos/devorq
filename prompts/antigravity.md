# DEVORQ - Antigravity Activation

## Ativar
Prompt de ativação automática.

## Workflow
1. Handoff: ler .devorq/state/handoffs/ (contexto completo do LLM anterior)
2. Context: /env-context (auto-detect stack e constraints)
3. Contract: /scope-guard → [Gate 1: aprovar contrato]
4. Validate: /pre-flight → /schema-validate → [Gate 2: aprovar antes de implementar]
5. Build: tdd (RED→GREEN→REFACTOR)
6. Gate: /quality-gate → [Gate 3: aprovar antes de commitar]
7. Audit: /session-audit (obrigatório)
8. Learn: /learned-lesson (obrigatório) → [Gate 5: salvar lições?]

## Stack Targets
- PHP/Laravel (TALL Stack)
- Python (data analysis)
- Shell (automation)
