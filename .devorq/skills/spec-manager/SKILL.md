---
name: spec-manager
description: Automatizar gestão de specs — detectar implementação, atualizar status, organizar documentação
triggers:
  - "spec-manager"
  - "gerenciar specs"
  - "atualizar status"
  - "spec status"
globs:
  - "docs/specs/*.md"
---

# Skill: spec-manager

> **Regra**: Toda spec approved sem implementation tracking = débt técnico

## Quando Usar

**OBRIGATÓRIO**:
- Ao final de ogni ciclo de implementação
- Quando uma spec approved for implementada
- Periodicamente para verificar status das specs

**OPCIONAL**:
- Ao executar `./bin/devorq spec status`
- Ao executar `./bin/devorq spec update`

---

## Como Detectar Implementação (Critérios Híbridos)

### Nível 1: Front Matter Válido

Antes de qualquer análise, verificar front matter completo:

| Campo | Formato | Obrigatório |
|-------|---------|-------------|
| id | `SPEC-YYYY-MM-DD-NNN` | ✅ |
| title | texto | ✅ |
| domain | arquitetura\|refactor\|importacao\|ui_ux\|seguranca\|operacao | ✅ |
| status | draft\|planning\|approved\|in_progress\|implemented\|validated\|blocked\|archived | ✅ |
| priority | low\|medium\|high\|critical | ✅ |
| created_at | YYYY-MM-DD | ✅ |
| updated_at | YYYY-MM-DD | ✅ |
| related_files | lista (pode ser `[]`) | ✅ |
| related_tasks | lista (pode ser `[]`) | ✅ |

### Nível 2: Contagem Precisa de related_files

**Problema:** `grep -c "^- "` conta qualquer linha com "- "

**Solução:** Contar apenas items dentro do bloco YAML:

```bash
# Contar só items em related_files: (entre front matter)
related_files=$(awk '/^related_files:/,/^[^ ]/' "$spec_file" 2>/dev/null | grep -c "^- " || echo "0")
```

### Nível 3: Verificação de Existência

Para cada `related_file` na lista, verificar se existe:
- Se começa com `.devorq/` → verificar diretório
- Se começa com `bin/` → verificar arquivo
- Se começa com `lib/` → verificar arquivo

```bash
for file in $related_files_list; do
  if [ -e "$file" ] || [ -d "$file" ]; then
    exists=$((exists + 1))
  fi
done
```

### Nível 4: Análise de related_tasks

Se `related_tasks` tem items (TASK-XXX):
- Verificar se tasklist correspondente existe
- Contar tasks existentes

---

## Critérios para status `implemented`

Uma spec com status `approved` é considerada **implementada** quando:

1. **Front matter completo**: Todos os campos obrigatórios presentes
2. **related_files count > 0**: Tem pelo menos 1 arquivo relacionado
3. **related_files existem**: Pelo menos 50% dos arquivos listados existem no filesystem

### Prioridade de Detecção

| Prioridade | Critério |
|------------|----------|
| 1 | `related_files` > 0 E > 50% existem → **implemented** |
| 2 | `related_files` > 0 E existem → **implemented** (fallback) |
| 3 | `related_tasks` > 0 E tasklist existe → **implemented** |

---

## Fluxo de Execução

### Step 1: Validar Front Matter

Para cada spec em `docs/specs/`:
1. Ler front matter
2. Verificar campos obrigatórios
3. Se incompleta → reportar alerta

### Step 2: Contar related_files

```bash
related_files_count=$(awk '/^related_files:/,/^[^ ]/' "$spec_file" | grep -c "^- ")
```

### Step 3: Verificar Existência

```bash
for file in $related_files_list; do
  [ -e "$file" ] || [ -d "$file" ] && ((exists++))
done
percent=$((exists * 100 / total))
```

### Step 4: Decidir Status

- Se `related_files > 0` E `percent >= 50` → proposed `implemented`
- Se `related_tasks > 0` E tasklist existe → proposed `implemented`

### Step 5: Apresentar e Confirmar

Mostrar análise detalhada antes de atualizar:
```
## SPEC-XXX: Título
  Status: approved → implementada?
  Files: 5 relacionados, 4 existem (80%)
  Tasks: 3 relacionadas, tasklist existe ✓
  → Atualizar? [S/N]
```

---

## Checklist de Validação

Antes de marcar como `implemented`:

- [ ] Front matter completo (9 campos)
- [ ] `related_files` com pelo menos 1 item
- [ ] `related_files: []` presente (mesmo vazio)
- [ ] `related_tasks: []` presente (mesmo vazio)
- [ ] `updated_at` recente
- [ ] Spec não está em `validated` ou `archived`

---

## Comandos CLI

### `./bin/devorq spec status`

Lista todas as specs com análise detalhada:
```
## SPEC-2026-04-02-001: Fluxo Multi-LLM
  Status: approved
  Domínio: arquitetura
  Related files: 6 (detected: 6)
  Existência: 6/6 (100%) ✓
  → Proposto: implemented
```

### `./bin/devorq spec update`

Atualiza com confirmações:
```
Verificando specs approved...
SPEC-2026-04-02-001: 6 files, 6 existem (100%)
  → Atualizar para implemented? [S/N]: S
  → Atualizado!
Índice regenerado.
```

---

## Regras de Ouro

1. **Front matter é rei**: Sem front matter válido = não analisar
2. **related_files vazio = não implementado**: `[]` significa nada feito
3. **Nunca rebaixa status**: implemented → validated (manual)
4. **50% threshold**: Se 50%+ dos arquivos existem, considerar implementada
5. **Confirmação antes de atualizar**: Sempre perguntar usuário

---

## Padrão de Documentação

Para specs seguirem o padrão e serem detectadas corretamente:

```yaml
---
id: SPEC-2026-04-06-002
title: Nova Feature
domain: arquitetura
status: draft
priority: high
owner: team-core
created_at: 2026-04-06
updated_at: 2026-04-06
source: manual
related_tasks: []
related_files: []
---
```

**Importante:** Sempre incluir `related_tasks: []` e `related_files: []` mesmo que vazios.

---

## Fontes de Verdade

- Docs specs: `docs/specs/`
- Índice: `docs/specs/_index.md`
- Task lists: `.devorq/state/tasklist/`
- CLI: `bin/devorq spec`