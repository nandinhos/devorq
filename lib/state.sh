#!/bin/bash

# ============================================================================
# AI Dev Superpowers V3.2 - Unified State Manager
# ============================================================================
# Sistema de estado unificado com operacoes ACID-like, checkpoints e rollback.
#
# Uso: source lib/state.sh
# Dependencias: lib/core.sh, lib/file-ops.sh
# ============================================================================

# Arquivo de estado unificado
STATE_FILE="${CLI_INSTALL_PATH:-.}/.aidev/state/unified.json"

# ============================================================================
# ESTADO UNIFICADO - Estrutura
# ============================================================================
# {
#   "version": "3.2.0",
#   "session": {
#     "id": "uuid",
#     "started_at": "ISO-8601",
#     "last_activity": "ISO-8601",
#     "project_name": "...",
#     "stack": "...",
#     "maturity": "greenfield|brownfield"
#   },
#   "active_skill": null,
#   "active_agent": null,
#   "checkpoints": {
#     "skill_name": ["step1", "step2", ...]
#   },
#   "artifacts": [
#     {"path": "...", "type": "...", "created_at": "..."}
#   ],
#   "agent_queue": [
#     {"from": "...", "to": "...", "task": "...", "artifact": "..."}
#   ],
#   "confidence_log": [
#     {"decision": "...", "score": 0.85, "level": "high", "timestamp": "..."}
#   ],
#   "rollback_stack": [
#     {"timestamp": "...", "state_snapshot": {...}}
#   ]
# }

# ============================================================================
# INICIALIZACAO
# ============================================================================

