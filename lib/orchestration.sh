#!/bin/bash

# ============================================================================
# AI Dev Superpowers V3 - Orchestration Module
# ============================================================================
# Sistema de orquestracao inteligente: estado de skills, protocolo de agentes,
# sistema de confianca e validacao
#
# Uso: source lib/orchestration.sh
# Dependencias: lib/core.sh, lib/file-ops.sh, lib/metrics.sh, lib/kb.sh
source lib/metrics.sh

# Carrega modulo de Knowledge Base para hooks automaticos de catalogacao
if [ -f "${CLI_INSTALL_PATH:-.}/lib/kb.sh" ]; then
    source "${CLI_INSTALL_PATH:-.}/lib/kb.sh"
elif [ -f "lib/kb.sh" ]; then
    source lib/kb.sh
fi
source lib/lessons.sh
# ============================================================================

# ============================================================================
# SKILL STATE MACHINE
# ============================================================================
# Cada skill tem estados: idle -> active -> step_N -> completed/failed
# Checkpoints permitem retomar de onde parou

# Estrutura do estado de skill em .aidev/state/skills.json:
# {
#   "active_skill": "brainstorming",
#   "skill_states": {
#     "brainstorming": {
#       "status": "active",
#       "current_step": 2,
#       "total_steps": 4,
#       "started_at": "...",
#       "checkpoints": [...],
#       "artifacts": [...]
#     }
#   }
# }

# Inicializa estado de uma skill
# Uso: skill_init "brainstorming"
skill_init() {
    local skill_name="$1"
    local install_path="${CLI_INSTALL_PATH:-.}"
    local skills_file="$install_path/.aidev/state/skills.json"

    ensure_dir "$(dirname "$skills_file")"

    # Carrega ou inicializa arquivo
    if [ ! -f "$skills_file" ]; then
        echo '{"active_skill": null, "skill_states": {}}' > "$skills_file"
    fi

    local timestamp=$(date -Iseconds)
    local timer_id=""
    if command -v metrics_start_timer >/dev/null 2>&1; then
        timer_id=$(metrics_start_timer)
        metrics_track_event "skill_start" "$skill_name" 0 "started" "{}"
    fi

    if command -v jq >/dev/null 2>&1; then
        local tmp_file=$(mktemp)
        jq --arg skill "$skill_name" --arg ts "$timestamp" --arg tid "$timer_id" '
            .active_skill = $skill |
            .skill_states[$skill] = {
                "status": "active",
                "current_step": 0,
                "total_steps": 0,
                "started_at": $ts,
                "metrics_id": $tid,
                "checkpoints": [],
                "artifacts": []
            }
        ' "$skills_file" > "$tmp_file" && mv "$tmp_file" "$skills_file"
    fi

    print_debug "Skill '$skill_name' inicializada"
}

# Define o numero total de steps de uma skill
# Uso: skill_set_steps "brainstorming" 4
skill_set_steps() {
    local skill_name="$1"
    local total_steps="$2"
    local install_path="${CLI_INSTALL_PATH:-.}"
    local skills_file="$install_path/.aidev/state/skills.json"

    if command -v jq >/dev/null 2>&1 && [ -f "$skills_file" ]; then
        local tmp_file=$(mktemp)
        jq --arg skill "$skill_name" --argjson steps "$total_steps" '
            .skill_states[$skill].total_steps = $steps
        ' "$skills_file" > "$tmp_file" && mv "$tmp_file" "$skills_file"
    fi
}

# Avanca para o proximo step de uma skill
# Uso: skill_advance "brainstorming" "Explorar alternativas"
skill_advance() {
    local skill_name="$1"
    local step_description="${2:-}"
    local install_path="${CLI_INSTALL_PATH:-.}"
    local skills_file="$install_path/.aidev/state/skills.json"

    if command -v jq >/dev/null 2>&1 && [ -f "$skills_file" ]; then
        local current_step=$(jq -r --arg skill "$skill_name" '.skill_states[$skill].current_step // 0' "$skills_file")
        local next_step=$((current_step + 1))
        local timestamp=$(date -Iseconds)

        local tmp_file=$(mktemp)
        jq --arg skill "$skill_name" --argjson step "$next_step" --arg desc "$step_description" --arg ts "$timestamp" '
            .skill_states[$skill].current_step = $step |
            .skill_states[$skill].checkpoints += [{
                "step": $step,
                "description": $desc,
                "timestamp": $ts,
                "validated": false
            }]
        ' "$skills_file" > "$tmp_file" && mv "$tmp_file" "$skills_file"

        print_debug "Skill '$skill_name' avancou para step $next_step: $step_description"
    fi
}

