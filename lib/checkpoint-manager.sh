#!/bin/bash

# ============================================================================
# AI Dev Superpowers V3 - Checkpoint Manager Module
# ============================================================================
# Gestao de checkpoints automaticos para preservacao de contexto
# Cria, lista, restaura e exporta checkpoints de sessao
#
# Uso: source lib/checkpoint-manager.sh
# Dependencias: lib/context-monitor.sh
# ============================================================================

# ============================================================================
# CRIAR CHECKPOINT
# ============================================================================

# Cria um novo checkpoint com snapshot completo do estado
# Uso: ckpt_create <install_path> <trigger> <description> [chain_of_thought] [hypothesis] [mental_model] [observations]
# Triggers: "manual" | "task_completed" | "auto_checkpoint" | "force_save" | "architectural_decision"
# Retorna: checkpoint ID
ckpt_create() {
    local install_path="${1:-${CLI_INSTALL_PATH:-.}}"
    local trigger="${2:-manual}"
    local description="${3:-Checkpoint}"
    local cot="${4:-}"
    local hypothesis="${5:-}"
    local mental_model="${6:-}"
    local observations="${7:-}"
    local ckpt_dir="$install_path/.aidev/state/sprints/current/checkpoints"
    local unified_file="$install_path/.aidev/state/unified.json"
    local sprint_file="$install_path/.aidev/state/sprints/current/sprint-status.json"

    mkdir -p "$ckpt_dir"

    # MCP Fallback Check - Hook pré-checkpoint
    source "$install_path/lib/mcp-fallback.sh" 2>/dev/null || true
    if type mcp_fallback_hook_ckpt_create &>/dev/null; then
        mcp_fallback_hook_ckpt_create || true
    fi

    # Gera ID unico
    local timestamp=$(date +%s)
    local random_suffix=$((RANDOM % 100000))
    local ckpt_id="ckpt-${timestamp}-${random_suffix}"

    local ckpt_file="$ckpt_dir/${ckpt_id}.json"

    # Snapshot do estado unificado
    local state_snapshot="{}"
    if [ -f "$unified_file" ] && command -v jq >/dev/null 2>&1; then
        state_snapshot=$(jq '.' "$unified_file" 2>/dev/null || echo "{}")
    fi

    # Snapshot da sprint
    local sprint_snapshot="{}"
    if [ -f "$sprint_file" ] && command -v jq >/dev/null 2>&1; then
        sprint_snapshot=$(jq '.' "$sprint_file" 2>/dev/null || echo "{}")
    fi

    # Resolve version: prioriza VERSION file sobre unified.json
    local version_file="$install_path/VERSION"
    local resolved_version
    if [ -f "$version_file" ]; then
        resolved_version=$(tr -d '[:space:]' < "$version_file")
    fi
    if [ -z "$resolved_version" ] && command -v jq >/dev/null 2>&1; then
        resolved_version=$(echo "$state_snapshot" | jq -r '.version // ""' 2>/dev/null || echo "")
    fi
    resolved_version="${resolved_version:-unknown}"

    # Resolve project_name: prioriza unified.json, fallback basename do install_path
    local resolved_project=""
    if command -v jq >/dev/null 2>&1; then
        resolved_project=$(echo "$state_snapshot" | jq -r '.session.project_name // ""' 2>/dev/null || echo "")
    fi
    if [ -z "$resolved_project" ] || [ "$resolved_project" = "null" ]; then
        resolved_project=$(basename "$install_path")
    fi

    # Resolve sprint_name: fallback "lifecycle-transition" quando vazio/null
    local resolved_sprint_name=""
    if command -v jq >/dev/null 2>&1; then
        resolved_sprint_name=$(echo "$sprint_snapshot" | jq -r '.sprint_name // ""' 2>/dev/null || echo "")
    fi
    if [ -z "$resolved_sprint_name" ] || [ "$resolved_sprint_name" = "null" ]; then
        resolved_sprint_name="lifecycle-transition"
    fi

    # Injeta valores resolvidos nos snapshots
    if command -v jq >/dev/null 2>&1; then
        state_snapshot=$(echo "$state_snapshot" | jq \
            --arg v "$resolved_version" \
            --arg p "$resolved_project" \
            '.version = $v | .session.project_name = $p' 2>/dev/null || echo "$state_snapshot")
        sprint_snapshot=$(echo "$sprint_snapshot" | jq \
            --arg sn "$resolved_sprint_name" \
            'if (.sprint_name == null or .sprint_name == "") then .sprint_name = $sn else . end' 2>/dev/null || echo "$sprint_snapshot")
    fi

    # Monta checkpoint JSON com cognitive_context
    if command -v jq >/dev/null 2>&1; then
        jq -n \
            --arg id "$ckpt_id" \
            --arg trigger "$trigger" \
            --arg desc "$description" \
            --arg created "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
            --argjson state "$state_snapshot" \
            --argjson sprint "$sprint_snapshot" \
            --arg cot "$cot" \
            --arg hyp "$hypothesis" \
            --arg mm "$mental_model" \
            --arg obs "$observations" \
            '{
                checkpoint_id: $id,
                trigger: $trigger,
                description: $desc,
                created_at: $created,
                state_snapshot: $state,
                sprint_snapshot: $sprint,
                cognitive_context: {
                    chain_of_thought: $cot,
                    current_hypothesis: $hyp,
                    mental_model: $mm,
                    observations: $obs,
                    confidence: 0,
                    decisions_pending: []
                }
            }' > "$ckpt_file"
    fi

    # Gera fallback artifacts (Feature 5.3)
    if [ "${CKPT_GENERATE_FALLBACK:-false}" = "true" ] && [ -f "$ckpt_file" ]; then
        if type fallback_generate_all &>/dev/null; then
            fallback_generate_all "$install_path" "$ckpt_file" > /dev/null 2>&1 || true
        fi
    fi

    # Sync para Basic Memory (Sprint 3: graceful via ckpt_sync_to_basic_memory)
    if [ -f "$ckpt_file" ]; then
        ckpt_sync_to_basic_memory "$ckpt_file" 2>/dev/null || true
    fi

    echo "$ckpt_id"
}

