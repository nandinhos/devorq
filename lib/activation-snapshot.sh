#!/bin/bash
# activation-snapshot.sh - Gera snapshot de ativação para bootstrap rápido
# Include: 6 commits recentes + issues + checksums

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AIDEV_ROOT="${AIDEV_ROOT:-$(cd "$_SCRIPT_DIR/.." && pwd)}"
STATE_DIR="$AIDEV_ROOT/state"
SNAPSHOT_FILE="$STATE_DIR/activation_snapshot.json"

# ============================================================================
# DETECÇÃO DE RUNTIME LLM
# ============================================================================
detect_runtime() {
    # OpenCode
    [[ "$OPENCODE" == "1" ]] && echo "opencode" && return
    
    # Claude Code
    [[ "$CLAUDE_CODE" == "1" ]] && echo "claude_code" && return
    
    # Gemini CLI
    command -v gemini &>/dev/null && echo "gemini" && return
    
    # Antigravity (ambiente específico)
    [[ "$ANTIGRAVITY" == "1" ]] && echo "antigravity" && return
    
    # Claude Desktop
    [[ -n "$CLAUDE_DESKTOP" ]] && echo "claude_desktop" && return
    
    echo "unknown"
}

# ============================================================================
# COLETA DE COMMITS RECENTES
# ============================================================================
get_recent_commits() {
    local limit="${1:-6}"
    local commits=$(git log --oneline -"$limit" 2>/dev/null || echo "")
    
    if [ -z "$commits" ]; then
        echo "[]"
        return
    fi
    
    # Processar cada commit
    local json_array="["
    local first=true
    
    while IFS= read -r line; do
        local hash=$(echo "$line" | awk '{print $1}')
        local msg=$(echo "$line" | sed 's/^[^ ]* //')
        
        # Detectar tipo de commit (padrão: tipo(escopo): mensagem)
        local type="chore"
        if [[ "$msg" =~ ^feat ]]; then
            type="feat"
        elif [[ "$msg" =~ ^fix ]]; then
            type="fix"
        elif [[ "$msg" =~ ^refactor ]]; then
            type="refactor"
        elif [[ "$msg" =~ ^docs ]]; then
            type="docs"
        elif [[ "$msg" =~ ^test ]]; then
            type="test"
        elif [[ "$msg" =~ ^release ]]; then
            type="release"
        elif [[ "$msg" =~ ^chore ]]; then
            type="chore"
        fi
        
        # Truncar mensagem para 50 caracteres
        msg="${msg:0:50}"
        
        if [ "$first" = true ]; then
            first=false
        else
            json_array+=","
        fi
        
        json_array+="{\"hash\":\"$hash\",\"type\":\"$type\",\"msg\":\"$msg\"}"
    done <<< "$commits"
    
    json_array+="]"
    echo "$json_array"
}

# ============================================================================
# CONTAGEM DE COMMITS POR CATEGORIA
# ============================================================================
get_commits_by_category() {
    local limit=20
    local commits=$(git log --oneline -"$limit" 2>/dev/null || echo "")
    
    local counts='{"feat":0,"fix":0,"chore":0,"docs":0,"refactor":0,"test":0,"release":0}'
    
    while IFS= read -r line; do
        local msg=$(echo "$line" | sed 's/^[^ ]* //')
        
        if [[ "$msg" =~ ^feat ]]; then
            counts=$(echo "$counts" | jq '.feat += 1')
        elif [[ "$msg" =~ ^fix ]]; then
            counts=$(echo "$counts" | jq '.fix += 1')
        elif [[ "$msg" =~ ^refactor ]]; then
            counts=$(echo "$counts" | jq '.refactor += 1')
        elif [[ "$msg" =~ ^docs ]]; then
            counts=$(echo "$counts" | jq '.docs += 1')
        elif [[ "$msg" =~ ^test ]]; then
            counts=$(echo "$counts" | jq '.test += 1')
        elif [[ "$msg" =~ ^release ]]; then
            counts=$(echo "$counts" | jq '.release += 1')
        elif [[ "$msg" =~ ^chore ]]; then
            counts=$(echo "$counts" | jq '.chore += 1')
        fi
    done <<< "$commits"
    
    echo "$counts"
}

