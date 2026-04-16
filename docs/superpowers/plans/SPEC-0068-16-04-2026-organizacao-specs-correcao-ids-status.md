# SPEC-XXXX: Organização de Specs — Correção de IDs e Status

## Contexto

Após auditoria completa do repositório, identificou-se:
1. **SPEC-0021** com front matter incompleto (faltam 4 campos obrigatórios)
2. **3 SPECs** com IDs não-canônicos (formato `SPEC-YYYY-MM-DD-*` em vez de `SPEC-NNNN-DD-MM-YYYY`)
3. **4 SPECs** com status inconsistentes (documentos/lições marcados como `draft` ou `validated`)

## Tarefas

### T1: Corrigir SPEC-0021 Front Matter

**Arquivo:** `docs/specs/implemented/SPEC-0021-13-04-2026-devorq-installer.md`

Campos ausentes: `domain`, `priority`, `owner`, `source`

```yaml
---
id: SPEC-0021
title: DEVORQ Installer — Bootstrap e Deploy Multi-Projeto
domain: operacao
status: implemented
priority: high
owner: team-core
source: manual
author: nandodev
created_at: 2026-04-13
updated_at: 2026-04-15
---
```

### T2: Renomear SPEC-2026-04-07-upgrade-multiproject

**Arquivo atual:** `docs/specs/implemented/SPEC-2026-04-07-upgrade-multiproject.md`
**Arquivo novo:** `docs/specs/implemented/SPEC-0020-07-04-2026-upgrade-multiproject.md`

ID canônico: `SPEC-0020` (próximo número disponível)

```yaml
---
id: SPEC-0020-07-04-2026
title: Upgrade Multi-Projeto DEVORQ v2.1
domain: arquitetura
status: draft
priority: medium
owner: team-core
source: manual
created_at: 2026-04-07
updated_at: 2026-04-07
related_tasks: []
related_files: []
---
```

### T3: Renomear SPEC-2026-04-08-align-slash-commands

**Arquivo atual:** `docs/specs/implemented/SPEC-2026-04-08-align-slash-commands.md`
**Arquivo novo:** `docs/specs/implemented/SPEC-0022-08-04-2026-align-slash-commands.md`

### T4: Renomear SPEC-2026-04-08-homologacao-multi-llm

**Arquivo atual:** `docs/specs/implemented/SPEC-2026-04-08-homologacao-multi-llm.md`
**Arquivo novo:** `docs/specs/implemented/SPEC-0023-08-04-2026-homologacao-multi-llm.md`

Status: `approved` → `implemented` (é documento de referência, não feature)

### T5: Corrigir SPEC-0016 Status

**Arquivo:** `docs/specs/implemented/SPEC-0016-07-04-2026-comportamento-antigravity-governanca.md`

Status: `validated` → `implemented`
Motivo: É uma lição aprendida (documentação), não uma feature a ser implementada.

### T6: Corrigir SPEC-0018 Status

**Arquivo:** `docs/specs/implemented/SPEC-0018-09-04-2026-handoff-gemini-cli.md`

Status: `draft` → `implemented`
Motivo: Estudo de caso - o Front Matter já foi validado, checklist mostra tasks pendentes como "spec-index" que são verificações, não implementação.

### T7: Verificar Integridade

```bash
./bin/spec-index
grep -c "N/A" docs/specs/_index.md  # deve ser 0
./bin/devorq spec status | grep -E "N/A|validated|draft"  # deve estar limpo
```

### T8: Commit

```bash
git add -A && git commit -m "fix(specs): organizar IDs canônicos e corrigir status de 6 specs"
```

---

## Critérios de Aceite

- [ ] SPEC-0021 com front matter completo (11 campos)
- [ ] 3 SPECs renomeadas com IDs canônicos (SPEC-0020, 0022, 0023)
- [ ] SPEC-0016, SPEC-0018, SPEC-2026-04-08-homolog com status correto
- [ ] `grep -c "N/A" docs/specs/_index.md` retorna 0
- [ ] Índice sem entries duplicadas

## Riscos

| Risco | Impacto | Mitigação |
|-------|---------|-----------|
| Arquivos renomeados quebram links | Baixo | Atualizar índice após renomear |
| Status изменен affects workflows | Baixo | Comandos não dependem de status |

---

## Histórico

| Data | Autor | Mudança |
|------|-------|---------|
| 2026-04-16 | Nando Dev | Criação desta spec |
