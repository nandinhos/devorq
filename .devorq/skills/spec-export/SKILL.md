---
name: spec-export
description: Exportar contexto para handoff entre LLMs
triggers:
  - "spec-export"
  - "handoff"
  - "exportar spec"
globs:
  - "**/*.md"
---

# /spec-export - Handoff entre LLMs

> **Regra de Ouro**: Handoff sem spec-export = perda de contexto

## Quando Usar

**OBRIGATÓRIO** quando:
1. Troca de LLM (Claude → Gemini)
2. Sessão pausada para outro continuar
3. Repassar contexto para desenvolvedor

## Estrutura

```markdown
# SPEC EXPORT - [Task]

## Estado
- Status: [Em progresso/Pausado/Completo]
- Última atividade: [o que fazia]
- Commits: [lista]

## Escopo
### FAZER: [lista]
### NÃO FAZER: [lista]
### ARQUIVOS: [lista]

## Contexto Técnico
- Stack: [ex: Laravel 12, PHP 8.4]
- Artefatos: [tabelas, enums, models]

## Próximos Passos
1. [ação específica]
2. [ação]
3. [ação]

## Notas
- [warnings, pitfalls]
```

---

> **Débito que previne**: D18 (Specs sem formato cross-LLM)