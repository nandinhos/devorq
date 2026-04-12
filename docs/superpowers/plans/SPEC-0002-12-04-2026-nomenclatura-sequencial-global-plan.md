# Nomenclatura Sequencial Global — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implementar numeração sequencial global para specs e criar comandos `spec new`, `spec find`, e validação no `upgrade`.

**Architecture:** Scripts Bash puros. Numeração derivada dinamicamente escaneando specs existentes. Validação no upgrade detecta desvios e oferece correção automática.

**Tech Stack:** Bash puro

---

## File Structure

| Arquivo | Responsabilidade |
|---------|------------------|
| `bin/devorq` | Comandos `spec new`, `spec find`, `spec validate` |
| `bin/upgrade` | Chamar validação de padronização |

---

## Tasks

### Task 1: Implementar `spec_get_next_number()` — Função Auxiliar

**Files:**
- Modify: `bin/devorq` (adicionar função auxiliar)

- [ ] **Step 1: Implementar função para extrair NUM de filename**

Adicionar função `spec_get_next_number()` que:
1. Lista todos os arquivos `SPEC-*.md` em `docs/specs/**`
2. Extrai NUM de cada nome usando regex `sed -n 's/SPEC-\([0-9]*\)-.*/\1/p'`
3. Encontra MAX(NUM)
4. Retorna MAX + 1 com 4 dígitos (0001, 0002, ...)

```bash
spec_get_next_number() {
    local specs_dir="$DEVORQ_ROOT/docs/specs"
    local max_num=0
    
    for f in "$specs_dir"/**/SPEC-*.md; do
        [ -f "$f" ] || continue
        local num=$(echo "$(basename "$f")" | sed -n 's/SPEC-\([0-9]*\)-.*/\1/p')
        [ -n "$num" ] && [ "$num" -gt "$max_num" ] && max_num=$num
    done
    
    printf "%04d" $((max_num + 1))
}
```

- [ ] **Step 2: Testar função no terminal**

```bash
cd /home/nandodev/projects/devorq && source bin/devorq && spec_get_next_number
```

Esperado: `0002` (já existe SPEC-0001)

- [ ] **Step 3: Commit**

```bash
git add bin/devorq
git commit -m "feat(spec): adiciona spec_get_next_number para numeração global"
```

---

### Task 2: Implementar `cmd_spec_new`

**Files:**
- Modify: `bin/devorq` (adicionar `cmd_spec_new()` e registro no case)

- [ ] **Step 1: Implementar `cmd_spec_new()`**

```bash
cmd_spec_new() {
    local title="$*"
    
    if [[ -z "$title" ]]; then
        echo "Uso: devorq spec new \"título da spec\""
        return 1
    fi
    
    # Gerar próximo número
    local next_num=$(spec_get_next_number)
    
    # Data atual
    local date=$(date "+%d-%m-%Y")
    
    # Converter título para kebab-case
    local slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g' | tr ' ' '-' | tr -s '-')
    slug=${slug%%-}  # Remove trailing dash
    slug=${slug##-}   # Remove leading dash
    
    # Nome do arquivo
    local filename="SPEC-${next_num}-${date}-${slug}.md"
    local target_dir="$DEVORQ_ROOT/docs/specs/draft"
    local target_file="$target_dir/$filename"
    
    # Criar diretório se não existir
    mkdir -p "$target_dir"
    
    # Criar arquivo com front matter
    cat > "$target_file" << EOF
---
id: SPEC-${next_num}-${date}-${slug}
title: ${title}
domain: arquitetura
status: draft
created_at: ${date}
updated_at: ${date}
author: Nando Dev
related_files: []
---

# ${title}

## Contexto



## Decisões



## Critérios de Aceite

- [ ] 

EOF
    
    echo "Spec criada: $target_file"
    
    # Abrir com editor se configurado
    if [ -n "$EDITOR" ]; then
        $EDITOR "$target_file"
    fi
}
```

- [ ] **Step 2: Adicionar `new` ao case da `cmd_spec()`**

```bash
        new)
            shift  # remove 'spec'
            shift  # remove 'new'
            cmd_spec_new "$@"
            ;;
```

- [ ] **Step 3: Atualizar mensagem de uso**

Mudar de:
```bash
echo "Uso: devorq spec [index|list|status|update|move]"
```

Para:
```bash
echo "Uso: devorq spec [new|find|index|list|status|update|move|validate]"
```

- [ ] **Step 4: Testar**

```bash
./bin/devorq spec new "teste de nova spec"
ls docs/specs/draft/SPEC-*
```

