# SPEC — Fluxo Multi-LLM DEVORQ

**Data**: 2026-04-02
**Versão**: 1.0
**Status**: Aprovado para implementação

---

## Objetivo

Definir como o DEVORQ orquestra múltiplas LLMs em papéis distintos,
garantindo continuidade de contexto e qualidade independente do modelo
executor.

---

## Fora do Escopo

- Integração automática com APIs de LLMs (responsabilidade do ambiente do usuário)
- Automação de dispatch (handoff é gerado pelo CLI, enviado manualmente)
- Ranking ou comparativo de desempenho entre modelos
- Autenticação ou billing de providers

---

## Fluxo Principal

```
FASE 1 — ARQUITETURA (Tier 1)
  Ferramenta: Claude Code ou equivalente Tier 1
  ┌──────────────────────────────────────────────┐
  │ /spec       → documento de especificação     │
  │ /break      → decomposição em tasks          │
  │ /scope-guard → contrato por task             │
  │ handoff generate → handoff package           │
  │ [Gate 4] → usuário aprova handoff            │
  └──────────────────────────────────────────────┘
              ↓ handoff package

FASE 2 — IMPLEMENTAÇÃO (Tier 2)
  Ferramenta: Qualquer modelo disponível
  ┌──────────────────────────────────────────────┐
  │ Ativa com prompts/activation.md              │
  │ Lê handoff package                           │
  │ /env-context → detecta stack e runtime       │
  │ /pre-flight  → valida schema e tipos         │
  │ TDD → RED → GREEN → REFACTOR                 │
  │ /quality-gate → checklist pré-commit         │
  │ Commit + retorno padronizado para Tier 1     │
  └──────────────────────────────────────────────┘
              ↓ retorno: SHA + testes + desvios

FASE 3 — REVISÃO (Tier 3)
  Ferramenta: Claude Code, Codex ou equivalente
  ┌──────────────────────────────────────────────┐
  │ /code-review → análise do diff               │
  │ Aprovação ou lista de correções              │
  │ Se correções → volta para Fase 2             │
  │ Se aprovado → merge + /session-audit         │
  │              + /learned-lesson               │
  └──────────────────────────────────────────────┘
```

---

## Handoff Package

O handoff é um pacote auto-contido de 7 seções que viaja entre Tier 1 e
Tier 2. Ver template completo em `docs/templates/handoff-package.md`.

**Princípio**: o executor não precisa de nenhum contexto além do pacote.
Se precisar perguntar algo, o handoff está incompleto.

### Geração (modelo híbrido — Opção C)

```bash
# CLI gera seções automáticas (snapshot, verificação, done criteria base)
./bin/devorq handoff generate

# Arquiteto preenche seções decisórias manualmente:
# → contrato de escopo
# → task brief (arquivo por arquivo)
# → padrões relevantes para a task
# → formato de retorno esperado

# Usuário revisa e aprova [Gate 4]
./bin/devorq handoff status
```

---

## Retorno do Implementador

Formato padronizado que o Tier 2 devolve ao Tier 1:

```markdown
# RETORNO — [nome da tarefa]

- **SHA do commit**: [hash]
- **Testes**: [N/N passando]
- **Arquivos modificados**: [lista exata]
- **Desvios do plano**: [nenhum | descrição]
- **Dúvidas para próxima iteração**: [nenhuma | lista]
```

---

## Gates de Qualidade

| Gate | Fase | Quem valida | Critério de Passagem |
|------|------|------------|---------------------|
| Gate 1 — Contrato | Fase 1 | Arquiteto (Tier 1) | Scope-guard aprovado antes de gerar handoff |
| Gate 2 — Pre-flight | Fase 2 | Implementador (Tier 2) | Schema e tipos validados antes de codificar |
| Gate 3 — Quality | Fase 2 | Implementador (Tier 2) | Checklist pré-commit 100% satisfeito |
| Gate 4 — Handoff | Fase 1→2 | Usuário | Handoff package aprovado antes de enviar |
| Gate 5 — Review | Fase 3 | Revisor (Tier 3) | Diff aprovado, sem regressão, contratos respeitados |

---

## Critério de Aceitação pelo Arquiteto (Tier 1)

O retorno do Tier 2 é aceito quando:
- Testes 100% passando (suite completa)
- Nenhum arquivo fora da lista branca do contrato foi modificado
- Todos os done criteria do contrato estão satisfeitos
- Sem secrets, lógica de negócio ou permissões expostas no frontend
- Commit com mensagem convencional correta

---

## Páginas / Componentes Relevantes no DEVORQ

| Componente | Responsabilidade | Tier de criação |
|-----------|-----------------|----------------|
| `/spec` | Gera especificação formal | Tier 1 |
| `/break` | Decompõe spec em tasks | Tier 1 |
| `/scope-guard` | Contrato de escopo por task | Tier 1 |
| `handoff generate` | Monta handoff package | Tier 1 (CLI) + Tier 1 (decisões) |
| `/pre-flight` | Valida schema antes de implementar | Tier 2 |
| `tdd` | Ciclo RED→GREEN→REFACTOR | Tier 2 |
| `/quality-gate` | Checklist pré-commit | Tier 2 |
| `/code-review` | Revisão do diff | Tier 3 |
| `/session-audit` | Métricas de eficiência | Tier 1 ou Tier 3 |
| `/learned-lesson` | Captura lições | Qualquer tier |
