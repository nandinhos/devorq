---
id: SPEC-0077-18-04-2026-grafo-dependencias-skills
title: Grafo de Dependências das Skills DEVORQ
domain: arquitetura
status: draft
priority: medium
owner: nando-dev
source: code-review-hermes
created_at: 2026-04-18
updated_at: 2026-04-18
related_tasks: []
related_files:
  - bin/devorq
  - .devorq/skills/pre-flight/SKILL.md
  - .devorq/skills/quality-gate/SKILL.md
  - .devorq/skills/session-audit/SKILL.md
  - .devorq/skills/break/SKILL.md
  - .devorq/skills/handoff/SKILL.md
  - .devorq/skills/tdd/SKILL.md
  - .devorq/skills/learned-lesson/SKILL.md
  - .devorq/skills/spec/SKILL.md
---

# SPEC-0077 — Grafo de Dependências das Skills DEVORQ

**Data**: 2026-04-18
**Status**: draft
**Autor**: Nando Dev / Claude Code

---

## 1. Objetivo

Tornar explícitas as dependências entre as 19 skills do DEVORQ de duas formas:

1. Campo `depends_on:` no frontmatter YAML de cada SKILL.md com dependências conhecidas
2. Subcomando `./bin/devorq skills graph` que lê os frontmatters e exibe o grafo ASCII

---

## 2. Contexto

O Hermes identificou: *"As skills não formam um grafo de dependências. Cada uma é isolada."*

Na prática, existem relações claras entre skills que guiam o fluxo mas nunca foram declaradas:

| Relação | Evidência |
|---|---|
| `pre-flight` → `constraint-loader` | SKILL.md da constraint-loader: "chamado automaticamente pelo /pre-flight" |
| `quality-gate` → `systematic-debugging` | SPEC-0075: trigger adicionado |
| `quality-gate` → `code-review` | SPEC-0075: pré-requisito adicionado |
| `session-audit` → `learned-lesson` | Fluxo obrigatório: session-audit + learned-lesson sempre juntos |
| `break` → `spec` | "Sem spec não existe break" (SKILL.md do spec) |
| `handoff` → `spec` | Handoff carrega a spec como contrato |
| `tdd` → `pre-flight` | TDD só faz sentido após validação de tipos |

Sem declaração explícita, novos contribuidores e outros LLMs precisam inferir essas relações lendo múltiplos arquivos.

---

## 3. Escopo

### 3.1 Escopo Positivo

- [ ] Adicionar campo `depends_on:` ao frontmatter YAML de 8 skills
- [ ] Skills sem dependências declaradas recebem `depends_on: []`
- [ ] Adicionar subcomando `skills graph` ao `cmd_skills()` em `bin/devorq`
- [ ] Atualizar `cmd_help()` para listar o novo subcomando
- [ ] Atualizar `docs/specs/_index.md`

### 3.2 Escopo Negativo

- Não alterar skills além das listadas (10 skills sem dependências conhecidas ficam sem `depends_on:` por ora)
- Não criar sistema de validação de dependências (enforcement)
- Não alterar o comportamento do fluxo — é apenas documentação
- Não alterar a lógica existente de `cmd_skills()` (listagem de skills)
- Não adicionar dependências para SPEC-0076 (context7 é ferramenta, não skill)

---

## 4. Mudanças Técnicas Detalhadas

### T1 — Campo `depends_on:` em 8 skills

Adicionar ao frontmatter YAML de cada SKILL.md, após o campo `globs:`:

| Skill | `depends_on:` |
|---|---|
| `pre-flight` | `[constraint-loader]` |
| `quality-gate` | `[systematic-debugging, code-review]` |
| `session-audit` | `[learned-lesson]` |
| `learned-lesson` | `[]` |
| `spec` | `[]` |
| `break` | `[spec]` |
| `handoff` | `[spec]` |
| `tdd` | `[pre-flight]` |

**Formato YAML exato**:
```yaml
---
name: pre-flight
description: ...
triggers:
  - ...
globs:
  - ...
depends_on:
  - constraint-loader
---
```

Skills sem dependências:
```yaml
depends_on: []
```

---

### T2 — Subcomando `skills graph` em `bin/devorq`

**Arquivo**: `bin/devorq`

Modificar `cmd_skills()` para aceitar argumento `graph`:

```bash
cmd_skills() {
    local subcommand="${1:-list}"

    case "$subcommand" in
        graph) cmd_skills_graph ;;
        list|*) cmd_skills_list ;;
    esac
}
```

