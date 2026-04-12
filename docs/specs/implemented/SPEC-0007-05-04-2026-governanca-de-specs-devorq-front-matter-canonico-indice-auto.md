---
id: SPEC-0007-05-04-2026
title: Governança de Specs DEVORQ — Front Matter Canônico + Índice Automático
domain: arquitetura
status: implemented
priority: high
owner: team-core
created_at: 2026-04-05
updated_at: 2026-04-06
source: proposal/architecture/devorq-spec-governance.md
related_tasks: []
related_files:
  - .devorq/skills/spec/SKILL.md
  - .devorq/skills/session-audit/SKILL.md
  - docs/specs/
  - bin/spec-index
---

# Spec — Governança de Specs DEVORQ

**Data**: 2026-04-05
**Status**: approved
**Autor**: Arquiteto (sessão devorq)

---

## Objetivo

Padronizar o ciclo de vida de specs no DEVORQ com:
1. Front matter YAML canônico em todo documento de spec gerado pelo `/spec`
2. Consolidação do diretório canônico (`docs/specs/`, singular já descartado)
3. Script de índice automático que gera `docs/specs/_index.md` com visão executiva
4. Alertas leves no `/devorq-audit` para specs sem metadados ou com status inconsistente

Resolve a dor atual: specs sem status legível, dois diretórios concorrentes (`docs/spec/` e `docs/specs/`), formato heterogêneo que impede rastreabilidade entre spec → task → entrega.

---

## Fora do Escopo

- Banco de dados para specs
- Painel web ou dashboard dedicado
- Engine de workflow para transição de status
- Geração automática de IDs sem colisão (ID usa data + sequência manual por ora)
- Integração com ferramentas externas (Jira, Linear, GitHub Issues)
- Subpastas por domínio (só quando houver > 50 specs ativas)

---

## Componentes / Artefatos Afetados

| Artefato | Tipo | Ação |
|----------|------|------|
| `docs/spec/2026-04-02-fluxo-multi-llm.md` | arquivo existente | migrar para `docs/specs/` |
| `docs/spec/` | diretório | remover após migração |
| `.devorq/skills/spec/SKILL.md` | skill | atualizar template + Step 3 |
| `docs/specs/_index.md` | novo arquivo | gerado pelo script |
| `bin/spec-index` | novo script Bash | criar |
| `.devorq/skills/session-audit/SKILL.md` | skill | adicionar checagens de spec |

---

## Regras de Negócio

1. `docs/specs/` é o único diretório canônico de specs do DEVORQ. `docs/spec/` não deve existir.
2. Todo arquivo em `docs/specs/` (exceto `_index.md`) deve ter front matter YAML com os campos obrigatórios: `id`, `title`, `domain`, `status`, `priority`, `created_at`, `updated_at`.
3. O campo `status` só aceita valores do enum canônico: `draft`, `planning`, `approved`, `in_progress`, `implemented`, `validated`, `blocked`, `archived`.
4. O campo `domain` só aceita valores canônicos: `importacao`, `ui_ux`, `refactor`, `arquitetura`, `seguranca`, `operacao`.
5. O `_index.md` é sempre gerado pelo script `bin/spec-index` — nunca editado manualmente.
6. O `/spec` SKILL.md deve salvar specs com front matter completo por padrão, sem exceção.
7. O `/devorq-audit` deve alertar (não bloquear) sobre: specs sem `updated_at` recente (> 14 dias), specs `implemented` sem `validated`, specs `blocked` sem `related_tasks` explícito.

---

## Modelos de Dados / Estrutura de Arquivos

**Front matter canônico (obrigatório):**
```yaml
---
id: SPEC-0007-05-04-2026
title: Título legível da spec
domain: arquitetura | importacao | ui_ux | refactor | seguranca | operacao
status: draft | planning | approved | in_progress | implemented | validated | blocked | archived
priority: low | medium | high | critical
owner: team-core | [nome]
created_at: YYYY-MM-DD
updated_at: YYYY-MM-DD
source: manual | devorq | proposal/[caminho]
related_tasks: []
related_files: []
---
```

**Estrutura de diretório alvo:**
```
docs/specs/
  _index.md                              ← gerado automaticamente
  2026-04-02-fluxo-multi-llm.md          ← migrado de docs/spec/
  2026-03-31-devorq-evolution-design.md  ← já existe
  2026-04-05-spec-governance-devorq.md   ← esta spec
  2026-04-05-skill-filament-expert.md    ← próxima spec
```

**Saída esperada do `bin/spec-index`:**
```markdown
# Índice de Specs DEVORQ
_Gerado automaticamente em YYYY-MM-DD HH:MM_

## Resumo por Status
| Status | Total |
|--------|-------|
| approved | 2 |
| implemented | 1 |
...

## Resumo por Domínio
...

## Todas as Specs
| ID | Título | Domínio | Status | Prioridade | Atualizado |
...

## Alertas
- [AVISO] spec X sem updated_at recente
```

---

## Plano de Implementação (fases)

### Fase 1 — Consolidação + Normalização (esta sprint)
1. Migrar `docs/spec/2026-04-02-fluxo-multi-llm.md` → `docs/specs/`
2. Remover diretório `docs/spec/`
3. Adicionar front matter nos arquivos existentes de `docs/specs/`
4. Atualizar `SKILL.md` do `/spec`: novo template com front matter + save em `docs/specs/`

### Fase 2 — Índice automático
5. Criar `bin/spec-index` (Bash puro, lê front matters, gera `_index.md`)
6. Documentar uso em `CLAUDE.md` ou `README`

### Fase 3 — Governança operacional
7. Adicionar checagens no `/devorq-audit`

---

## Critérios de Aceitação (Done Criteria)

- [ ] `docs/spec/` não existe mais
- [ ] Todos os arquivos em `docs/specs/` têm front matter canônico válido
- [ ] `bin/spec-index` gera `_index.md` sem erro com os arquivos existentes
- [ ] `/spec` SKILL.md usa o novo template com front matter por padrão
- [ ] `/devorq-audit` emite alertas para specs sem status canônico
- [ ] Esta própria spec tem front matter completo e status `validated` ao final