# Inicializa estado unificado
# Uso: state_init
state_init() {
    local install_path="${CLI_INSTALL_PATH:-.}"
    STATE_FILE="$install_path/.aidev/state/unified.json"
    
    ensure_dir "$(dirname "$STATE_FILE")"
    
    if [ ! -f "$STATE_FILE" ]; then
        local session_id=$(uuidgen 2>/dev/null || echo "session-$(date +%s)")
        local timestamp=$(date -Iseconds)
        local project_name=$(detect_project_name "$install_path" 2>/dev/null || basename "$install_path")
        local stack=$(detect_stack "$install_path" 2>/dev/null || echo "generic")
        local maturity=$(detect_maturity "$install_path" 2>/dev/null || echo "unknown")
        
        cat > "$STATE_FILE" << EOF
{
  "version": "${AIDEV_VERSION:-unknown}",
  "session": {
    "id": "$session_id",
    "started_at": "$timestamp",
    "last_activity": "$timestamp",
    "project_name": "$project_name",
    "stack": "$stack",
    "maturity": "$maturity"
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
        print_debug "Estado unificado inicializado: $STATE_FILE"
    fi
}

# Garante que o estado existe antes de operacoes
# Uso: state_ensure
state_ensure() {
    local install_path="${CLI_INSTALL_PATH:-.}"
    STATE_FILE="$install_path/.aidev/state/unified.json"
    
    if [ ! -f "$STATE_FILE" ]; then
        state_init
    fi
}

# ============================================================================
# OPERACOES DE LEITURA
# ============================================================================

# Le um valor do estado unificado
# Uso: value=$(state_read "session.project_name")
# Suporta notacao de ponto para paths aninhados
state_read() {
    local key="$1"
    local default="${2:-}"
    
    state_ensure
    
    if command -v jq >/dev/null 2>&1; then
        local value
        value=$(jq -r ".$key // empty" "$STATE_FILE" 2>/dev/null)
        
        if [ -z "$value" ] || [ "$value" = "null" ]; then
            echo "$default"
        else
            echo "$value"
        fi
    else
        # Fallback basico para keys simples (primeiro nivel)
        local simple_key="${key%%.*}"
        grep "\"$simple_key\":" "$STATE_FILE" | sed 's/.*: "\?\([^",}]*\)"\?.*/\1/' | head -n 1
    fi
}

# Le uma secao completa como JSON
# Uso: session_json=$(state_read_section "session")
state_read_section() {
    local section="$1"
    
    state_ensure
    
    if command -v jq >/dev/null 2>&1; then
        jq ".$section" "$STATE_FILE" 2>/dev/null
    else
        echo "{}"
    fi
}

# Lista todos os checkpoints de uma skill
# Uso: checkpoints=$(state_list_checkpoints "brainstorming")
state_list_checkpoints() {
    local skill_name="$1"
    
    state_ensure
    
    if command -v jq >/dev/null 2>&1; then
        jq -r ".checkpoints[\"$skill_name\"] // []" "$STATE_FILE" 2>/dev/null
    else
        echo "[]"
    fi
}

# ============================================================================
# OPERACOES DE ESCRITA
# ============================================================================

# Escreve um valor no estado unificado
# Uso: state_write "active_skill" "brainstorming"
# Uso: state_write "session.last_activity" "$(date -Iseconds)"
state_write() {
    local key="$1"
    local value="$2"
    
    state_ensure
    
    # Atualiza last_activity automaticamente
    local timestamp=$(date -Iseconds)
    
    if command -v jq >/dev/null 2>&1; then
        local tmp_file=$(mktemp)
        
        # Determina se o valor e string, numero, booleano ou null
        local jq_value
        if [ "$value" = "null" ] || [ "$value" = "true" ] || [ "$value" = "false" ]; then
            jq_value="$value"
        elif [[ "$value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
            jq_value="$value"
        else
            jq_value="\"$value\""
        fi
        
        # Atualiza o valor e o last_activity
        jq ".$key = $jq_value | .session.last_activity = \"$timestamp\"" "$STATE_FILE" > "$tmp_file" && mv "$tmp_file" "$STATE_FILE"
        
        print_debug "Estado atualizado: $key = $value"
    else
        print_warning "jq nao encontrado. Estado nao atualizado."
    fi
}

# Adiciona um item a um array no estado
# Uso: state_append "artifacts" '{"path": "docs/design.md", "type": "design"}'
state_append() {
    local array_key="$1"
    local item_json="$2"
    
    state_ensure
    
    if command -v jq >/dev/null 2>&1; then
        local tmp_file=$(mktemp)
        local timestamp=$(date -Iseconds)
        
        jq --argjson item "$item_json" \
           --arg ts "$timestamp" \
           ".$array_key += [\$item] | .session.last_activity = \$ts" \
           "$STATE_FILE" > "$tmp_file" && mv "$tmp_file" "$STATE_FILE"
        
        print_debug "Item adicionado a $array_key"
    fi
}

# Define um checkpoint para uma skill
# Uso: state_set_checkpoint "brainstorming" "step_1" "Entender problema"
state_set_checkpoint() {
    local skill_name="$1"
    local step_id="$2"
    local description="${3:-}"
    
    state_ensure
    
    if command -v jq >/dev/null 2>&1; then
        local tmp_file=$(mktemp)
        local timestamp=$(date -Iseconds)
        
        jq --arg skill "$skill_name" \
           --arg step "$step_id" \
           --arg desc "$description" \
           --arg ts "$timestamp" \
           '.checkpoints[$skill] = ((.checkpoints[$skill] // []) + [{
               "step": $step,
               "description": $desc,
               "timestamp": $ts,
               "validated": false
           }]) | .session.last_activity = $ts' \
           "$STATE_FILE" > "$tmp_file" && mv "$tmp_file" "$STATE_FILE"
        
        print_debug "Checkpoint definido: $skill_name -> $step_id"
    fi
}

# ============================================================================
# CHECKPOINTS E ROLLBACK
# ============================================================================

# Cria um ponto de restauracao completo
# Uso: checkpoint_id=$(state_checkpoint "Antes de iniciar TDD")
state_checkpoint() {
    local description="${1:-Checkpoint automatico}"
    
    state_ensure
    
    if command -v jq >/dev/null 2>&1; then
        local tmp_file=$(mktemp)
        local timestamp=$(date -Iseconds)
        local checkpoint_id="cp-$(date +%s%N | cut -c1-13)-${RANDOM}"
        
        # Captura snapshot do estado atual (exceto rollback_stack para evitar recursao)
        local snapshot=$(jq 'del(.rollback_stack)' "$STATE_FILE")
        
        # Adiciona ao rollback_stack
        jq --arg id "$checkpoint_id" \
           --arg desc "$description" \
           --arg ts "$timestamp" \
           --argjson snapshot "$snapshot" \
           '.rollback_stack = ([{
               "id": $id,
               "description": $desc,
               "timestamp": $ts,
               "state_snapshot": $snapshot
           }] + (.rollback_stack // [])) | .rollback_stack = .rollback_stack[:10]' \
           "$STATE_FILE" > "$tmp_file" && mv "$tmp_file" "$STATE_FILE"
        
        print_debug "Checkpoint criado: $checkpoint_id - $description"
        echo "$checkpoint_id"
    fi
}