# Valida o checkpoint atual (marca como concluido)
# Uso: skill_validate_checkpoint "brainstorming"
skill_validate_checkpoint() {
    local skill_name="$1"
    local install_path="${CLI_INSTALL_PATH:-.}"
    local skills_file="$install_path/.aidev/state/skills.json"

    if command -v jq >/dev/null 2>&1 && [ -f "$skills_file" ]; then
        local tmp_file=$(mktemp)
        jq --arg skill "$skill_name" '
            .skill_states[$skill].checkpoints[-1].validated = true
        ' "$skills_file" > "$tmp_file" && mv "$tmp_file" "$skills_file"
    fi
}

# Registra um artefato produzido pela skill
# Uso: skill_add_artifact "brainstorming" "docs/plans/2024-01-01-design.md" "design"
skill_add_artifact() {
    local skill_name="$1"
    local artifact_path="$2"
    local artifact_type="${3:-document}"
    local install_path="${CLI_INSTALL_PATH:-.}"
    local skills_file="$install_path/.aidev/state/skills.json"

    if command -v jq >/dev/null 2>&1 && [ -f "$skills_file" ]; then
        local timestamp=$(date -Iseconds)
        local tmp_file=$(mktemp)
        jq --arg skill "$skill_name" --arg path "$artifact_path" --arg type "$artifact_type" --arg ts "$timestamp" '
            .skill_states[$skill].artifacts += [{
                "path": $path,
                "type": $type,
                "created_at": $ts
            }]
        ' "$skills_file" > "$tmp_file" && mv "$tmp_file" "$skills_file"

        print_debug "Artefato registrado: $artifact_path"
    fi
}

# Marca skill como completa
# Uso: skill_complete "brainstorming"
skill_complete() {
    local skill_name="$1"
    local install_path="${CLI_INSTALL_PATH:-.}"
    local skills_file="$install_path/.aidev/state/skills.json"

    if command -v jq >/dev/null 2>&1 && [ -f "$skills_file" ]; then
        local timestamp=$(date -Iseconds)
        
        # Recupera metrics_id antes de limpar ou atualizar
        local metrics_id=$(jq -r --arg skill "$skill_name" '.skill_states[$skill].metrics_id // empty' "$skills_file")
        if [ -n "$metrics_id" ] && command -v metrics_stop_timer >/dev/null 2>&1; then
            metrics_stop_timer "$metrics_id" "skill_execution" "$skill_name" "completed"
        fi

        local tmp_file=$(mktemp)
        jq --arg skill "$skill_name" --arg ts "$timestamp" '
            .skill_states[$skill].status = "completed" |
            .skill_states[$skill].completed_at = $ts |
            .active_skill = null
        ' "$skills_file" > "$tmp_file" && mv "$tmp_file" "$skills_file"

        # Hook automatico para KB: cataloga licao quando skill de resolucao completa
        if [[ "$skill_name" == "systematic-debugging" ]] ||
           [[ "$skill_name" == "learned-lesson" ]]; then
            if command -v _kb_on_resolution_complete >/dev/null 2>&1; then
                _kb_on_resolution_complete "$skill_name"
            fi
        fi

        print_success "Skill '$skill_name' concluida!"

        # Gatilho: Sugerir Learned Lesson apos bug fix ou tarefas complexas
        if [[ "$skill_name" == "systematic-debugging" ]] || [[ "$skill_name" == "test-driven-development" ]]; then
            print_warning "Detectada conclusao de tarefa tecnica. Deseja registrar uma licao aprendida ou padrao de sucesso?"
            print_info "Trigger: skill_init 'learned-lesson'"
        fi
    fi
}

