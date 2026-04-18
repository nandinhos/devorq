---
name: learned-lesson
description: Documentar aprendizados para evitar recorrência — Pipeline Gates 5/6/7
triggers:
  - "learned-lesson"
  - "lição"
  - "aprendizado"
globs:
  - "**/*.md"
fields:
  - id
  - title
  - domain
  - status
  - priority
  - owner
  - created_at
  - updated_at
  - source
  - related_tasks
  - related_files
  - applied_to
depends_on: []
---

# learned-lesson v3 — Lições Aprendidas

## Quando Usar

**OBRIGATÓRIO** após:
- Bug debugado com sucesso
- Erro de implementação corrigido
- Problema resolvido com solução não óbvia
- Descoberta de padrão que evita retrabalho futuro

## Pipeline de Gates

```
[Gate 5] /learned-lesson
         │
         ▼
.devorq/state/lessons-pending/LESSON-NNNN-DD-MM-YYYY-titulo-kebab.md
(status: pending)
         │
         ▼
[Gate 6] devorq lessons validate
         │  1. Context7 MCP (automático quando aplicável)
         │  2. Classifica: CONFIRMADO | PARCIAL | INCORRETO | NÃO_APLICÁVEL
         │  3. Aguarda aprovação humana
         ▼
.devorq/state/lessons-validated/
(status: validated)
         │
         ▼
[Gate 7] devorq lessons apply <id>
         │  1. Apresenta 4 destinos possíveis
         │  2. Recomendação automática
         │  3. Escolha humana (1/2/3/4)
         │  4. Aplica destino escolhido
         ▼
.devorq/state/lessons-applied/
(status: applied, applied_to: <destino>)
```

## Front Matter Canônico (12 campos + applied_to)

```yaml
---
id: LESSON-NNNN-DD-MM-YYYY
title: Título descritivo da lição
domain: arquitetura | importacao | ui_ux | refactor | seguranca | operacao
status: pending | validated | applied
priority: low | medium | high | critical
owner: team-core
created_at: YYYY-MM-DD
updated_at: YYYY-MM-DD
source: manual | session-audit | code-review | spec-completion
related_tasks: []
related_files: []
applied_to: ""    # preenchido no Gate 7. Ex: "skill:quality-gate", "memory:local", "memory:global", "skill:nova/<nome>"
---
```

**Nota**: O campo `skill_target` da versão anterior é descontinuado. O destino da lição agora é registrado em `applied_to`.

## ID da Lição

Formato: `LESSON-NNNN-DD-MM-YYYY` (sequencial global, não por dia).

Para descobrir o próximo número:
```bash
ls .devorq/state/lessons-pending/ .devorq/state/lessons-validated/ .devorq/state/lessons-applied/ \
  | grep -oP 'LESSON-\d+' | sort -u | tail -1
```

## Gate 5 — Captura (menos-pending/)

```bash
devorq lessons new
```

Cria `.devorq/state/lessons-pending/LESSON-NNNN-DD-MM-YYYY-titulo-kebab.md` com `status: pending`.

**Regra**: É proibido escrever lições direto em `~/.claude/CLAUDE.md`, `memory/*.md`, `.devorq/skills/*` ou `MEMORY.md` sem passar pelo pipeline.

## Gate 6 — Validação (lessons-validated/)

```bash
devorq lessons validate
```

1. **Validação Context7** (quando a lição envolve framework/biblioteca):
   - `mcp__context7__resolve-library-id` → identificar a biblioteca relevante para a lição
   - `mcp__context7__query-docs` com `topic` = conceito central da lição
   - Classificar conforme resultado da consulta:
     - **CONFIRMADO** — documentação confirma a lição como correta e atual
     - **PARCIAL** — documentação confirma parte; diverge em algum ponto
     - **INCORRETO** — documentação contradiz a lição (revisar antes de aplicar)
     - **NÃO_APLICÁVEL** — lição é sobre processo/negócio, não framework externo
   - Registrar no front matter da lição: `context7_result: CONFIRMADO`
   - Se Context7 não disponível: classificar como `NÃO_APLICÁVEL` e prosseguir

## Gate 7 — Decisão de Destino (lessons-applied/)

```bash
devorq lessons apply <id>
```

### 4 Destinos Possíveis

| # | Destino | Critério de Recomendação | Onde Grava |
|---|---------|--------------------------|------------|
| 1 | Promover capability em skill existente | Lição técnica + skill cobrindo o domínio existe | diff em `.devorq/skills/<nome>/SKILL.md` + bump minor + entrada `CHANGELOG.md` |
| 2 | Criar nova skill | Lição técnica recorrente + nenhuma skill cobre o domínio | scaffold em `.devorq/skills/<nova>/` (`SKILL.md`, `CHANGELOG.md`, `VERSIONS/v1.0.0.md`) |
| 3 | Memória global do user | Aplica a múltiplos projetos (preferência, padrão de commit, regra de stack) | append em `~/.claude/CLAUDE.md` ou novo arquivo em `~/.claude/knowledge/` |
| 4 | Memória local do projeto | Específica deste projeto (paridade dev↔CI, atalho interno) | novo arquivo em `<projeto>/.claude/projects/.../memory/<feedback\|project\|reference>_*.md` + entrada em `MEMORY.md` |

### Diálogo do Gate 7

```
[GATE 7 — Decisão de Destino para LESSON-XXXX-DD-MM-YYYY]

Parecer Context7: CONFIRMADO
Análise de escopo: lição técnica, específica deste projeto

Recomendação: [4] Memória local do projeto

Destinos disponíveis:
  [1] Promover capability em skill existente
      Skills candidatas: quality-gate, systematic-debugging
  [2] Criar nova skill
      Nome sugerido: ci-dev-parity
  [3] Memória global do user
      Path: ~/.claude/CLAUDE.md
  [4] Memória local do projeto    ← recomendado
      Path: <projeto>/.claude/projects/.../memory/feedback_ci_dev_parity.md

Sua escolha [1/2/3/4]:
```

**Importante**: A recomendação é apenas sugestão — a escolha final é sempre humana. Sem escolha explícita, a lição permanece em `lessons-validated/`.

## Status Válidos

| Status | Significado |
|--------|-------------|
| `pending` | Aguardando Gate 6 (validação) |
| `validated` | Aprovada no Gate 6, aguardando Gate 7 |
| `applied` | Destino escolhido e aplicado, aguardando commit |

## Estrutura da Lição

```markdown
---
id: LESSON-0012-07-04-2026
title: Bash Source Guard
domain: refactor
status: pending
priority: medium
owner: team-core
created_at: 2026-04-07
updated_at: 2026-04-07
source: session-audit
related_tasks: []
related_files:
  - lib/orchestration/flow.sh
  - tests/sourcing.bats
applied_to: ""
---

## SINTOMA

Libs shell não carregavam via source.

## CAUSA

Guard invertido.

## FIX

```bash
[[ "${BASH_SOURCE[0]}" == "$0" ]] && exit 0
```

**Quando**: Criação de qualquer lib em lib/
**Verificação**: shellcheck não reporta erros
```

## Regras

1. **Sempre passa por lessons-pending/** — mesmo lições "claramente memória local"
2. **Snapshot antes de aplicar** — versioning obrigatório (via `devorq skill version`)
3. **applied_to preenchido após Gate 7** — registra o destino elegido
4. **ID segue LESSON-NNNN-DD-MM-YYYY** — sequencial global
5. **Recomendação no Gate 7 é sugestão** — escolha humana é soberana

---

> **Regra**: Revisar lições aprendidas antes de novas implementações