# Lista checkpoints disponiveis para rollback
# Uso: state_list_rollback_points
state_list_rollback_points() {
    state_ensure
    
    if command -v jq >/dev/null 2>&1; then
        jq -r '.rollback_stack[] | "\(.id)\t\(.timestamp)\t\(.description)"' "$STATE_FILE" 2>/dev/null
    fi
}

# Restaura estado para um checkpoint anterior
# Uso: state_rollback "cp-1234567890" ou state_rollback (ultimo)
state_rollback() {
    local checkpoint_id="${1:-}"
    
    state_ensure
    
    if command -v jq >/dev/null 2>&1; then
        local tmp_file=$(mktemp)
        local snapshot
        
        if [ -z "$checkpoint_id" ]; then
            # Rollback para o ultimo checkpoint
            snapshot=$(jq -r '.rollback_stack[0].state_snapshot // empty' "$STATE_FILE")
            checkpoint_id=$(jq -r '.rollback_stack[0].id // empty' "$STATE_FILE")
        else
            # Rollback para checkpoint especifico
            snapshot=$(jq -r --arg id "$checkpoint_id" \
                '[.rollback_stack[] | select(.id == $id)] | first | .state_snapshot // empty' "$STATE_FILE")
        fi
        
        if [ -z "$snapshot" ] || [ "$snapshot" = "null" ]; then
            print_error "Checkpoint nao encontrado: $checkpoint_id"
            return 1
        fi
        
        # Preserva o rollback_stack atual
        local current_rollback_stack=$(jq '.rollback_stack' "$STATE_FILE")
        
        # Restaura o snapshot e adiciona o rollback_stack
        echo "$snapshot" | jq --argjson stack "$current_rollback_stack" \
            '. + {rollback_stack: $stack}' > "$tmp_file" && mv "$tmp_file" "$STATE_FILE"
        
        print_success "Estado restaurado para checkpoint: $checkpoint_id"
        return 0
    else
        print_error "jq necessario para rollback"
        return 1
    fi
}

# ============================================================================
# VALIDACAO DE INTEGRIDADE
# ============================================================================

# Valida integridade do arquivo de estado
# Uso: if state_validate; then echo "OK"; fi
state_validate() {
    state_ensure
    
    # Verifica se arquivo existe
    if [ ! -f "$STATE_FILE" ]; then
        print_error "Arquivo de estado nao existe: $STATE_FILE"
        return 1
    fi
    
    # Verifica se e JSON valido
    if command -v jq >/dev/null 2>&1; then
        if ! jq . "$STATE_FILE" >/dev/null 2>&1; then
            print_error "Arquivo de estado corrompido (JSON invalido)"
            return 1
        fi
        
        # Verifica campos obrigatorios
        local version=$(jq -r '.version // empty' "$STATE_FILE")
        local session_id=$(jq -r '.session.id // empty' "$STATE_FILE")
        
        if [ -z "$version" ]; then
            print_warning "Campo 'version' ausente no estado"
        fi
        
        if [ -z "$session_id" ]; then
            print_warning "Campo 'session.id' ausente no estado"
        fi
        
        print_debug "Estado validado com sucesso"
        return 0
    else
        # Sem jq, apenas verifica se arquivo nao esta vazio
        if [ -s "$STATE_FILE" ]; then
            return 0
        else
            print_error "Arquivo de estado vazio"
            return 1
        fi
    fi
}

# Repara estado corrompido
# Uso: state_repair
state_repair() {
    local install_path="${CLI_INSTALL_PATH:-.}"
    STATE_FILE="$install_path/.aidev/state/unified.json"
    
    print_info "Tentando reparar estado..."
    
    # Tenta backup
    if [ -f "$STATE_FILE" ]; then
        cp "$STATE_FILE" "${STATE_FILE}.bak" 2>/dev/null || true
        print_debug "Backup criado: ${STATE_FILE}.bak"
    fi
    
    # Reinicializa
    rm -f "$STATE_FILE"
    state_init
    
    print_success "Estado reinicializado"
}