# Marca skill como falha
# Uso: skill_fail "brainstorming" "Motivo da falha"
skill_fail() {
    local skill_name="$1"
    local reason="${2:-Falha nao especificada}"
    local install_path="${CLI_INSTALL_PATH:-.}"
    local skills_file="$install_path/.aidev/state/skills.json"

    if command -v jq >/dev/null 2>&1 && [ -f "$skills_file" ]; then
        local timestamp=$(date -Iseconds)

        # Recupera metrics_id
        local metrics_id=$(jq -r --arg skill "$skill_name" '.skill_states[$skill].metrics_id // empty' "$skills_file")
        if [ -n "$metrics_id" ] && command -v metrics_stop_timer >/dev/null 2>&1; then
            metrics_stop_timer "$metrics_id" "skill_execution" "$skill_name" "failed" "{\"reason\": \"$reason\"}"
        fi

        local tmp_file=$(mktemp)
        jq --arg skill "$skill_name" --arg ts "$timestamp" --arg reason "$reason" '
            .skill_states[$skill].status = "failed" |
            .skill_states[$skill].failed_at = $ts |
            .skill_states[$skill].failure_reason = $reason |
            .active_skill = null
        ' "$skills_file" > "$tmp_file" && mv "$tmp_file" "$skills_file"

        # Hook automatico para KB: registra falha para correlacao futura
        if command -v _kb_on_failure >/dev/null 2>&1; then
            _kb_on_failure "$skill_name" "$reason"
        fi

        print_error "Skill '$skill_name' falhou: $reason"
    fi
}

# Obtem status da skill ativa
# Uso: status=$(skill_get_status)
skill_get_status() {
    local install_path="${CLI_INSTALL_PATH:-.}"
    local skills_file="$install_path/.aidev/state/skills.json"

    if command -v jq >/dev/null 2>&1 && [ -f "$skills_file" ]; then
        jq -r '.active_skill // "none"' "$skills_file"
    else
        echo "none"
    fi
}

# Obtem progresso da skill (step atual / total)
# Uso: progress=$(skill_get_progress "brainstorming")
skill_get_progress() {
    local skill_name="$1"
    local install_path="${CLI_INSTALL_PATH:-.}"
    local skills_file="$install_path/.aidev/state/skills.json"

    if command -v jq >/dev/null 2>&1 && [ -f "$skills_file" ]; then
        local current=$(jq -r --arg skill "$skill_name" '.skill_states[$skill].current_step // 0' "$skills_file")
        local total=$(jq -r --arg skill "$skill_name" '.skill_states[$skill].total_steps // 0' "$skills_file")
        echo "$current/$total"
    else
        echo "0/0"
    fi
}

# ============================================================================
# AGENT PROTOCOL
# ============================================================================
# Protocolo de comunicacao entre agentes via artefatos e handoffs

# Estrutura do estado de agentes em .aidev/state/agents.json:
# {
#   "active_agent": "architect",
#   "handoff_queue": [...],
#   "agent_states": {...}
# }

# Inicializa um agente
# Uso: agent_activate "architect" "Projetar arquitetura do modulo X"
agent_activate() {
    local agent_name="$1"
    local task_description="${2:-}"
    local install_path="${CLI_INSTALL_PATH:-.}"
    local agents_file="$install_path/.aidev/state/agents.json"

    ensure_dir "$(dirname "$agents_file")"

    if [ ! -f "$agents_file" ]; then
        echo '{"active_agent": null, "handoff_queue": [], "agent_states": {}}' > "$agents_file"
    fi

    local timestamp=$(date -Iseconds)

    if command -v jq >/dev/null 2>&1; then
        local tmp_file=$(mktemp)
        jq --arg agent "$agent_name" --arg task "$task_description" --arg ts "$timestamp" '
            .active_agent = $agent |
            .agent_states[$agent] = {
                "status": "active",
                "task": $task,
                "started_at": $ts,
                "outputs": [],
                "validations": []
            }
        ' "$agents_file" > "$tmp_file" && mv "$tmp_file" "$agents_file"
    fi

    if command -v metrics_track_event >/dev/null 2>&1; then
        metrics_track_event "agent_activate" "$agent_name" 0 "active" "{\"task\": \"$task_description\"}"
    fi

    print_info "Agente '$agent_name' ativado: $task_description"
}

# Registra output de um agente
# Uso: agent_output "architect" "docs/design.md" "design_document"
agent_output() {
    local agent_name="$1"
    local output_path="$2"
    local output_type="${3:-artifact}"
    local install_path="${CLI_INSTALL_PATH:-.}"
    local agents_file="$install_path/.aidev/state/agents.json"

    if command -v jq >/dev/null 2>&1 && [ -f "$agents_file" ]; then
        local timestamp=$(date -Iseconds)
        local tmp_file=$(mktemp)
        jq --arg agent "$agent_name" --arg path "$output_path" --arg type "$output_type" --arg ts "$timestamp" '
            .agent_states[$agent].outputs += [{
                "path": $path,
                "type": $type,
                "created_at": $ts
            }]
        ' "$agents_file" > "$tmp_file" && mv "$tmp_file" "$agents_file"
    fi
}

