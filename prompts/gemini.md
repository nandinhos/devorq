# DEVORQ - Gemini CLI Activation

## Ativar
Digite: `devorq [task]` ou cole este prompt.

## Fluxo
1. Ler handoff file em .devorq/state/handoffs/ (se existir — contém contexto completo)
2. /env-context (auto — detecta stack e constraints)
3. /scope-guard (obrigatório) → [Gate 1: aprovar contrato]
4. /pre-flight → [Gate 2: aprovar relatório antes de implementar]
5. TDD (RED→GREEN→REFACTOR)
6. /quality-gate (obrigatório) → [Gate 3: aprovar antes de commitar]
7. /session-audit (obrigatório)
8. /learned-lesson (obrigatório) → [Gate 5: decidir quais lições salvar]

## Stack
Laravel, Filament, Python, Shell