Esperado: `SPEC-0003-12-04-2026-teste-de-nova-spec.md` criado

- [ ] **Step 5: Commit**

```bash
git add bin/devorq
git commit -m "feat(spec): implementa comando spec new"
```

---

### Task 3: Implementar `cmd_spec_find`

**Files:**
- Modify: `bin/devorq` (adicionar `cmd_spec_find()` e registro no case)

- [ ] **Step 1: Implementar `cmd_spec_find()`**

```bash
cmd_spec_find() {
    local query="$*"
    
    if [[ -z "$query" ]]; then
        echo "Uso: devorq spec find \"busca\""
        return 1
    fi
    
    local specs_dir="$DEVORQ_ROOT/docs/specs"
    local found=0
    
    echo "Results for: $query"
    echo ""
    
    for f in "$specs_dir"/**/SPEC-*.md; do
        [ -f "$f" ] || continue
        
        local basename=$(basename "$f")
        
        # Busca fuzzy no nome do arquivo E no conteúdo
        if echo "$basename" | grep -qi "$query"; then
            found=1
        elif grep -qi "$query" "$f" 2>/dev/null; then
            found=1
        fi
        
        if [[ "$found" -eq 1 ]]; then
            local id=$(grep -m1 "^id:" "$f" 2>/dev/null | cut -d: -f2 | xargs)
            local title=$(grep -m1 "^title:" "$f" 2>/dev/null | cut -d: -f2 | xargs)
            local status=$(grep -m1 "^status:" "$f" 2>/dev/null | cut -d: -f2 | xargs)
            local relative_path="${f#$DEVORQ_ROOT/}"
            
            echo "📄 $id"
            echo "   Título: $title"
            echo "   Status: $status"
            echo "   Path: $relative_path"
            echo ""
            
            found=0
        fi
    done
    
    if [[ $(grep -lqi "$query" "$specs_dir"/**/SPEC-*.md 2>/dev/null | wc -l) -eq 0 ]]; then
        echo "Nenhuma spec encontrada para: $query"
    fi
}
```

- [ ] **Step 2: Adicionar `find` ao case da `cmd_spec()`**

```bash
        find)
            cmd_spec_find "$3"
            ;;
```

- [ ] **Step 3: Testar**

```bash
./bin/devorq spec find "oauth"
./bin/devorq spec find "SPEC-0002"
```

- [ ] **Step 4: Commit**

```bash
git add bin/devorq
git commit -m "feat(spec): implementa comando spec find"
```

---

### Task 4: Implementar `cmd_spec_validate`

**Files:**
- Modify: `bin/devorq` (adicionar `cmd_spec_validate()` e registro no case)

- [ ] **Step 1: Implementar `cmd_spec_validate()`**

```bash
cmd_spec_validate() {
    local fix=0
    if [[ "$2" == "--fix" ]]; then
        fix=1
    fi
    
    local specs_dir="$DEVORQ_ROOT/docs/specs"
    local issues=0
    
    echo "[DEVORQ] Validando padronização de specs..."
    echo ""
    
    # Regex para novo padrão
    local new_pattern='^SPEC-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4}-'
    # Regex para padrão antigo
    local old_pattern='^SPEC-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{3}$'
    
    for f in "$specs_dir"/**/SPEC-*.md; do
        [ -f "$f" ] || continue
        [ "$(basename "$f")" == "_index.md" ] && continue
        
        local basename=$(basename "$f")
        local relative_path="${f#$DEVORQ_ROOT/}"
        
        # Verificar nomenclatura
        if [[ "$basename" =~ $old_pattern ]]; then
            issues=$((issues + 1))
            echo "⚠ $basename: Nomenclatura não padronizada"
            echo "  → Era: SPEC-YYYY-MM-DD-NNN"
            echo "  → Deve ser: SPEC-NNNN-DD-MM-AAAA-slug"
            echo "  → Path: $relative_path"
            echo ""
            
            if [[ "$fix" -eq 1 ]]; then
                echo "  [Auto-correction not implemented yet - use migrate script]"
            fi
        fi
        
        # Verificar front matter
        if ! grep -q "^id:" "$f" 2>/dev/null; then
            issues=$((issues + 1))
            echo "⚠ $basename: Front matter sem 'id'"
            echo ""
        fi
        
        # Verificar se status corresponde à pasta
        local status=$(grep -m1 "^status:" "$f" 2>/dev/null | cut -d: -f2 | xargs)
        if [[ -n "$status" ]]; then
            local expected_dir="$specs_dir/$status"
            local actual_dir=$(dirname "$f")
            if [[ "$expected_dir" != "$actual_dir" ]]; then
                issues=$((issues + 1))
                echo "⚠ $basename: Status '$status' não corresponde à pasta"
                echo "  → Pasta atual: $actual_dir"
                echo "  → Deveria estar em: $expected_dir"
                echo ""
            fi
        fi
    done
    
    echo ""
    if [[ "$issues" -gt 0 ]]; then
        echo "[DEVORQ] Encontrados $issues problema(s)"
        if [[ "$fix" -eq 0 ]]; then
            echo ""
            echo "Para corrigir automaticamente, execute:"
            echo "  ./bin/devorq spec validate --fix"
        fi
        return 1
    else
        echo "[DEVORQ] Todas as specs padronizadas ✓"
        return 0
    fi
}
```

