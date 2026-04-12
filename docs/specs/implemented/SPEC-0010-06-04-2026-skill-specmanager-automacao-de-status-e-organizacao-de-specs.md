---
id: SPEC-0010-06-04-2026
title: Skill spec-manager — Automação de Status e Organização de Specs
domain: arquitetura
status: implemented
priority: high
owner: team-core
created_at: 2026-04-06
updated_at: 2026-04-06
source: manual
related_tasks: []
related_files:
  - .devorq/skills/spec-manager/
  - bin/spec-index
---

# Spec — Skill `spec-manager`

**Data**: 2026-04-06
**Status**: draft

---

## Objetivo

Criar skill especializada que:
1. Analisa specs em `docs/specs/` e atualiza status automaticamente
2. Detecta se specs `approved` já foram implementadas (baseado em artefatos relacionados)
3. Organiza documentação automaticamente (gera índice, alertas)
4. Executa via `./bin/devorq spec` ou como skill `/spec-manager`

---

## Fora do Escopo

- Painel web ou dashboard
- Integração com Jira/Linear
- Banco de dados

---

## Componentes / Artefatos

| Artefato | Tipo | Ação |
|----------|------|------|
| `.devorq/skills/spec-manager/SKILL.md` | skill principal | criar |
| `.devorq/skills/spec-manager/CHANGELOG.md` | rastreabilidade | criar |
| `.devorq/skills/spec-manager/VERSIONS/` | snapshots | criar |

---

## Regras de Negócio

### Regra 1 — Detecção de Implementação

Uma spec `approved` é considerada **implementada** quando:
- Tem `related_files` listados E esses arquivos existem no projeto
- Tem `related_tasks` com padrão TASK-XXX E essas tasks estão em `.devorq/state/tasklist/`
- Está em `docs/specs/` com todos os front matter obrigatórios

### Regra 2 — Atualização de Status Automática

Skill executa e propõe:
- `draft` → `approved` (se todas asDone Criteria marcadas)
- `approved` → `implemented` (se artefatos relacionados existem)
- `implemented` → `validated` (se passou em /quality-gate ou equivalent)

### Regra 3 — Fluxo de Execução

```
1. Ler _index.md atual
2. Para cada spec com status "approved":
   - Verificar related_files existem
   - Verificar related_tasks existem
   - Se implementada, propor mudança para "implemented"
3. Gerar novo _index.md com contagens corrigidas
4. Reportar mudanças propostas
5. Aguardar usuário confirmar
```

### Regra 4 — Validação de Front Matter

Para specs em `docs/specs/`, verificar:
- `id` presente (formato SPEC-YYYY-MM-DD-NNN)
- `title` presente
- `domain` válido (arquitetura|refactor|importacao|ui_ux|seguranca|operacao)
- `status` válido (draft|planning|approved|in_progress|implemented|validated|blocked|archived)
- `priority` válido (low|medium|high|critical)
- `created_at` presente
- `updated_at` presente

---

## Estrutura da Skill

```
.devorq/skills/spec-manager/
├── SKILL.md        ← regras de detecção e atualização
├── CHANGELOG.md    ← histórico de versões
└── VERSIONS/       ← snapshots
```

**Seções do SKILL.md:**
```markdown
## Quando Usar
## Como Detectar Implementação
## Como Atualizar Status
## Fluxo de Execução
## Checklist de Validação
## Integração com CLI
```

---

## Integração CLI

```bash
# Verificar specs e propor atualizações
./bin/devorq spec status

# Atualizar automaticamente
./bin/devorq spec update
```

---

## Critérios de Aceitação (Done Criteria)

- [ ] `.devorq/skills/spec-manager/SKILL.md` existe com regras completas
- [ ] `.devorq/skills/spec-manager/CHANGELOG.md` existe com entrada v1.0.0
- [ ] `./bin/devorq spec status` lista specs e detecta implementadas
- [ ] `./bin/devorq spec update` atualiza status automaticamento
- [ ] Speculada espec implementada neste processo (teste)