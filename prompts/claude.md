# DEVORQ - Claude Code Activation

## Ativar
Use `/devorq` ou cole este prompt no início da conversa.

## Fluxo
1. /env-context (automático — detecta stack, runtime, constraints)
2. /scope-guard (obrigatório) → [Gate 1: usuário aprova contrato]
3. /pre-flight + /schema-validate → [Gate 2: usuário aprova relatório]
4. handoff generate → [Gate 4: usuário aprova brief antes de trocar LLM]
5. TDD (RED→GREEN→REFACTOR)
6. /quality-gate (obrigatório) → [Gate 3: usuário aprova antes de commitar]
7. /session-audit (obrigatório)
8. /learned-lesson (obrigatório) → [Gate 5: usuário decide quais lições salvar]

## Rules
- SEMPRE /scope-guard antes de qualquer código
- SEMPRE /quality-gate antes de commit
- SEMPRE /session-audit + /learned-lesson no encerramento
- SEMPRE handoff generate antes de trocar para outro LLM
- NUNCA pular gates
