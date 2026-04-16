---
name: learned-lesson
description: Documentar aprendizados para evitar recorrência — Pipeline Gates 6/7
triggers:
  - "learned-lesson"
  - "lição"
  - "aprendizado"
globs:
  - "**/*.md"
fields:
  - id
  - title
  - skill_target
  - status
  - validation_result
  - diff_proposed
  - created_at
  - validated_at
  - applied_at
---

# learned-lesson v2 — Lições Aprendidas

## Quando Usar

**OBRIGATÓRIO** após:
- Bug debugado com sucesso
- Erro de implementação corrigido
- Problema resolvido com solução não óbvia

## Pipeline de Gates

```
[Gate 5] /learned-lesson
         │
         ▼
.devorq/state/lessons-pending/
         │
         ▼
[Gate 6] devorq lessons validate
         │  1. Context7 MCP (automático)
         │  2. Classifica: CONFIRMADO | PARCIAL | INCORRETO
         │  3. Gera diff_proposed
         │  4. Aguarda aprovação
         ▼
.devorq/state/lessons-validated/
         │
         ▼
[Gate 7] devorq lessons apply <nome>
         │  1. Diff editável pelo usuário
         │  2. Snapshot da skill
         │  3. Aplica diff
         │  4. Atualiza CHANGELOG
         ▼
.devorq/state/lessons-applied/
         │
         ▼
[CHECAGEM FUNCIONAL] → git commit manual
```

## Estrutura da Lição

```markdown
---
id: LESSON-XXXX
title: Bash Source Guard
skill_target: quality-gate
status: pending
created_at: 2026-04-07
---

## SINTOMA
Libs shell não carregavam via source.

## CAUSA
Guard invertido.

## FIX
[[ "${BASH_SOURCE[0]}" == "$0" ]] && exit 0

## SKILL AFETADA
quality-gate
```

## Campos Obrigatórios

| Campo | Descrição | Exemplo |
|-------|-----------|---------|
| `id` | Identificador único | `LESSON-0012` |
| `title` | Título descritivo | `Bash Source Guard` |
| `skill_target` | Skill a ser atualizada | `quality-gate` |
| `status` | Estado no pipeline | `pending` |
| `created_at` | Data de criação | `2026-04-07` |

## Status Válidos

| Status | Significado |
|--------|-------------|
| `pending` | Aguardando Gate 6 (validação) |
| `validated` | Aprovada no Gate 6, aguardando Gate 7 |
| `applied` | Diff aplicado, aguardando commit manual |

## Gates

### Gate 5 — Captura

```bash
devorq lessons new
```

Captura a lição e salva em `lessons-pending/`.

### Gate 6 — Validação

```bash
devorq lessons validate
```

1. Context7 valida automaticamente
2. Classifica: CONFIRMADO | PARCIAL | INCORRETO
3. Gera `diff_proposed`
4. Aguarda ENTER para mover para `lessons-validated/`

### Gate 7 — Aplicação

```bash
devorq lessons apply LESSON-XXXX
```

1. Exibe diff para revisão
2. Usuário pode editar (e) ou aplicar (ENTER)
3. Snapshot: `VERSIONS/v<x.y+1.z>.md`
4. Aplica diff na skill
5. Atualiza CHANGELOG
6. Move para `lessons-applied/`

## Exemplo de Diff Gerado

```diff
+ ## Bash Source Guard
+ Ao criar libs shell, usar guard de sourcing:
+ [[ "${BASH_SOURCE[0]}" == "$0" ]] && exit 0
+ **Quando:** Criação de qualquer lib em lib/
+ **Verificação:** shellcheck não reporta erros
```

## Regras

1. **skill_target deve existir** — a skill afetada precisa estar em `.devorq/skills/`
2. **diff deve ser minimal** — apenas o necessário para incorporar a lição
3. **snapshot antes de aplicar** — versioning obrigatório
4. **commit manual após validação** — usuário verifica antes de commitar

---

> **Regra**: Revisar lições aprendidas antes de novas implementações