# ============================================================================
# FUNCOES DE CONVENIENCIA
# ============================================================================

# Registra confianca de uma decisao
# Uso: state_log_confidence "Usar React Query" 0.85 "high"
state_log_confidence() {
    local decision="$1"
    local score="$2"
    local level="${3:-}"
    
    # Determina nivel se nao fornecido
    if [ -z "$level" ]; then
        if (( $(echo "$score >= 0.8" | bc -l 2>/dev/null || echo "0") )); then
            level="high"
        elif (( $(echo "$score >= 0.5" | bc -l 2>/dev/null || echo "0") )); then
            level="medium"
        elif (( $(echo "$score >= 0.3" | bc -l 2>/dev/null || echo "0") )); then
            level="low"
        else
            level="very_low"
        fi
    fi
    
    local timestamp=$(date -Iseconds)
    local item="{\"decision\": \"$decision\", \"score\": $score, \"level\": \"$level\", \"timestamp\": \"$timestamp\"}"
    
    state_append "confidence_log" "$item"
}

# Adiciona agente a fila de handoff
# Uso: state_queue_handoff "architect" "backend" "Implementar API" "docs/design.md"
state_queue_handoff() {
    local from_agent="$1"
    local to_agent="$2"
    local task="$3"
    local artifact="${4:-}"
    
    local timestamp=$(date -Iseconds)
    local item="{\"from\": \"$from_agent\", \"to\": \"$to_agent\", \"task\": \"$task\", \"artifact\": \"$artifact\", \"timestamp\": \"$timestamp\", \"processed\": false}"
    
    state_append "agent_queue" "$item"
    state_write "active_agent" "$to_agent"
    
    print_info "Handoff enfileirado: $from_agent -> $to_agent"
}

# Registra artefato produzido
# Uso: state_add_artifact "docs/design.md" "design" "brainstorming"
state_add_artifact() {
    local path="$1"
    local type="${2:-document}"
    local source="${3:-unknown}"
    
    local timestamp=$(date -Iseconds)
    local item="{\"path\": \"$path\", \"type\": \"$type\", \"source\": \"$source\", \"created_at\": \"$timestamp\"}"
    
    state_append "artifacts" "$item"
}

# Ativa uma skill
# Uso: state_activate_skill "brainstorming"
state_activate_skill() {
    local skill_name="$1"
    
    state_checkpoint "Antes de iniciar skill: $skill_name"
    state_write "active_skill" "$skill_name"
    
    print_info "Skill ativada: $skill_name"
}

# Desativa skill atual
# Uso: state_deactivate_skill
state_deactivate_skill() {
    state_write "active_skill" "null"
}

# Obtem skill ativa
# Uso: skill=$(state_get_active_skill)
state_get_active_skill() {
    state_read "active_skill"
}

# Obtem agente ativo
# Uso: agent=$(state_get_active_agent)
state_get_active_agent() {
    state_read "active_agent"
}

# ============================================================================
# MIGRACAO DE ESTADO LEGADO
# ============================================================================