# ============================================================================
# LISTAR CHECKPOINTS
# ============================================================================

# Lista todos os checkpoints existentes
# Uso: ckpt_list <install_path>
# Retorna: lista de checkpoint IDs (um por linha)
ckpt_list() {
    local install_path="${1:-${CLI_INSTALL_PATH:-.}}"
    local ckpt_dir="$install_path/.aidev/state/sprints/current/checkpoints"

    if [ ! -d "$ckpt_dir" ]; then
        echo ""
        return 0
    fi

    local files=$(ls "$ckpt_dir"/ckpt-*.json 2>/dev/null)
    if [ -z "$files" ]; then
        echo ""
        return 0
    fi

    for f in $files; do
        basename "$f" .json
    done
}

# ============================================================================
# OBTER MAIS RECENTE
# ============================================================================

# Retorna o checkpoint mais recente
# Uso: ckpt_get_latest <install_path>
# Retorna: checkpoint ID ou vazio
ckpt_get_latest() {
    local install_path="${1:-${CLI_INSTALL_PATH:-.}}"
    local ckpt_dir="$install_path/.aidev/state/sprints/current/checkpoints"

    if [ ! -d "$ckpt_dir" ]; then
        return 0
    fi

    local latest
    latest=$(ls -t "$ckpt_dir"/ckpt-*.json 2>/dev/null | head -1) || true
    
    if [ -z "$latest" ] || [ ! -f "$latest" ]; then
        return 0
    fi

    basename "$latest" .json
}

# ============================================================================
# GERAR PROMPT DE RESTAURACAO
# ============================================================================