# ============================================================================
# DETECÇÃO DE ISSUES ABERTAS
# ============================================================================
get_issues_observed() {
    # Tenta usar gh CLI se disponível
    if command -v gh &>/dev/null; then
        local open_count=$(gh issue list --state open 2>/dev/null | wc -l || echo "0")
        echo "{\"open\":$open_count,\"source\":\"github\"}"
    else
        echo "{\"open\":0,\"source\":\"none\"}"
    fi
}

# ============================================================================
# OBTEM INFORMAÇÕES DO CHECKPOINT
# ============================================================================
get_checkpoint_info() {
    local checkpoint_file="$STATE_DIR/checkpoint.md"
    
    if [ -f "$checkpoint_file" ]; then
        local date=$(grep -m1 "^# Checkpoint" "$checkpoint_file" | sed 's/# Checkpoint - //')
        local next_action=$(grep -A5 "Próxima Ação" "$checkpoint_file" | tail -1 | xargs)
        echo "{\"date\":\"$date\",\"next_action\":\"$next_action\"}"
    else
        echo "{\"date\":null,\"next_action\":null}"
    fi
}

# ============================================================================
# GERA CHECKSUMS DOS ARQUIVOS DO FRAMEWORK
# ============================================================================
get_framework_checksums() {
    local orchestrator="$AIDEV_ROOT/agents/orchestrator.md"
    local skills_dir="$AIDEV_ROOT/skills"
    local agents_dir="$AIDEV_ROOT/agents"
    
    local orch_hash="null"
    local skills_hash="null"
    local agents_hash="null"
    
    if [ -f "$orchestrator" ]; then
        orch_hash="\"$(md5sum "$orchestrator" 2>/dev/null | awk '{print $1}')\""
    fi
    
    if [ -d "$skills_dir" ]; then
        skills_hash="\"$(find "$skills_dir" -type f -name "*.md" -exec md5sum {} \; 2>/dev/null | sort | md5sum | awk '{print $1}')\""
    fi
    
    if [ -d "$agents_dir" ]; then
        agents_hash="\"$(find "$agents_dir" -type f -name "*.md" -exec md5sum {} \; 2>/dev/null | sort | md5sum | awk '{print $1}')\""
    fi
    
    echo "{\"orchestrator\":$orch_hash,\"skills\":$skills_hash,\"agents\":$agents_hash}"
}

# ============================================================================
# VERIFICA SE UNIFIED.JS PRECISA SINCRONIZA
# ============================================================================
check_unified_sync() {
    local unified_file="$STATE_DIR/unified.json"
    local framework_version="${AIDEV_VERSION:-$(cat "$AIDEV_ROOT/VERSION" 2>/dev/null | tr -d '[:space:]')}"
    framework_version="${framework_version:-4.5.1}"
    
    if [ ! -f "$unified_file" ]; then
        echo "{\"version\":\"none\",\"needs_sync\":true}"
        return
    fi
    
    local unified_version=$(jq -r '.version' "$unified_file" 2>/dev/null || echo "unknown")
    local needs_sync="false"
    
    if [ "$unified_version" != "$framework_version" ]; then
        needs_sync="true"
    fi
    
    echo "{\"version\":\"$unified_version\",\"needs_sync\":$needs_sync}"
}