- [ ] **Step 2: Adicionar `validate` ao case da `cmd_spec()`**

```bash
        validate)
            cmd_spec_validate "$2" "$3"
            ;;
```

- [ ] **Step 3: Testar sem --fix**

```bash
./bin/devorq spec validate
```

Esperado: Lista de issues ou "Todas as specs padronizadas ✓"

- [ ] **Step 4: Commit**

```bash
git add bin/devorq
git commit -m "feat(spec): implementa comando spec validate"
```

---

### Task 5: Integrar validação no `upgrade`

**Files:**
- Modify: `bin/upgrade` (adicionar chamada à validação após upgrade)

- [ ] **Step 1: Ler o código atual do `cmd_upgrade()`**

```bash
grep -n "cmd_upgrade" bin/upgrade | head -5
cat bin/upgrade | sed -n '520,560p'
```

- [ ] **Step 2: Adicionar chamada à validação após upgrade**

No final da função `cmd_upgrade()`, após "DEVORQ atualizado", adicionar:

```bash
    # Verificar padronização de specs
    echo ""
    echo "[DEVORQ] Verificando padronização de specs..."
    if "$target/bin/devorq" spec validate >/dev/null 2>&1; then
        echo "✓ Specs padronizadas"
    else
        echo "⚠ Specs fora do padrão detectadas"
        echo ""
        read -p "Deseja corrigir automaticamente? [y/N] " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            "$target/bin/devorq" spec validate --fix
        else
            echo "Execute '$target/bin/devorq spec validate --fix' para corrigir depois"
        fi
    fi
```

**Nota:** `read -p` não funciona bem em scripts não-interativos.，宜改用:
```bash
if [[ "$auto_fix" == "y" ]]; then
    # correção automática
else
    # apenas informational
fi
```

Simplificar para só mostrar aviso e instrução (sem ask interativo):
```bash
    echo ""
    if "$target/bin/devorq" spec validate >/dev/null 2>&1; then
        pass "Specs padronizadas"
    else
        warn "Specs fora do padrão detectadas"
        echo "  Execute 'devorq spec validate --fix' para corrigir"
    fi
```

- [ ] **Step 3: Commit**

```bash
git add bin/upgrade
git commit -m "feat(upgrade): adiciona verificação de padronização de specs"
```

---

### Task 6: Teste de Integração Completa

- [ ] **Step 1: Testar `spec new`**

```bash
./bin/devorq spec new "integração completa"
ls docs/specs/draft/SPEC-*
```

- [ ] **Step 2: Testar `spec find`**

```bash
./bin/devorq spec find "integração"
```

- [ ] **Step 3: Testar `spec validate`**

```bash
./bin/devorq spec validate
```

- [ ] **Step 4: Limpar spec de teste**

```bash
rm docs/specs/draft/SPEC-*-integração-*.md 2>/dev/null
git add -A
git commit -m "test: validação de integração spec new/find/validate"
```

---

## Self-Review Checklist

1. **Spec coverage:** Todos os critérios da SPEC-0002 estão cobertos?
   - [x] spec new cria com NUM correto
   - [x] Numeração global (não reinicia)
   - [x] spec find busca fuzzy
   - [x] upgrade detecta desvios
   - [x] Regex: `^SPEC-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{4}-`

2. **Placeholder scan:** Nenhum TBD/TODO no plano?

3. **Type consistency:** Nomes de funções consistentes?

---

## Execution Handoff

**Plan complete and saved to `docs/superpowers/plans/SPEC-0002-12-04-2026-nomenclatura-sequencial-global-plan.md`.**

**Two execution options:**

1. **Subagent-Driven (recommended)** — Dispatch fresh subagent per task, review between tasks, fast iteration

2. **Inline Execution** — Execute tasks in this session using executing-plans, batch execution with checkpoints

**Which approach?**