# Gera um prompt de restauracao para o LLM a partir de um checkpoint
# Uso: ckpt_generate_restore_prompt <checkpoint_file>
# Retorna: texto do prompt
ckpt_generate_restore_prompt() {
    local ckpt_file="$1"

    if [ ! -f "$ckpt_file" ]; then
        echo ""
        return 1
    fi

    if ! command -v jq >/dev/null 2>&1; then
        echo ""
        return 1
    fi

    local ckpt_id=$(jq -r '.checkpoint_id // "unknown"' "$ckpt_file")
    local trigger=$(jq -r '.trigger // "unknown"' "$ckpt_file")
    local desc=$(jq -r '.description // ""' "$ckpt_file")
    local created=$(jq -r '.created_at // "unknown"' "$ckpt_file")

    # Estado
    local project=$(jq -r '.state_snapshot.session.project_name // ""' "$ckpt_file")
    [ -z "$project" ] || [ "$project" = "null" ] && project=$(basename "$PWD")
    local intent=$(jq -r '.state_snapshot.active_intent // "none"' "$ckpt_file")
    local intent_desc=$(jq -r '.state_snapshot.intent_description // ""' "$ckpt_file")

    # Sprint
    local sprint_id=$(jq -r '.sprint_snapshot.sprint_id // "none"' "$ckpt_file")
    local sprint_name=$(jq -r '.sprint_snapshot.sprint_name // ""' "$ckpt_file")
    [ -z "$sprint_name" ] || [ "$sprint_name" = "null" ] && sprint_name="lifecycle-transition"
    local sprint_status=$(jq -r '.sprint_snapshot.status // "unknown"' "$ckpt_file")
    local current_task=$(jq -r '.sprint_snapshot.current_task // "none"' "$ckpt_file")
    local completed=$(jq -r '.sprint_snapshot.overall_progress.completed // 0' "$ckpt_file")
    local total=$(jq -r '.sprint_snapshot.overall_progress.total_tasks // 0' "$ckpt_file")

    # Contexto cognitivo (Sprint 5 - Feature 5.1)
    local cot=$(jq -r '.cognitive_context.chain_of_thought // ""' "$ckpt_file")
    local hypothesis=$(jq -r '.cognitive_context.current_hypothesis // ""' "$ckpt_file")
    local mental_model=$(jq -r '.cognitive_context.mental_model // ""' "$ckpt_file")
    local observations=$(jq -r '.cognitive_context.observations // ""' "$ckpt_file")

    cat << EOF
============================================================
RESTAURAR CONTEXTO - AI Dev Superpowers
============================================================

Checkpoint: $ckpt_id
Criado em: $created
Trigger: $trigger
Descricao: $desc

PROJETO: $project

INTENT ATIVO: $intent
$intent_desc

SPRINT: $sprint_id
Nome: $sprint_name
Status: $sprint_status
Progresso: $completed/$total tarefas
Task Atual: $current_task
EOF

    # Secao cognitiva - so exibe se ha conteudo preenchido
    if [ -n "$cot" ] || [ -n "$hypothesis" ] || [ -n "$mental_model" ]; then
        echo ""
        echo "CONTEXTO COGNITIVO:"
        [ -n "$cot" ] && echo "Raciocinio: $cot"
        [ -n "$hypothesis" ] && echo "Hipotese: $hypothesis"
        [ -n "$mental_model" ] && echo "Modelo Mental: $mental_model"
        [ -n "$observations" ] && echo "Observacoes: $observations"
    fi

    cat << EOF

INSTRUCAO: Retome o trabalho a partir deste checkpoint.
Consulte o estado completo e continue de onde parou.
============================================================
EOF
}

# ============================================================================
# BASIC MEMORY INTEGRATION (Fase 1: Schema Mapping)
# ============================================================================

