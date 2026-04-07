#!/bin/bash
# workflow-sync.sh - Hook de sincronização automática após tarefas
# Sincroniza: activation_snapshot + unified.json
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "ERRO: Este módulo deve ser carregado via 'source', não executado." >&2; exit 1; fi

_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEVORQ_ROOT="${DEVORQ_ROOT:-$(cd "$_SCRIPT_DIR/.." && pwd)}"
source "$DEVORQ_ROOT/lib/activation-snapshot.sh"

# ============================================================================
# VERIFICA SE HÁ CHANGES PARA COMMITAR ANTES DE SYNC
# ============================================================================
has_pending_changes() {
    if [ -d ".git" ]; then
        local status=$(git status --porcelain 2>/dev/null)
        [ -n "$status" ]
        return $?
    fi
    return 1
}

# ============================================================================
# DETECTA TIPO DE ALTERAÇÃO
# ============================================================================
detect_change_type() {
    local status=$(git status --porcelain 2>/dev/null)
    
    # Contar por tipo
    local added=$(echo "$status" | grep "^??" | wc -l)
    local modified=$(echo "$status" | grep "^.M" | wc -l)
    local deleted=$(echo "$status" | grep "^.D" | wc -l)
    
    # Detectar tipo baseado em padrões de arquivo
    if echo "$status" | grep -q "test"; then
        echo "test"
    elif echo "$status" | grep -q "docs/"; then
        echo "docs"
    elif [ "$added" -gt 5 ]; then
        echo "feat"
    elif [ "$deleted" -gt 0 ]; then
        echo "fix"
    elif [ "$modified" -gt 0 ]; then
        echo "chore"
    else
        echo "chore"
    fi
}

# ============================================================================
# SINCRONIZA SNAPSHOT (principal função)
# ============================================================================
sync_workflow() {
    local force="${1:-false}"
    local task_name="${2:-manual}"
    
    echo "=== Workflow Sync: $task_name ==="
    
    # 1. Verificar se há changes pendentes (se for auto-sync)
    if [ "$task_name" = "auto" ] && has_pending_changes; then
        echo "⚠️  Alterações pendentes detectadas!"
        local change_type=$(detect_change_type)
        echo "   Tipo detectado: $change_type"
        echo "   Execute 'devorq commit <msg>' antes de sincronizar"
    fi
    
    # 2. Verificar unified.json (se precisa sync)
    local unified_status=$(check_unified_sync)
    local needs_sync=$(echo "$unified_status" | jq -r '.needs_sync')
    
    if [ "$needs_sync" = "true" ] || [ "$force" = "true" ]; then
        echo "⚠️  unified.json desatualizado, sincronizando..."
        sync_unified_json
    else
        echo "✅ unified.json OK"
    fi
    
    # 3. Regenerar activation snapshot
    echo "📸 Gerando snapshot..."
    generate_activation_snapshot
    
    # 4. Verificar integridade do snapshot
    if is_snapshot_valid; then
        echo "✅ Snapshot válido"
        export_snapshot_summary
    else
        echo "❌ Erro ao gerar snapshot"
        return 1
    fi
    
    echo "=== Sync concluído ==="
}

# ============================================================================
# SINCRONIZA unified.json COM ESTADO ATUAL
# ============================================================================
sync_unified_json() {
    local unified_file="$DEVORQ_ROOT/state/unified.json"
    local framework_version="${DEVORQ_VERSION:-$(cat "$DEVORQ_ROOT/VERSION" 2>/dev/null | tr -d '[:space:]')}"
    framework_version="${framework_version:-4.5.1}"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    if [ -f "$unified_file" ]; then
        # Atualizar versão e timestamp
        local updated=$(jq --arg version "$framework_version" \
                          --arg timestamp "$timestamp" \
                          '.version = $version | .session.last_activity = $timestamp' \
                          "$unified_file")
        echo "$updated" > "$unified_file"
        echo "✅ unified.json atualizado para v$framework_version"
    else
        # Criar novo unified.json
        cat > "$unified_file" <<EOF
{
  "version": "$framework_version",
  "session": {
    "id": "$(uuidgen 2>/dev/null || echo "generated-$(date +%s)")",
    "started_at": "$timestamp",
    "last_activity": "$timestamp",
    "project_name": ".",
    "stack": "generic"
  },
  "active_skill": null,
  "active_agent": null,
  "checkpoints": {},
  "artifacts": [],
  "agent_queue": [],
  "confidence_log": [],
  "rollback_stack": []
}
EOF
        echo "✅ unified.json criado"
    fi
}

# ============================================================================
# VALIDA CONFORMIDADE DO SISTEMA
# ============================================================================
validate_conformity() {
    echo "=== Validação de Conformidade ==="
    
    local issues=0
    
    # 1. Verificar snapshot
    if is_snapshot_valid; then
        echo "✅ Snapshot válido em .devorq/state/"
    else
        echo "❌ Snapshot inválido ou ausente em .devorq/state/"
        ((issues++))
    fi
    
    # 1.5 Verificar se há snapshots falsos na raiz
    local root_state_dir="$DEVORQ_ROOT/../state"
    if [ -d "$root_state_dir" ]; then
        echo "❌ Snapshot espúrio detectado na raiz do projeto (diretório 'state/')"
        ((issues++))
    fi
    
    # 2. Verificar unified.json
    local unified_status=$(check_unified_sync)
    local needs_sync=$(echo "$unified_status" | jq -r '.needs_sync')
    if [ "$needs_sync" = "false" ]; then
        echo "✅ unified.json sincronizado"
    else
        echo "⚠️  unified.json precisa sincronização"
        ((issues++))
    fi
    
    # 3. Verificar git
    if git rev-parse --git-dir &>/dev/null; then
        echo "✅ Git OK"
    else
        echo "❌ Não é repositório git"
        ((issues++))
    fi
    
    # 4. Verificar branch
    local branch=$(git branch --show-current 2>/dev/null)
    echo "✅ Branch: $branch"
    
    echo ""
    if [ $issues -eq 0 ]; then
        echo "=== STATUS: ✅ CONFORME ==="
        return 0
    else
        echo "=== STATUS: ⚠️ $issues ISSUE(S) ==="
        return 1
    fi
}

# ============================================================================
# HOOK PARA CHAMAR APÓS CONCLUSÃO DE TAREFA
# ============================================================================
task_complete() {
    local task_name="${1:-unnamed}"
    local exit_code="${2:-0}"
    
    echo "=== Task Complete: $task_name (exit: $exit_code) ==="
    
    if [ "$exit_code" -eq 0 ]; then
        sync_workflow "false" "task:$task_name"
    else
        echo "⚠️  Task falhou (exit $exit_code), sync opcional"
        sync_workflow "true" "task:$task_name:failed"
    fi
}

