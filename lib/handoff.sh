#!/bin/bash
# lib/handoff.sh — Geração e rastreamento de handoff multi-LLM

# =====================================================
# GERAR HANDOFF
# =====================================================

generate_handoff() {
    local devorq_dir="$1"
    local devorq_root="$2"
    local handoffs_dir="$devorq_dir/state/handoffs"
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)

    mkdir -p "$handoffs_dir"

    # Coletar dados do contexto
    local branch=""
    local last_commit=""
    local git_status=""
    if git -C "$devorq_root" rev-parse --git-dir > /dev/null 2>&1; then
        branch=$(git -C "$devorq_root" branch --show-current 2>/dev/null || echo "desconhecida")
        last_commit=$(git -C "$devorq_root" log --oneline -1 2>/dev/null || echo "sem commits")
        git_status=$(git -C "$devorq_root" status --short 2>/dev/null | head -10)
    fi

    # Ler contexto detectado
    local stack="desconhecido"
    local runtime="desconhecido"
    local project_name
    project_name=$(basename "$devorq_root")

    local session_file="$devorq_dir/state/session.json"
    if [ -f "$session_file" ] && command -v jq > /dev/null 2>&1; then
        stack=$(jq -r '.stack // "desconhecido"' "$session_file" 2>/dev/null)
        runtime=$(jq -r '.runtime // "desconhecido"' "$session_file" 2>/dev/null)
    fi

    # Ler contrato ativo do scope-guard
    local contract_content=""
    local contracts_dir="$devorq_dir/state/contracts"
    if [ -d "$contracts_dir" ]; then
        local latest_contract
        latest_contract=$(ls -t "$contracts_dir"/*.md 2>/dev/null | head -1)
        if [ -n "$latest_contract" ]; then
            contract_content=$(cat "$latest_contract")
        fi
    fi

    local handoff_file="$handoffs_dir/handoff_${timestamp}.md"

    cat > "$handoff_file" << EOF
# HANDOFF DEVORQ — $timestamp
## Destinatário: [Gemini CLI / MiniMax / OpenCode / Antigravity]
## Gerado por: [LLM atual]
## Projeto: $project_name
## Status: em_andamento

### CONTEXTO
- Stack: $stack
- Runtime: $runtime
- Branch: $branch
- Ultimo commit: $last_commit

### GIT STATUS
\`\`\`
${git_status:-sem alterações}
\`\`\`

### TAREFA
[Preencher com a descrição da task do contrato /scope-guard ativo]

### CONSTRAINTS OBRIGATÓRIOS
- Runtime: [comando base, ex: vendor/bin/sail artisan]
- Portas: app=[porta] | db=[porta]
- Binaries disponíveis: [ex: PDO sim, mysql binary nao]
- Variaveis de ambiente: [ex: WWWUSER=1000]
- NUNCA fazer: [lista de gotchas]

### ENUMS E TIPOS VÁLIDOS
[Copiar textualmente do código — não inferir, não inventar]

### ARQUIVOS PERMITIDOS
[Lista do contrato /scope-guard]

### ARQUIVOS PROIBIDOS
[Lista do contrato /scope-guard]

### CRITERIO DE DONE
- [ ] item 1
- [ ] item 2

### DECISÕES JÁ TOMADAS
[Decisões arquiteturais da sessão atual]

### ANTI-PATTERNS
[Armadilhas identificadas — o que não fazer]

---
Contrato scope-guard ativo:
${contract_content:-[Nenhum contrato ativo encontrado — executar /scope-guard primeiro]}
EOF

    echo "$handoff_file"
}

# =====================================================
# STATUS DO HANDOFF
# =====================================================

handoff_status() {
    local devorq_dir="$1"
    local handoffs_dir="$devorq_dir/state/handoffs"

    if [ ! -d "$handoffs_dir" ] || [ -z "$(ls -A "$handoffs_dir" 2>/dev/null)" ]; then
        echo "Nenhum handoff encontrado."
        return 0
    fi

    local latest
    latest=$(ls -t "$handoffs_dir"/handoff_*.md 2>/dev/null | head -1)

    if [ -z "$latest" ]; then
        echo "Nenhum handoff encontrado."
        return 0
    fi

    echo "=== HANDOFF ATUAL ==="
    echo "Arquivo: $(basename "$latest")"

    # Ler status do handoff
    local status
    status=$(grep -o 'Status: [a-z_]*' "$latest" 2>/dev/null | head -1 | cut -d' ' -f2)
    echo "Status: ${status:-em_andamento}"

    # Mostrar destinatário
    local dest
    dest=$(grep 'Destinatário:' "$latest" 2>/dev/null | head -1 | sed 's/## Destinatário: //')
    echo "Destinatario: ${dest:-[não definido]}"

    echo ""
    echo "Para ver o conteúdo completo:"
    echo "  cat $latest"
}

# =====================================================
# LISTAGEM DE HANDOFFS
# =====================================================

handoff_list() {
    local devorq_dir="$1"
    local handoffs_dir="$devorq_dir/state/handoffs"

    echo "=== HISTÓRICO DE HANDOFFS ==="

    if [ ! -d "$handoffs_dir" ] || [ -z "$(ls -A "$handoffs_dir" 2>/dev/null)" ]; then
        echo "Nenhum handoff encontrado."
        return 0
    fi

    local count=0
    for f in $(ls -t "$handoffs_dir"/handoff_*.md 2>/dev/null); do
        count=$((count + 1))
        local name
        name=$(basename "$f" .md)
        local status
        status=$(grep -o 'Status: [a-z_]*' "$f" 2>/dev/null | head -1 | cut -d' ' -f2 || echo "desconhecido")
        echo "  [$count] $name — $status"
    done

    echo ""
    echo "Total: $count handoff(s)"
}

# =====================================================
# ATUALIZAR STATUS DO HANDOFF
# =====================================================

handoff_update_status() {
    local devorq_dir="$1"
    local new_status="$2"  # em_andamento | aguardando_merge | concluido
    local handoffs_dir="$devorq_dir/state/handoffs"

    local latest
    latest=$(ls -t "$handoffs_dir"/handoff_*.md 2>/dev/null | head -1)

    if [ -z "$latest" ]; then
        echo "Nenhum handoff ativo encontrado."
        return 1
    fi

    # Atualizar status no arquivo
    if command -v sed > /dev/null 2>&1; then
        sed -i "s/Status: [a-z_]*/Status: $new_status/" "$latest"
        echo "Status do handoff atualizado: $new_status"
        echo "Arquivo: $(basename "$latest")"
    fi
}
