# HANDOFF DEVORQ — 20260418_060000

**Destinatário**: MiniMax
**Gerado por**: Claude Code (Sonnet 4.6)
**Projeto**: DEVORQ — Meta-framework de orquestração Multi-LLM
**Gate**: 4 — Transferência para implementação

---

## CONTEXTO

- **Stack**: Shell/Bash puro (4.0+) + Markdown (SKILL.md frontmatter YAML)
- **Branch**: `main`
- **Último commit**: `c8f778d feat(workflow): adiciona rastreabilidade de panes, hook pre-commit e integração formal de skills`
- **Status**: SPEC-0077 criada e aprovada no Gate 1. Task list pronta. SPEC-0076 pode já ter sido implementada antes desta.

### O que foi feito antes desta SPEC

- SPEC-0075 ✅ — Hook pre-commit, RESOLUÇÕES DE PANES, quality-gate triggers
- SPEC-0076 ✅ (esperado) — Context7 em pre-flight, constraint-loader e learned-lesson

---

## TAREFA

Implementar **2 mudanças** para tornar visível o grafo de dependências entre as 19 skills do DEVORQ.

| Task | O que fazer |
|---|---|
| T1 | Adicionar `depends_on:` ao frontmatter de 8 SKILL.md |
| T2 | Criar subcomando `./bin/devorq skills graph` que exibe o grafo ASCII |

---

## ARTEFATOS DE PLANEJAMENTO

1. **SPEC completa**: `docs/specs/draft/SPEC-0077-18-04-2026-grafo-dependencias-skills.md`
2. **Task list**: `.devorq/state/tasklist/spec-0077-grafo-dependencias-skills-tasks.md`

---

## CONSTRAINTS

- **`awk` para parsear frontmatter**: preferir `awk` sobre `python3` para leitura do `depends_on:` — mais portável
- **Padrão dual-use no bin/devorq**: qualquer nova função deve seguir a estrutura `cmd_*` existente
- **`set -eEo pipefail` NUNCA global**: se necessário, usar dentro de `main()` (LESSON-0014)
- **`cmd_skills "$@"` já está no MAIN**: não precisa alterar o `case` principal

---

## NUNCA FAZER

- ❌ Não alterar o comportamento de `./bin/devorq skills` sem argumento — deve continuar listando skills normalmente
- ❌ Não renomear `cmd_skills` — extrair para `cmd_skills_list` e criar `cmd_skills_graph`
- ❌ Não adicionar `depends_on:` às 11 skills não listadas (brainstorming, code-review, constraint-loader, devorq-setup, env-context, filament-expert, integrity-guardian, schema-validate, scope-guard, spec-export, spec-manager, systematic-debugging)
- ❌ Não confundir `cmd_skill` (singular — versionamento) com `cmd_skills` (plural — listagem)
- ❌ Não validar se dependências existem como skills — apenas exibir o que está declarado

---

## ARQUIVOS PERMITIDOS

```
.devorq/skills/pre-flight/SKILL.md       ← T1 (depends_on: [constraint-loader])
.devorq/skills/quality-gate/SKILL.md     ← T1 (depends_on: [systematic-debugging, code-review])
.devorq/skills/session-audit/SKILL.md    ← T1 (depends_on: [learned-lesson])
.devorq/skills/learned-lesson/SKILL.md   ← T1 (depends_on: [])
.devorq/skills/spec/SKILL.md             ← T1 (depends_on: [])
.devorq/skills/break/SKILL.md            ← T1 (depends_on: [spec])
.devorq/skills/handoff/SKILL.md          ← T1 (depends_on: [spec])
.devorq/skills/tdd/SKILL.md              ← T1 (depends_on: [pre-flight])
bin/devorq                               ← T2
docs/specs/draft/SPEC-0077-*.md          ← atualizar status (opcional)
docs/specs/_index.md                     ← atualizar contagem/status
```

## ARQUIVOS PROIBIDOS

