# Pre-flight Report — Bash Source Guard Detection

**Data**: 2026-04-07
**Tarefa**: Aplicar lição de Bash Dual-Use Source Guard
**Status**: ⚠️ ATENÇÃO REQUERIDA

## Step 1: Identificar Domínio
- **Módulo**: Governança (Skills) e Core (Scripts Bash)
- **Files Afetados**: `.devorq/skills/quality-gate/SKILL.md`, `.devorq/skills/pre-flight/SKILL.md`
- **Scripts em lib/**: Identificados scripts vulneráveis (sem guard e com lógica de case).

## Step 2: Carregar Artefatos (Scripts lib/ sem Guard)

Foram identificados os seguintes arquivos em `lib/` que possuem blocos `case` mas não possuem o guard `[[ "${BASH_SOURCE[0]}" != "$0" ]] && return 0`:

- `lib/cli.sh`
- `lib/detection.sh`
- `lib/error-recovery.sh`
- `lib/lessons.sh`
- `lib/mcp-fallback.sh`
- `lib/mcp-validate.sh`
- `lib/orchestration.sh`
- `lib/stack-detector.sh`

## Step 3: Validar Ambiente e Tipos
- ✅ Antigravity Agent em dia.
- ✅ Bash 4.0+ confirmado.
- ✅ Scripts dual-use padrão DEVORQ v2.1 confirmados como vulneráveis sem o guard.

## Step 4: Report de Risco
- **Risco**: Os scripts acima podem interferir nos testes unitários ou em outros módulos quando carregados via `source`, disparando o help ou lógicas de execução direta indevidamente.

### Ação Recomendada:
1. Implementar a regra no `quality-gate` (Bloqueio).
2. Implementar a regra no `pre-flight` (Aviso automático).

## Status da Validação
- ✅ AMBIENTE: VÁLIDO
- ⚠️ CÓDIGO: DÉBITOS ENCONTRADOS (8 arquivos em lib/)
- ✅ SKILLS: PRONTAS PARA ATUALIZAÇÃO

[AGUARDANDO APROVAÇÃO DA SPEC PARA IMPLEMENTAR]