# Handoff: transfere trabalho de um agente para outro
# Uso: agent_handoff "architect" "backend" "Implementar API conforme design" "docs/design.md"
agent_handoff() {
    local from_agent="$1"
    local to_agent="$2"
    local task_description="$3"
    local artifact_path="${4:-}"
    local install_path="${CLI_INSTALL_PATH:-.}"
    local agents_file="$install_path/.aidev/state/agents.json"

    if command -v jq >/dev/null 2>&1 && [ -f "$agents_file" ]; then
        local timestamp=$(date -Iseconds)
        local tmp_file=$(mktemp)
        jq --arg from "$from_agent" --arg to "$to_agent" --arg task "$task_description" --arg artifact "$artifact_path" --arg ts "$timestamp" '
            .agent_states[$from].status = "completed" |
            .agent_states[$from].completed_at = $ts |
            .handoff_queue += [{
                "from": $from,
                "to": $to,
                "task": $task,
                "artifact": $artifact,
                "timestamp": $ts,
                "processed": false
            }] |
            .active_agent = $to
        ' "$agents_file" > "$tmp_file" && mv "$tmp_file" "$agents_file"

        print_info "Handoff: $from_agent -> $to_agent"
        print_info "Tarefa: $task_description"
    fi
}

# Processa proximo handoff da fila
# Uso: next_task=$(agent_process_handoff)
agent_process_handoff() {
    local install_path="${CLI_INSTALL_PATH:-.}"
    local agents_file="$install_path/.aidev/state/agents.json"

    if command -v jq >/dev/null 2>&1 && [ -f "$agents_file" ]; then
        # Pega o primeiro handoff nao processado
        local handoff=$(jq -r '.handoff_queue | map(select(.processed == false)) | .[0] // empty' "$agents_file")

        if [ -n "$handoff" ] && [ "$handoff" != "null" ]; then
            local to_agent=$(echo "$handoff" | jq -r '.to')
            local task=$(echo "$handoff" | jq -r '.task')
            local artifact=$(echo "$handoff" | jq -r '.artifact')

            # Marca como processado
            local tmp_file=$(mktemp)
            jq '(.handoff_queue | map(select(.processed == false)) | .[0]).processed = true' "$agents_file" > "$tmp_file" && mv "$tmp_file" "$agents_file"

            # Ativa o agente de destino
            agent_activate "$to_agent" "$task"

            echo "$to_agent|$task|$artifact"
        fi
    fi
}

# ============================================================================
# CONFIDENCE SYSTEM
# ============================================================================
# Sistema de confianca para decisoes autonomas vs consulta ao usuario

# Niveis de confianca:
# - high (0.8-1.0): Executa autonomamente
# - medium (0.5-0.79): Executa com log detalhado
# - low (0.3-0.49): Pede confirmacao
# - very_low (0-0.29): Solicita mais contexto

# Registra uma decisao com nivel de confianca
# Uso: confidence_log "Usar React Query para cache" 0.85 "high"
confidence_log() {
    local decision="$1"
    local score="$2"
    local level="${3:-}"
    local install_path="${CLI_INSTALL_PATH:-.}"
    local confidence_file="$install_path/.aidev/state/confidence.json"

    ensure_dir "$(dirname "$confidence_file")"

    if [ ! -f "$confidence_file" ]; then
        echo '{"decisions": [], "stats": {"high": 0, "medium": 0, "low": 0, "very_low": 0}}' > "$confidence_file"
    fi

    # Determina nivel se nao fornecido
    if [ -z "$level" ]; then
        if (( $(echo "$score >= 0.8" | bc -l) )); then
            level="high"
        elif (( $(echo "$score >= 0.5" | bc -l) )); then
            level="medium"
        elif (( $(echo "$score >= 0.3" | bc -l) )); then
            level="low"
        else
            level="very_low"
        fi
    fi

    local timestamp=$(date -Iseconds)

    if command -v jq >/dev/null 2>&1; then
        local tmp_file=$(mktemp)
        jq --arg dec "$decision" --arg score "$score" --arg level "$level" --arg ts "$timestamp" '
            .decisions += [{
                "decision": $dec,
                "score": ($score | tonumber),
                "level": $level,
                "timestamp": $ts
            }] |
            .stats[$level] += 1
        ' "$confidence_file" > "$tmp_file" && mv "$tmp_file" "$confidence_file"
    fi
}