# Migra estado de arquivos separados para unificado
# Uso: state_migrate_legacy
state_migrate_legacy() {
    local install_path="${CLI_INSTALL_PATH:-.}"
    local state_dir="$install_path/.aidev/state"
    
    state_init
    
    # Migra session.json
    if [ -f "$state_dir/session.json" ]; then
        if command -v jq >/dev/null 2>&1; then
            local session_data=$(cat "$state_dir/session.json")
            local tmp_file=$(mktemp)
            
            # Mescla dados de sessao
            jq --argjson legacy "$session_data" \
               '.session = (.session * $legacy)' \
               "$STATE_FILE" > "$tmp_file" && mv "$tmp_file" "$STATE_FILE"
            
            print_info "Migrado: session.json"
        fi
    fi
    
    # Migra skills.json
    if [ -f "$state_dir/skills.json" ]; then
        if command -v jq >/dev/null 2>&1; then
            local skills_data=$(cat "$state_dir/skills.json")
            local active=$(echo "$skills_data" | jq -r '.active_skill // empty')
            
            if [ -n "$active" ] && [ "$active" != "null" ]; then
                state_write "active_skill" "$active"
            fi
            
            print_info "Migrado: skills.json"
        fi
    fi
    
    # Migra agents.json
    if [ -f "$state_dir/agents.json" ]; then
        if command -v jq >/dev/null 2>&1; then
            local agents_data=$(cat "$state_dir/agents.json")
            local active=$(echo "$agents_data" | jq -r '.active_agent // empty')
            local queue=$(echo "$agents_data" | jq '.handoff_queue // []')
            
            if [ -n "$active" ] && [ "$active" != "null" ]; then
                state_write "active_agent" "$active"
            fi
            
            local tmp_file=$(mktemp)
            jq --argjson queue "$queue" \
               '.agent_queue = $queue' \
               "$STATE_FILE" > "$tmp_file" && mv "$tmp_file" "$STATE_FILE"
            
            print_info "Migrado: agents.json"
        fi
    fi
    
    # Migra confidence.json
    if [ -f "$state_dir/confidence.json" ]; then
        if command -v jq >/dev/null 2>&1; then
            local conf_data=$(cat "$state_dir/confidence.json")
            local decisions=$(echo "$conf_data" | jq '.decisions // []')
            
            local tmp_file=$(mktemp)
            jq --argjson decisions "$decisions" \
               '.confidence_log = $decisions' \
               "$STATE_FILE" > "$tmp_file" && mv "$tmp_file" "$STATE_FILE"
            
            print_info "Migrado: confidence.json"
        fi
    fi
    
    print_success "Migracao de estado legado concluida"
}

# ============================================================================
# EXPORTACAO
# ============================================================================

# Exporta estado para formato legivel
# Uso: state_export > estado.txt
state_export() {
    state_ensure
    
    echo "=== AI Dev Superpowers - Estado Unificado ==="
    echo "Arquivo: $STATE_FILE"
    echo "Data: $(date)"
    echo ""
    
    if command -v jq >/dev/null 2>&1; then
        echo "--- Sessao ---"
        jq -r '.session | to_entries[] | "  \(.key): \(.value)"' "$STATE_FILE"
        echo ""
        
        echo "--- Skill Ativa ---"
        jq -r '.active_skill // "Nenhuma"' "$STATE_FILE"
        echo ""
        
        echo "--- Agente Ativo ---"
        jq -r '.active_agent // "Nenhum"' "$STATE_FILE"
        echo ""
        
        echo "--- Artefatos ---"
        jq -r '.artifacts[] | "  - \(.path) (\(.type))"' "$STATE_FILE" 2>/dev/null || echo "  Nenhum"
        echo ""
        
        echo "--- Fila de Handoff ---"
        jq -r '.agent_queue[] | select(.processed == false) | "  - \(.from) -> \(.to): \(.task)"' "$STATE_FILE" 2>/dev/null || echo "  Vazia"
        echo ""
        
        echo "--- Checkpoints Disponiveis ---"
        jq -r '.rollback_stack[:5][] | "  - \(.id): \(.description) (\(.timestamp))"' "$STATE_FILE" 2>/dev/null || echo "  Nenhum"
    else
        cat "$STATE_FILE"
    fi
}

# ============================================================================
# SINCRONIZACAO LEGADA
# ============================================================================

# Sincroniza session.json (legado) com unified.json
# Uso: state_sync_legacy_session
# Mantem backward compatibility com codigo que ainda le session.json
state_sync_legacy_session() {
    local install_path="${CLI_INSTALL_PATH:-.}"
    local unified_file="$install_path/.aidev/state/unified.json"
    local session_file="$install_path/.aidev/state/session.json"

    # Se unified.json nao existe, nao faz nada
    if [ ! -f "$unified_file" ]; then
        return 0
    fi

    # Verifica se jq esta disponivel
    if ! command -v jq >/dev/null 2>&1; then
        return 1
    fi

    # Extrai session de unified.json e adiciona campos extras
    local tmp_file=$(mktemp)
    local timestamp=$(date -Iseconds 2>/dev/null || date +"%Y-%m-%dT%H:%M:%S%z")

    jq '.session + {
        "agent_mode_active": true,
        "last_activation": $ts
    }' --arg ts "$timestamp" "$unified_file" > "$tmp_file"

    # Move atomicamente
    if [ -s "$tmp_file" ]; then
        mkdir -p "$(dirname "$session_file")"
        mv "$tmp_file" "$session_file"
        print_debug "session.json sincronizado com unified.json"
    else
        rm -f "$tmp_file"
        return 1
    fi
}