# Converte um checkpoint JSON para formato de nota do Basic Memory (Markdown)
# Uso: ckpt_to_basic_memory_note <checkpoint_file>
# Retorna: Conteudo da nota em Markdown
ckpt_to_basic_memory_note() {
    local ckpt_file="$1"
    
    if [ ! -f "$ckpt_file" ]; then
        return 1
    fi
    
    # Extrai dados do checkpoint usando jq
    local ckpt_id trigger desc created project version sprint_id sprint_name task status
    local completed total progress intent intent_desc stack
    
    if command -v jq >/dev/null 2>&1; then
        ckpt_id=$(jq -r '.checkpoint_id // "unknown"' "$ckpt_file")
        trigger=$(jq -r '.trigger // "unknown"' "$ckpt_file")
        desc=$(jq -r '.description // ""' "$ckpt_file")
        created=$(jq -r '.created_at // "unknown"' "$ckpt_file")
        project=$(jq -r '.state_snapshot.session.project_name // ""' "$ckpt_file")
        [ -z "$project" ] || [ "$project" = "null" ] && project=$(basename "$PWD")
        version=$(jq -r '.state_snapshot.version // ""' "$ckpt_file")
        [ -z "$version" ] || [ "$version" = "null" ] && version=$([ -f "VERSION" ] && tr -d '[:space:]' < VERSION || echo "unknown")
        stack=$(jq -r '.state_snapshot.session.stack // "generic"' "$ckpt_file")
        sprint_id=$(jq -r '.sprint_snapshot.sprint_id // "unknown"' "$ckpt_file")
        sprint_name=$(jq -r '.sprint_snapshot.sprint_name // ""' "$ckpt_file")
        [ -z "$sprint_name" ] || [ "$sprint_name" = "null" ] && sprint_name="lifecycle-transition"
        task=$(jq -r '.sprint_snapshot.current_task // "none"' "$ckpt_file")
        status=$(jq -r '.sprint_snapshot.status // "unknown"' "$ckpt_file")
        completed=$(jq -r '.sprint_snapshot.overall_progress.completed // 0' "$ckpt_file")
        total=$(jq -r '.sprint_snapshot.overall_progress.total_tasks // 0' "$ckpt_file")
        intent=$(jq -r '.state_snapshot.active_intent // "none"' "$ckpt_file")
        intent_desc=$(jq -r '.state_snapshot.intent_description // ""' "$ckpt_file")
    else
        # Fallback: retorna mensagem de erro
        echo "Erro: jq necessario para converter checkpoint"
        return 1
    fi
    
    # Calcula progresso percentual
    if [ "$total" -gt 0 ]; then
        progress=$(( (completed * 100) / total ))
    else
        progress=0
    fi
    
    # Extrai data formatada
    local date_formatted
    date_formatted=$(echo "$created" | cut -d'T' -f1)
    
    # Gera tags
    local tags="#checkpoint"
    if [ "$sprint_id" != "unknown" ]; then
        tags="$tags #$sprint_id"
    fi
    if [ "$task" != "none" ]; then
        local task_tag
        task_tag=$(echo "$task" | sed 's/task-//' | cut -d'-' -f1)
        tags="$tags #$task_tag"
    fi
    if [ "$trigger" != "unknown" ]; then
        tags="$tags #$trigger"
    fi
    
    # Contexto cognitivo (Sprint 5 - Feature 5.1)
    local cot hypothesis mental_model observations
    cot=$(jq -r '.cognitive_context.chain_of_thought // ""' "$ckpt_file")
    hypothesis=$(jq -r '.cognitive_context.current_hypothesis // ""' "$ckpt_file")
    mental_model=$(jq -r '.cognitive_context.mental_model // ""' "$ckpt_file")
    observations=$(jq -r '.cognitive_context.observations // ""' "$ckpt_file")

    # Gera nota em Markdown
    cat << EOF
---
checkpoint_id: $ckpt_id
trigger: $trigger
sprint: $sprint_id
task: $task
created_at: $created
project: $project
version: $version
---

# Checkpoint: $ckpt_id

**Trigger**: $trigger
**Sprint**: $sprint_name ($sprint_id)
**Task**: $task
**Data**: $date_formatted
**Tags**: $tags

## Resumo
$desc

## Estado do Sistema
- **Projeto**: $project
- **Versão**: $version
- **Stack**: $stack
- **Status**: $status

## Contexto Técnico

### Intent Ativo
- **Tipo**: $intent
- **Descrição**: $intent_desc

### Sprint Atual
- **ID**: $sprint_id
- **Nome**: $sprint_name
- **Status**: $status
- **Task em Execução**: $task
EOF

    # Secao cognitiva - so exibe se ha conteudo preenchido
    if [ -n "$cot" ] || [ -n "$hypothesis" ] || [ -n "$mental_model" ]; then
        echo ""
        echo "## Contexto Cognitivo"
        [ -n "$cot" ] && echo "- **Raciocinio**: $cot"
        [ -n "$hypothesis" ] && echo "- **Hipotese**: $hypothesis"
        [ -n "$mental_model" ] && echo "- **Modelo Mental**: $mental_model"
        [ -n "$observations" ] && echo "- **Observacoes**: $observations"
    fi

    cat << EOF

## Progresso
- **Completado**: $completed/$total tasks
- **Percentual**: $progress%

## Artefatos
- Checkpoint: \`$ckpt_id\`
- Arquivo: \`$ckpt_file\`

---
*Gerado automaticamente por AI Dev Superpowers v$version*
EOF
}

# ============================================================================
# SYNC GRACEFUL COM BASIC MEMORY (Sprint 3: basic-memory-graceful-integration)
# ============================================================================

# Sincroniza um checkpoint para o Basic Memory de forma graceful.
# Se BM disponível: usa mcp__basic-memory__write_note.
# Se indisponível: fallback para arquivo local em .aidev/memory/kb/checkpoints/.
# Nunca bloqueia o fluxo principal — sempre retorna 0.
#
# Uso: ckpt_sync_to_basic_memory <checkpoint_file>
ckpt_sync_to_basic_memory() {
    local ckpt_file="$1"

    # Arquivo inexistente: encerra silenciosamente
    [ -f "$ckpt_file" ] || return 0

    # Carrega detecção unificada se disponível
    local _lib_dir
    _lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.aidev/lib" 2>/dev/null && pwd)" || true
    if [ -f "$_lib_dir/mcp-detect.sh" ] && ! type mcp_detect_basic_memory &>/dev/null; then
        source "$_lib_dir/mcp-detect.sh" 2>/dev/null || true
    fi

    # Gera conteúdo da nota
    local note_content ckpt_id
    ckpt_id=$(basename "$ckpt_file" .json)
    if type ckpt_to_basic_memory_note &>/dev/null; then
        note_content=$(ckpt_to_basic_memory_note "$ckpt_file" 2>/dev/null) || true
    fi
    [ -z "$note_content" ] && note_content=$(cat "$ckpt_file" 2>/dev/null) || true

    # Caminho do fallback local
    local fallback_dir=".aidev/memory/kb/checkpoints"

    # Tenta via MCP se disponível
    if type mcp_detect_basic_memory &>/dev/null && mcp_detect_basic_memory 2>/dev/null; then
        if type mcp__basic-memory__write_note &>/dev/null; then
            mcp__basic-memory__write_note \
                title="Checkpoint: $ckpt_id" \
                content="$note_content" \
                directory="checkpoints" 2>/dev/null || {
                # Falha no MCP: fallback local sem propagar erro
                _ckpt_sync_local_fallback "$ckpt_id" "$note_content" "$fallback_dir"
            }
            return 0
        fi
    fi

    # Fallback local
    _ckpt_sync_local_fallback "$ckpt_id" "$note_content" "$fallback_dir"
    return 0
}

# Salva nota de checkpoint localmente em .aidev/memory/kb/checkpoints/
_ckpt_sync_local_fallback() {
    local ckpt_id="$1"
    local content="$2"
    local dest_dir="${3:-.aidev/memory/kb/checkpoints}"

    mkdir -p "$dest_dir" 2>/dev/null || return 0
    printf '%s\n' "$content" > "$dest_dir/${ckpt_id}.md" 2>/dev/null || true
}

# ============================================================================
# CONFIGURACAO DO SYNC COM BASIC MEMORY
# ============================================================================

# Habilita/desabilita sincronizacao automatica com Basic Memory
# Uso: ckpt_config_sync <true|false>
ckpt_config_sync() {
    local enable="${1:-true}"
    
    if [ "$enable" = "true" ]; then
        export CKPT_SYNC_BASIC_MEMORY="true"
        echo "✅ Sync com Basic Memory HABILITADO"
        echo "   Checkpoints serao sincronizados automaticamente"
    else
        export CKPT_SYNC_BASIC_MEMORY="false"
        echo "⏸️  Sync com Basic Memory DESABILITADO"
        echo "   Checkpoints serao salvos apenas no filesystem"
    fi
}

# Verifica status da sincronizacao
ckpt_sync_status() {
    if [ "${CKPT_SYNC_BASIC_MEMORY:-false}" = "true" ]; then
        echo "Status: ✅ HABILITADO"
        
        # Verifica se Basic Memory MCP está disponivel
        if type mcp__basic-memory__write_note &>/dev/null; then
            echo "MCP Basic Memory: ✅ Disponivel"
        else
            echo "MCP Basic Memory: ❌ Indisponivel (usando fallback filesystem)"
        fi
    else
        echo "Status: ⏸️  DESABILITADO"
        echo "Use: ckpt_config_sync true  # para habilitar"
    fi
}

# Sincroniza checkpoints existentes para Basic Memory (migracao)
# Uso: ckpt_sync_all <install_path>
ckpt_sync_all() {
    local install_path="${1:-${CLI_INSTALL_PATH:-.}}"
    local ckpt_dir="$install_path/.aidev/state/sprints/current/checkpoints"
    
    if [ ! -d "$ckpt_dir" ]; then
        echo "❌ Diretorio de checkpoints nao encontrado"
        return 1
    fi
    
    local files
    files=$(ls "$ckpt_dir"/ckpt-*.json 2>/dev/null) || true
    
    if [ -z "$files" ]; then
        echo "ℹ️  Nenhum checkpoint para sincronizar"
        return 0
    fi
    
    if ! type mcp__basic-memory__write_note &>/dev/null; then
        echo "❌ MCP Basic Memory nao disponivel"
        return 1
    fi
    
    local count=0
    
    echo "🔄 Sincronizando checkpoints para Basic Memory..."
    
    for f in $files; do
        if [ -f "$f" ]; then
            local note_content
            note_content=$(ckpt_to_basic_memory_note "$f" 2>/dev/null) || continue
            
            local ckpt_id
            ckpt_id=$(basename "$f" .json)
            
            mcp__basic-memory__write_note \
                title="Checkpoint: $ckpt_id" \
                content="$note_content" \
                directory="checkpoints" 2>/dev/null && { ((count++)) || true; }
        fi
    done
    
    echo "✅ $count checkpoints sincronizados"
}

# ============================================================================
# FASE 3: BUSCA SEMANTICA (Placeholder para implementacao futura)
# ============================================================================

# Busca checkpoints no Basic Memory
# Uso: ckpt_search_basic_memory <query>
ckpt_search_basic_memory() {
    local query="$1"
    
    if [ -z "$query" ]; then
        echo "Uso: ckpt_search_basic_memory <termo de busca>"
        return 1
    fi
    
    if ! type mcp__basic-memory__search_notes &>/dev/null; then
        echo "❌ MCP Basic Memory nao disponivel"
        return 1
    fi
    
    echo "🔍 Buscando checkpoints: $query"
    mcp__basic-memory__search_notes \
        query="checkpoint $query" \
        directory="checkpoints" 2>/dev/null || echo "Nenhum resultado encontrado"
}