# Tenta executar um comando com recuperacao automatica
# Uso: try_with_recovery "npm install" "npm cache clean --force"
try_with_recovery() {
    local command="$1"
    local recovery_command="${2:-aidev doctor --fix}"
    local max_attempts="${3:-2}"
    local attempt=1

    while [ $attempt -le $max_attempts ]; do
        print_step "Tentativa $attempt/$max_attempts: $command"
        
        if bash -c "$command"; then
            return 0
        fi
        
        print_warning "Comando falhou. Tentando recuperacao..."
        
        # Executa comando de recuperacao
        if [ -n "$recovery_command" ]; then
            print_info "Executando recuperacao: $recovery_command"
            bash -c "$recovery_command"
        fi
        
        ((attempt++)) || true
    done
    
    print_error "Falha apos $max_attempts tentativas: $command"
    return 1
}

# Verifica se deve pedir confirmacao baseado na confianca
# Uso: if confidence_needs_confirmation 0.4; then ask_user; fi
confidence_needs_confirmation() {
    local score="$1"

    if (( $(echo "$score < 0.5" | bc -l 2>/dev/null || echo "1") )); then
        return 0  # Precisa confirmacao
    fi
    return 1  # Nao precisa
}

# ============================================================================
# VALIDATION SYSTEM
# ============================================================================
# Sistema de validacao pre-acao para operacoes de risco

# Tipos de validacao:
# - file_exists: Verifica se arquivo existe
# - file_not_empty: Verifica se arquivo tem conteudo
# - tests_pass: Verifica se testes passam
# - no_uncommitted: Verifica se nao ha mudancas nao commitadas
# - safe_path: Verifica se path e seguro (nao e raiz, home, etc)

# Valida uma condicao antes de executar acao
# Uso: if validation_check "safe_path" "/tmp/myfile.txt"; then rm ...; fi
validation_check() {
    local validation_type="$1"
    local target="$2"

    case "$validation_type" in
        "file_exists")
            [ -f "$target" ]
            return $?
            ;;
        "dir_exists")
            [ -d "$target" ]
            return $?
            ;;
        "file_not_empty")
            [ -s "$target" ]
            return $?
            ;;
        "tests_pass")
            # Tenta rodar testes baseado na stack
            local test_cmd=""
            [ -f "package.json" ] && test_cmd="npm test"
            [ -f "composer.json" ] && test_cmd="php artisan test"
            [ -f "pytest.ini" ] || [ -f "pyproject.toml" ] && test_cmd="pytest"

            if [ -n "$test_cmd" ]; then
                $test_cmd >/dev/null 2>&1
                return $?
            fi
            return 0  # Sem testes configurados
            ;;
        "no_uncommitted")
            [ -z "$(git status --porcelain 2>/dev/null)" ]
            return $?
            ;;
        "safe_path")
            # Verifica se nao e um path perigoso
            local dangerous_paths=("/" "$HOME" "/etc" "/usr" "/var" "/bin" "/sbin")
            local resolved_path=$(realpath "$target" 2>/dev/null || echo "$target")

            for dangerous in "${dangerous_paths[@]}"; do
                if [ "$resolved_path" = "$dangerous" ]; then
                    print_error "BLOQUEADO: Operacao em path perigoso: $target"
                    return 1
                fi
            done
            return 0
            ;;
        *)
            print_warning "Tipo de validacao desconhecido: $validation_type"
            return 1
            ;;
    esac
}

# Registra uma validacao no log
# Uso: validation_log "safe_path" "/tmp/test" "passed"
validation_log() {
    local validation_type="$1"
    local target="$2"
    local result="$3"
    local install_path="${CLI_INSTALL_PATH:-.}"
    local validation_file="$install_path/.aidev/state/validations.json"

    ensure_dir "$(dirname "$validation_file")"

    if [ ! -f "$validation_file" ]; then
        echo '{"validations": []}' > "$validation_file"
    fi

    local timestamp=$(date -Iseconds)

    if command -v jq >/dev/null 2>&1; then
        local tmp_file=$(mktemp)
        jq --arg type "$validation_type" --arg target "$target" --arg result "$result" --arg ts "$timestamp" '
            .validations += [{
                "type": $type,
                "target": $target,
                "result": $result,
                "timestamp": $ts
            }]
        ' "$validation_file" > "$tmp_file" && mv "$tmp_file" "$validation_file"
    fi
}