# ============================================================================
# GERA SNAPSHOT COMPLETO
# ============================================================================
generate_activation_snapshot() {
    local runtime=$(detect_runtime)
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    local framework_version="${AIDEV_VERSION:-$(cat "$AIDEV_ROOT/VERSION" 2>/dev/null | tr -d '[:space:]')}"
    framework_version="${framework_version:-4.5.1}"
    
    # Obter informações do git
    local current_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
    local upstream=$(git rev-parse --abbrev-ref --symbolic-full-name @{u} 2>/dev/null || echo "")
    
    # Obter dados
    local recent_summaries=$(get_recent_commits 6)
    local commits_by_category=$(get_commits_by_category)
    local issues_observed=$(get_issues_observed)
    local checkpoint_info=$(get_checkpoint_info)
    local checksums=$(get_framework_checksums)
    local unified_status=$(check_unified_sync)
    
    # Obter checkpoint_date do checkpoint_info
    local checkpoint_date=$(echo "$checkpoint_info" | jq -r '.date // empty')
    local next_action=$(echo "$checkpoint_info" | jq -r '.next_action // "none"')
    
    # Obter sprint concluídos do checkpoint
    local sprint_completed=0
    if [ -f "$STATE_DIR/checkpoint.md" ]; then
        sprint_completed=$(grep -c "Sprint" "$STATE_DIR/checkpoint.md" 2>/dev/null || echo "0")
        sprint_completed=$((sprint_completed / 2))
    fi
    
    # Montar JSON final
    local snapshot=$(cat <<EOF
{
  "version": "$framework_version",
  "generated_at": "$timestamp",
  "framework_version": "$framework_version",
  "runtime": "$runtime",
  "git_context": {
    "current_branch": "$current_branch",
    "upstream_tracking": "$upstream",
    "commits_by_category": $commits_by_category,
    "recent_summaries": $recent_summaries
  },
  "state": {
    "checkpoint_date": "$checkpoint_date",
    "sprint_completed": $sprint_completed,
    "next_action": "$next_action",
    "unified": $unified_status
  },
  "issues_observed": $issues_observed,
  "checksums": $checksums
}
EOF
)
    
    # Garantir diretório state existe
    mkdir -p "$STATE_DIR"
    
    # Escrever snapshot
    echo "$snapshot" | jq -c . > "$SNAPSHOT_FILE"
    
    echo "Snapshot gerado: $SNAPSHOT_FILE"
}

# ============================================================================
# VERIFICA SE SNAPSHOT EXISTE E É VÁLIDO
# ============================================================================
is_snapshot_valid() {
    if [ ! -f "$SNAPSHOT_FILE" ]; then
        return 1
    fi
    
    # Verificar se tem menos de 1 hora
    local generated_at=$(jq -r '.generated_at' "$SNAPSHOT_FILE" 2>/dev/null)
    if [ "$generated_at" = "null" ] || [ -z "$generated_at" ]; then
        return 1
    fi
    
    # Verificar estrutura básica
    if ! jq -e '.version' "$SNAPSHOT_FILE" >/dev/null 2>&1; then
        return 1
    fi
    
    return 0
}

# ============================================================================
# LÊ SNAPSHOT PARA ATIVAÇÃO RÁPIDA
# ============================================================================
read_snapshot() {
    if is_snapshot_valid; then
        cat "$SNAPSHOT_FILE"
    else
        generate_activation_snapshot
        cat "$SNAPSHOT_FILE"
    fi
}

# ============================================================================
# EXPORTA RESUMO DO SNAPSHOT PARA INJEÇÃO EM LLM
# ============================================================================
export_snapshot_summary() {
    local snapshot=$(read_snapshot)
    
    echo "=== STATUS ATUAL ==="
    echo "Branch: $(echo "$snapshot" | jq -r '.git_context.current_branch')"
    echo "Sprints concluídos: $(echo "$snapshot" | jq -r '.state.sprint_completed')"
    echo "Próxima ação: $(echo "$snapshot" | jq -r '.state.next_action')"
    echo ""
    echo "=== ÚLTIMOS COMMITS ==="
    echo "$snapshot" | jq -r '.git_context.recent_summaries[] | "\(.type): \(.msg)"'
    echo ""
    echo "=== ISSUES ABERTAS ==="
    echo "$snapshot" | jq -r '.issues_observed.open'
}

# ============================================================================
# AUTO-SINCRONIZAÇÃO (para chamar após tarefas)
# ============================================================================
auto_sync() {
    generate_activation_snapshot
}

# Se chamado diretamente, gera snapshot
if [ "${BASH_SOURCE[0]}" == "${0}" ]; then
    generate_activation_snapshot
    cat "$SNAPSHOT_FILE"
fi