```
.devorq/skills/brainstorming/SKILL.md
.devorq/skills/code-review/SKILL.md
.devorq/skills/constraint-loader/SKILL.md    ← (a não ser que SPEC-0076 já alterou)
.devorq/skills/systematic-debugging/SKILL.md
[qualquer outra skill não listada acima]
lib/*.sh
tests/
```

---

## FORMATO EXATO DO FRONTMATTER

**Com dependências** (exemplo: pre-flight):
```yaml
---
name: pre-flight
description: Validação de schema/enums/tipos antes de implementar código de domínio
triggers:
  - "pre-flight"
  - ...
globs:
  - "**/*.php"
  - ...
depends_on:
  - constraint-loader
---
```

**Sem dependências** (exemplo: spec):
```yaml
---
name: spec
description: ...
triggers:
  - ...
globs:
  - ...
depends_on: []
---
```

---

## CÓDIGO EXATO PARA T2 (`bin/devorq`)

### Função `cmd_skills_list()` (extraída do `cmd_skills()` atual)

```bash
cmd_skills_list() {
    local skills_dir="$DEVORQ_DIR/skills"

    if [ ! -d "$skills_dir" ]; then
        echo "Skills DEVORQ (0 skills):"
        return 0
    fi

    echo "Skills DEVORQ ($(ls -1 "$skills_dir/" 2>/dev/null | wc -l | tr -d ' ') skills):"

    local found_any=false
    for skill_dir in "$skills_dir"/*/; do
        [ -d "$skill_dir" ] || continue
        found_any=true
        local skill
        skill=$(basename "$skill_dir")
        local version=""
        if [ -f "$skill_dir/CHANGELOG.md" ]; then
            version=$(grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' "$skill_dir/CHANGELOG.md" 2>/dev/null | head -1)
        fi
        echo "  - $skill ${version:-v?}"
    done
}
```

### Função `cmd_skills_graph()`

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

        # Extrair items do depends_on do frontmatter YAML (entre --- delimiters)
        local deps
        deps=$(awk '
            /^---$/ { delim_count++; next }
            delim_count == 1 && /^depends_on:/ { in_deps=1; next }
            delim_count == 1 && in_deps && /^  - / { print $2; next }
            delim_count == 1 && in_deps && /^[^ ]/ { in_deps=0 }
            delim_count == 2 { exit }
        ' "$skill_md" 2>/dev/null)

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

        local has_dep_field
        has_dep_field=$(grep -c "^depends_on:" "$skill_md" 2>/dev/null || echo 0)
        [ "$has_dep_field" -eq 0 ] && echo "  - $skill"
    done
}
```

### Novo `cmd_skills()` com roteamento

```bash
cmd_skills() {
    local subcommand="${1:-list}"
    case "$subcommand" in
        graph) cmd_skills_graph ;;
        list|*) cmd_skills_list ;;
    esac
}
```

### Linha a adicionar no `cmd_help()` (seção Comandos principais):

Substituir:
```
  skills                        Listar skills disponíveis com versões
```
Por:
```
  skills                        Listar skills disponíveis com versões
  skills graph                  Exibir grafo de dependências entre skills
```

---

## DONE CRITERIA (verificação final)

```bash
# T1 — 8 skills com depends_on
for skill in pre-flight quality-gate session-audit learned-lesson spec break handoff tdd; do
  count=$(grep -c "depends_on:" ".devorq/skills/$skill/SKILL.md" 2>/dev/null || echo 0)
  echo "  $skill: $count"  # esperado: 1 para todos
done

# T2 — CLI funcional
bash -n bin/devorq && echo "Syntax: OK"
./bin/devorq skills           # deve listar skills normalmente
./bin/devorq skills graph     # deve exibir relações
./bin/devorq help | grep "skills graph"  # deve aparecer
```

---

## OUTPUT ESPERADO

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

## COMMIT ESPERADO

```
feat(skills): adiciona grafo de dependencias e campo depends_on nas skills
```