Extrair lógica de listagem atual para `cmd_skills_list()`.

Criar `cmd_skills_graph()`:

```bash
cmd_skills_graph() {
    local skills_dir="$DEVORQ_DIR/skills"

    echo "Grafo de Dependências das Skills DEVORQ"
    echo "======================================="
    echo ""

    local has_deps=false
    for skill_dir in "$skills_dir"/*/; do
        [ -d "$skill_dir" ] || continue
        local skill skill_md
        skill=$(basename "$skill_dir")
        skill_md="$skill_dir/SKILL.md"
        [ -f "$skill_md" ] || continue

        # Ler depends_on do frontmatter (entre os --- delimiters)
        local deps
        deps=$(awk '/^---$/{f++} f==1 && /^depends_on:/{found=1; next} f==1 && found && /^  - /{print $2; next} f==1 && found && /^[^ ]/{found=0} f==2{exit}' "$skill_md" 2>/dev/null)

        if [ -n "$deps" ]; then
            has_deps=true
            while IFS= read -r dep; do
                [ -n "$dep" ] && echo "  $skill → $dep"
            done <<< "$deps"
        fi
    done

    if [ "$has_deps" = false ]; then
        echo "  (nenhuma dependência declarada)"
    fi

    echo ""
    echo "Skills sem dependências declaradas:"
    for skill_dir in "$skills_dir"/*/; do
        [ -d "$skill_dir" ] || continue
        local skill skill_md
        skill=$(basename "$skill_dir")
        skill_md="$skill_dir/SKILL.md"
        [ -f "$skill_md" ] || continue

        local has_depends_on
        has_depends_on=$(grep -c "^depends_on:" "$skill_md" 2>/dev/null || echo 0)
        [ "$has_depends_on" -eq 0 ] && echo "  - $skill"
    done
}
```

**Atualizar `cmd_help()`** — na seção de Skills:
```
  skills                        Listar skills disponíveis com versões
  skills graph                  Exibir grafo de dependências entre skills
```

**Registrar no `case` do MAIN**: o `case "skills"` já chama `cmd_skills "$@"` — o subcomando será roteado internamente, sem alterar o case principal.

---

## 5. Output Esperado de `./bin/devorq skills graph`

```
Grafo de Dependências das Skills DEVORQ
=======================================

  pre-flight → constraint-loader
  quality-gate → systematic-debugging
  quality-gate → code-review
  session-audit → learned-lesson
  break → spec
  handoff → spec
  tdd → pre-flight

Skills sem dependências declaradas:
  - brainstorming
  - code-review
  - constraint-loader
  - devorq-setup
  - env-context
  - filament-expert
  - integrity-guardian
  - learned-lesson
  - schema-validate
  - scope-guard
  - spec
  - spec-export
  - spec-manager
  - systematic-debugging
```

---

## 6. Critérios de Aceite

- [ ] `grep "depends_on" .devorq/skills/pre-flight/SKILL.md` retorna `depends_on:`
- [ ] `grep "depends_on" .devorq/skills/quality-gate/SKILL.md` retorna `depends_on:`
- [ ] `bash -n bin/devorq` passa sem erro
- [ ] `./bin/devorq skills graph` exibe pelo menos 7 relações de dependência
- [ ] `./bin/devorq skills` (sem argumento) ainda lista as skills normalmente
- [ ] `./bin/devorq help` menciona `skills graph`

---

## 7. Dependências

- Nenhuma dependência externa
- `awk` disponível (padrão em qualquer sistema Unix)
- SPEC-0076 pode ser implementada antes ou depois desta — independentes

---

## 8. Riscos

| Risco | Probabilidade | Mitigação |
|---|---|---|
| Awk falha em parsear frontmatter com formato inesperado | Baixa | Fallback: `grep -A5 "depends_on:" SKILL.md` como alternativa mais simples |
| Skills adicionadas no futuro sem `depends_on:` | Alta | A seção "Skills sem dependências declaradas" as lista explicitamente |
| `cmd_skills "$@"` não passa args corretamente | Baixa | Verificar com `./bin/devorq skills graph` após implementação |

---

## 9. RESOLUÇÕES DE PANES

*(Nenhuma pane registrada durante análise e criação da SPEC.)*

---

## 10. Estimativa de Esforço

| Task | Arquivos | Esforço |
|---|---|---|
| T1 — `depends_on:` em 8 skills | 8 SKILL.md | 20 min |
| T2 — `skills graph` no CLI | `bin/devorq` | 30 min |
| **Total** | **9 arquivos** | **~50 min** |
