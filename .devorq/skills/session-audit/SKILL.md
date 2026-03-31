---
name: session-audit
description: Classificar sessão ao final para métricas de eficiência
triggers:
  - "session-audit"
  - "auditar sessão"
  - "eficiência"
globs:
  - ".git"
---

# /session-audit - Métricas de Eficiência

> **Regra de Ouro**: Toda sessão termina com audit

## Quando Usar

**OBRIGATÓRIO** ao final de toda sessão (encerramento ou após 60min)

## Classificação

| Classificação | Critérios |
|---------------|-----------|
| **EFICIENTE** | ✅ Feature completa ✅ testes passando ✅ escopo respeitado |
| **ACEITÁVEL** | ✅ Feature parcial ✅ ajustes pendentes esperados |
| **DESPERDIÇADA** | ❌ Saiu do escopo ❌ over-engineering ❌ debugging evitável |

## Causas Raiz (se DESPERDIÇADA/ACEITÁVEL)

| Causa | Identificador |
|-------|---------------|
| SPEC_VAGA | Sem /scope-guard claro |
| OVER_ENGINEERING | Saiu do FAZER |
| ENV_DEBUG | Tempo perdido com Docker/infra |
| SCHEMA_ERRO | Tipos/enums errados |
| INTERROMPIDA | Fator externo |
| REGRESSÃO | Teste existente quebrou |

## Report

```markdown
# SESSION AUDIT - [timestamp]

## Dados
- Duração: [tempo]
- Task: [nome]
- Files: [count]

## Classificação: [EFICIENTE/ACEITÁVEL/DESPERDIÇADA]

## Métricas
- Fix rounds: [n]
- Checkpoints: [n]
- Testes: [n passing]

## Causa Raiz (se aplicável)
- [causa]: [descrição]

## Próxima Sessão
- Continuar de: [próximo passo]
- Atenção: [warnings]
```

---

> **Débito que previne**: D19 (Observer sessions), ineficiência invisível