# ============================================================================
# ORCHESTRATOR BRAIN
# ============================================================================
# Funcoes de alto nivel para orquestracao inteligente

# Classifica intent do usuario
# Uso: intent=$(orchestrator_classify_intent "quero criar uma nova feature de login")
orchestrator_classify_intent() {
    local user_input="$1"
    local input_lower=$(echo "$user_input" | tr '[:upper:]' '[:lower:]')

    # Palavras-chave para cada categoria
    if echo "$input_lower" | grep -qE "(novo|nova|criar|adicionar|feature|funcionalidade)"; then
        echo "feature_request"
    elif echo "$input_lower" | grep -qE "(bug|erro|fix|corrigir|quebrado|nao funciona)"; then
        echo "bug_fix"
    elif echo "$input_lower" | grep -qE "(refatorar|refactor|limpar|melhorar|otimizar)"; then
        echo "refactor"
    elif echo "$input_lower" | grep -qE "(analisar|analise|entender|explorar|investigar)"; then
        echo "analysis"
    elif echo "$input_lower" | grep -qE "(teste|tdd|testar|cobertura)"; then
        echo "testing"
    elif echo "$input_lower" | grep -qE "(deploy|publicar|producao|release)"; then
        echo "deployment"
    elif echo "$input_lower" | grep -qE "(seguranca|vulnerabilidade|owasp|security)"; then
        echo "security_review"
    else
        echo "general"
    fi
}

# Seleciona agentes apropriados para um intent
# Uso: agents=$(orchestrator_select_agents "feature_request")
orchestrator_select_agents() {
    local intent="$1"

    case "$intent" in
        "feature_request")
            echo "architect,backend,frontend,code-reviewer,qa"
            ;;
        "bug_fix")
            echo "qa,backend,security-guardian"
            ;;
        "refactor")
            echo "legacy-analyzer,architect,code-reviewer,qa"
            ;;
        "analysis")
            echo "legacy-analyzer,architect"
            ;;
        "testing")
            echo "qa,backend"
            ;;
        "deployment")
            echo "devops,security-guardian"
            ;;
        "security_review")
            echo "security-guardian,qa"
            ;;
        "code_review")
            echo "code-reviewer,qa,security-guardian"
            ;;
        *)
            echo "orchestrator"
            ;;
    esac
}

# Seleciona skill apropriada para um intent
# Uso: skill=$(orchestrator_select_skill "feature_request")
orchestrator_select_skill() {
    local intent="$1"

    case "$intent" in
        "feature_request")
            echo "brainstorming"
            ;;
        "bug_fix")
            echo "systematic-debugging"
            ;;
        "refactor"|"analysis")
            echo "writing-plans"
            ;;
        "testing")
            echo "test-driven-development"
            ;;
        "code_review")
            echo "code-review"
            ;;
        *)
            echo ""
            ;;
    esac
}

# Obtem licoes aprendidas relevantes
# Uso: lessons=$(orchestrator_get_lessons)
orchestrator_get_lessons() {
    local query="${1:-}"
    local lessons=$(lessons_search "$query")
    echo "$lessons"
}

# Gera contexto completo para o orchestrador
# Uso: context=$(orchestrator_get_context)
orchestrator_get_context() {
    local install_path="${CLI_INSTALL_PATH:-.}"

    local active_skill=$(skill_get_status)
    local stack=$(detect_stack "$install_path")
    local platform=$(detect_platform)
    local fase=$(get_state_value "current_fase" "1")
    local sprint=$(get_state_value "current_sprint" "0")
    local lessons=$(orchestrator_get_lessons)

    cat << EOF
{
  "project": {
    "path": "$install_path",
    "stack": "$stack",
    "platform": "$platform"
  },
  "session": {
    "fase": $fase,
    "sprint": $sprint
  },
  "orchestration": {
    "active_skill": "$active_skill",
    "skill_progress": "$(skill_get_progress "$active_skill")"
  },
  "memory": {
    "recent_lessons": $lessons
  }
}
EOF
}
