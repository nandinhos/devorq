# 📚 Documentação DEVORQ

> Índice centralizado de toda a documentação do projeto.
> Este índice aponta para a fonte de verdade operacional; a versão atual é **v4.1.0**.

---

## 📋 Índice por Categoria

### Arquitetura & Specs

| Arquivo | Descrição | Status |
|---------|-----------|--------|
| `SPEC.md` | Especificação principal do sistema | ✅ ATIVO |
| `CHANGELOG.md` | Histórico de versões | ✅ ATIVO |
| `VERSION` | Versão atual do sistema | ✅ ATIVO |
| `prd.json` | Product Requirements Document | ✅ ATIVO |
| `STATUS.md` | Estado atual do framework | ✅ ATIVO |
| `architecture/LOOP-ENGINEERING.md` | Arquitetura do loop experimental | ✅ ATIVO |
| `adr/ADR-001-loop-engineering-minimo.md` | Decisão arquitetural do loop mínimo | ✅ ATIVO |
| `releases/4.1.0.md` | Notas de release v4.1.0 | ✅ ATIVO |

### Guias & Tutoriais

| Arquivo | Descrição | Status |
|---------|-----------|--------|
| `AUTO-MODE.md` | Documentação do modo AUTO | ✅ ATIVO |
| `COMPORTAMENTO_ESPERADO.md` | Comportamento esperado do sistema | ✅ ATIVO |
| `PLAYWRIGHT_EXTENSION_VS_CLI.md` | Comparação Playwright | ⚠️ LEGADO |
| `SYSTEM_LEVANTAMENTO.md` | Levantamento do sistema | ⚠️ LEGADO |

### Regras & Processos

| Arquivo | Descrição | Status |
|---------|-----------|--------|
| `DEVORQ-COMMIT-VISUAL-SPEC.md` | Convenção de commits | ✅ ATIVO |
| `DEVORQ-RULES-CODE-REVIEW.md` | Regras de code review | ✅ ATIVO |
| `DEVORQ-DEFICITS-FIX-PLAN.md` | Plano de correções | ✅ ATIVO |
| `CODE_REVIEW_COMPLETO.md` | Guia de code review | ⚠️ LEGADO |
| `docs/specs/2026-06-02-code-review-corrections.md` | SPEC do sprint de code review (4 stories) | ✅ ATIVO |
| `docs/specs/README.md` | Índice de SPECs por sprint | ✅ ATIVO |
| `docs/security-reviews/2026-06-04/SUMMARY.md` | Review do Codex CLI (fix SSH) | ✅ ATIVO |

### Testes

| Arquivo | Descrição | Status |
|---------|-----------|--------|
| `TEST_STRATEGY.md` | Estratégia de testes | ✅ ATIVO |

### Refatoração & Melhorias

| Arquivo | Descrição | Status |
|---------|-----------|--------|
| `MELHORIAS_V3.md` | Melhorias planejadas | ⚠️ LEGADO |
| `REFATORACAO_ESTRUTURA.md` | Plano de refatoração | ⚠️ LEGADO |
| `SPEC-LESSONS-SKILLS-LOOP.md` | Arquitetura lessons/skills | ✅ ATIVO |
| `SPEC-ORCH-002-COMMIT-RULES-DISPATCH.md` | Spec do orquestrador de commit rules | ✅ ATIVO |

### Propostas

| Arquivo | Descrição | Status |
|---------|-----------|--------|
| `propostas/PRD-DESIGN-EVOLUTION-v2.md` | Proposta de design | ⚠️ PROPOSTA |

---

## 📊 Status dos Documentos

| Status | Count | Descrição |
|--------|-------|-----------|
| ✅ ATIVO | 11 | Documentos em uso |
| ⚠️ LEGADO | 7 | Documentos históricos |
| ⚠️ PROPOSTA | 1 | Propostas a avaliar |
| ❌ ARQUIVADO | 0 | Documentos arquivados |

---

## 🔄 Convenções de Nomenclatura

- **kebab-case**: `devorq-commit-visual-spec.md`
- ** snake_case**: `melhorias_v3.md` (legado)

**Recomendação**: Padronizar para `kebab-case` no futuro.

---

## 📝 Adicionando Novos Documentos

1. Colocar na pasta `docs/` raiz
2. Usar nomenclatura `kebab-case.md`
3. Adicionar neste índice
4. Atualizar status conforme apropriado

---

*Última atualização: 2026-07-13 (release v4.1.0 — Loop Engineering experimental).*
