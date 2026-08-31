#!/usr/bin/env bash
# lib/commands/brainstorm.sh — DEVORQ Brainstorm Command
#
# Session de brainstorming com gates de captura para gerar regras.
# Integração: devorq::rules::load() carrega rules/brainstorm.md
#
# Fluxo:
#   devorq brainstorm "<topic>"
#     → Gate: SCOPE_DEFINED    → trigger: generate scope rule
#     → Gate: ENTITIES         → trigger: generate domain rule
#     → Gate: RISKS            → trigger: log to rules/risks.md
#     → Gate: SESSION_COMPLETE  → trigger: lessons capture prompt

set -euo pipefail

# ============================================================
# devorq::cmd_brainstorm
# ============================================================

devorq::cmd_brainstorm() {
    local topic="${1:-}"
    local action="${2:-}"

    # Help
    if [[ "$topic" == "--help" || "$topic" == "-h" || "$topic" == "help" ]]; then
        devorq::brainstorm::help
        return 0
    fi

    if [ -z "$topic" ]; then
        devorq::brainstorm::usage
        return 0
    fi

    # M6: brainstorm persiste sessoes em JSON — jq e obrigatorio (fail early)
    devorq::contracts::require_jq || return 1

    case "$action" in
        start)
            devorq::brainstorm::start "$topic"
            ;;
        gate)
            devorq::brainstorm::capture_gate "${3:-}" "$topic"
            ;;
        list)
            devorq::brainstorm::list
            ;;
        help)
            devorq::brainstorm::help
            ;;
        "")
            devorq::brainstorm::interactive "$topic"
            ;;
        *)
            echo "[ERROR] Ação '$action' desconhecida."
            devorq::brainstorm::usage
            return 1
            ;;
    esac
}

# ============================================================
# Usage
# ============================================================

devorq::brainstorm::usage() {
    cat << EOF
Uso: devorq brainstorm <topic> [ação]

Tópicos de brainstorming para capturar decisões, trade-offs e padrões.

Ações:
  start <topic>     Iniciar sessão de brainstorming
  gate <name>       Capturar gate específico
  list              Listar sessões anteriores
  help              Mostrar este help

Gates disponíveis:
  SCOPE_DEFINED     Escopo do projeto definido
  ENTITIES_IDENTIFIED   Entidades de domínio identificadas
  RISKS_RAISED      Riscos levantados
  STACK_DECIDED     Stack tecnológico decidido
  SESSION_COMPLETE  Sessão finalizada

Exemplos:
  devorq brainstorm "sistema de pagamentos"
  devorq brainstorm "api rest" start
  devorq brainstorm "api rest" gate SCOPE_DEFINED
  devorq brainstorm list
EOF
}

# ============================================================
# devorq::brainstorm::interactive
# ============================================================

devorq::brainstorm::interactive() {
    local topic="$1"
    local session_id
    session_id="brainstorm_$(date '+%Y%m%d_%H%M%S')"
    local session_file="${PWD}/.devorq/state/sessions/${session_id}.json"

    mkdir -p "${PWD}/.devorq/state/sessions"

    echo ""
    echo "═══════════════════════════════════════════"
    echo "  DEVORQ Brainstorm — $topic"
    echo "═══════════════════════════════════════════"
    echo ""
    echo "Sessão: $session_id"
    echo "Data: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""

    # Inicializar sessão
    devorq::brainstorm::init_session "$session_id" "$topic" "$session_file"

    # Gate 1: SCOPE_DEFINED
    echo ""
    echo "─── Gate 1: SCOPE_DEFINED ───"
    echo "Defina o escopo do projeto/tarefa."
    echo ""
    echo -n "Escopo: "
    read -r scope
    devorq::brainstorm::capture_gate "SCOPE_DEFINED" "$topic" "$scope" "$session_file"

    # Gate 2: ENTITIES_IDENTIFIED
    echo ""
    echo "─── Gate 2: ENTITIES_IDENTIFIED ───"
    echo "Identifique as entidades de domínio principais."
    echo "(Pressione Enter para cada entidade, linha vazia para finalizar)"
    echo ""
    local entities=()
    while true; do
        echo -n "Entidade: "
        read -r entity
        if [ -z "$entity" ]; then
            break
        fi
        entities+=("$entity")
    done
    local entities_json
    entities_json=$(printf '%s\n' "${entities[@]}" | jq -R . | jq -s .)
    devorq::brainstorm::capture_gate "ENTITIES_IDENTIFIED" "$topic" "$entities_json" "$session_file"

    # Gate 3: RISKS_RAISED
    echo ""
    echo "─── Gate 3: RISKS_RAISED ───"
    echo "Levante os principais riscos identificados."
    echo "(Pressione Enter para cada risco, linha vazia para finalizar)"
    echo ""
    local risks=()
    while true; do
        echo -n "Risco: "
        read -r risk
        if [ -z "$risk" ]; then
            break
        fi
        risks+=("$risk")
    done
    local risks_json
    risks_json=$(printf '%s\n' "${risks[@]}" | jq -R . | jq -s .)
    devorq::brainstorm::capture_gate "RISKS_RAISED" "$topic" "$risks_json" "$session_file"

    # Gate 4: STACK_DECIDED
    echo ""
    echo "─── Gate 4: STACK_DECIDED ───"
    echo "Decisões de stack tecnológico."
    echo ""
    echo -n "Stack (ex: Laravel + Livewire + Tailwind): "
    read -r stack
    devorq::brainstorm::capture_gate "STACK_DECIDED" "$topic" "$stack" "$session_file"

    # Gate 5: SESSION_COMPLETE
    echo ""
    echo "─── Gate 5: SESSION_COMPLETE ───"
    devorq::brainstorm::capture_gate "SESSION_COMPLETE" "$topic" "" "$session_file"

    # Resumo
    echo ""
    echo "═══════════════════════════════════════════"
    echo "  Brainstorm Completo"
    echo "═══════════════════════════════════════════"
    echo ""
    echo "Sessão: $session_id"
    echo "Tópico: $topic"
    echo "Escopo: $scope"
    echo "Entidades: ${#entities[@]} identificadas"
    echo "Riscos: ${#risks[@]} levantados"
    echo "Stack: $stack"
    echo ""
    echo "Arquivo: $session_file"
    echo ""

    # Prompt para capturar lições
    echo "Capture lições aprendidas:"
    echo "  devorq lessons capture <title> --problem <p> --solution <s>"
    echo ""
}

# ============================================================
# devorq::brainstorm::init_session
# ============================================================

devorq::brainstorm::init_session() {
    local session_id="$1"
    local topic="$2"
    local session_file="$3"

    cat > "$session_file" << EOF
{
  "id": "$session_id",
  "topic": "$topic",
  "started_at": "$(date '+%Y-%m-%dT%H:%M:%S')",
  "gates": []
}
EOF

    devorq::info "Sessão iniciada: $session_id"
}

# ============================================================
# devorq::brainstorm::capture_gate
# ============================================================

devorq::brainstorm::capture_gate() {
    local gate_name="$1"
    local topic="$2"
    local data="${3:-}"
    local session_file="${4:-}"

    local timestamp
    timestamp="$(date '+%Y-%m-%dT%H:%M:%S')"

    # Adicionar gate ao arquivo de sessão
    if [ -n "$session_file" ] && [ -f "$session_file" ]; then
        local gate_json
        gate_json=$(jq -n \
            --arg name "$gate_name" \
            --arg timestamp "$timestamp" \
            --arg data "$data" \
            '{name: $name, timestamp: $timestamp, data: $data}')
        
        jq --argjson gate "$gate_json" \
           '.gates += [$gate]' \
           "$session_file" > "${session_file}.tmp" && \
            mv "${session_file}.tmp" "$session_file"
    fi

    # Log gate capturado
    echo "[GATE] $gate_name — $(echo "$data" | head -c 50)"

    # Ações específicas por gate
    case "$gate_name" in
        SCOPE_DEFINED)
            devorq::brainstorm::on_scope_defined "$data"
            ;;
        ENTITIES_IDENTIFIED)
            devorq::brainstorm::on_entities_identified "$data"
            ;;
        RISKS_RAISED)
            devorq::brainstorm::on_risks_raised "$data"
            ;;
        SESSION_COMPLETE)
            devorq::brainstorm::on_session_complete "$session_file"
            ;;
    esac
}

# ============================================================
# Ações pós-gate
# ============================================================

devorq::brainstorm::on_scope_defined() {
    local scope="$1"
    echo "[OK] Escopo definido: $scope"
}

devorq::brainstorm::on_entities_identified() {
    local entities="$1"
    local count
    count=$(echo "$entities" | jq 'length')
    echo "[OK] $count entidades identificadas"
}

devorq::brainstorm::on_risks_raised() {
    local risks="$1"
    local count
    count=$(echo "$risks" | jq 'length')
    echo "[OK] $count riscos levantados"

    # Se 3+ riscos, sugerir criar rules/risks.md
    if [ "$count" -ge 3 ]; then
        echo ""
        echo "[HINT] 3+ riscos identificados. Considere documentar em rules/risks.md"
    fi
}

devorq::brainstorm::on_session_complete() {
    local session_file="$1"

    # Atualizar sessão com timestamp de fim
    if [ -f "$session_file" ]; then
        jq '.ended_at = "'$(date '+%Y-%m-%dT%H:%M:%S')'"' \
           "$session_file" > "${session_file}.tmp" && \
            mv "${session_file}.tmp" "$session_file"
    fi

    echo ""
    echo "[OK] Sessão de brainstorm finalizada."
}

# ============================================================
# devorq::brainstorm::start
# ============================================================

devorq::brainstorm::start() {
    local topic="$1"
    devorq::brainstorm::interactive "$topic"
}

# ============================================================
# devorq::brainstorm::list
# ============================================================

devorq::brainstorm::list() {
    local sessions_dir="${PWD}/.devorq/state/sessions"

    if [ ! -d "$sessions_dir" ]; then
        echo "[INFO] Nenhuma sessão de brainstorm encontrada."
        return 0
    fi

    echo ""
    echo "═══════════════════════════════════════════"
    echo "  Sesses de Brainstorm"
    echo "═══════════════════════════════════════════"
    echo ""

    local count=0
    for session_file in "${sessions_dir}"/brainstorm_*.json; do
        if [ -f "$session_file" ]; then
            local id topic started_at gates_count
            id=$(jq -r '.id' "$session_file")
            topic=$(jq -r '.topic' "$session_file")
            started_at=$(jq -r '.started_at' "$session_file")
            gates_count=$(jq -r '.gates | length' "$session_file")
            
            echo "  $id"
            echo "    Tópico: $topic"
            echo "    Iniciado: $started_at"
            echo "    Gates: $gates_count"
            echo ""
            ((count++)) || true
        fi
    done

    echo "Total: $count sessão(ões)"
    echo ""
}

# ============================================================
# devorq::brainstorm::help
# ============================================================

devorq::brainstorm::help() {
    cat << EOF
## DEVORQ Brainstorm

Sessões de brainstorming para capturar decisões, trade-offs e padrões
durante o levantamento de requisitos.

### Fluxo

1. Iniciar sessão: \`devorq brainstorm <topic>\`
2. Responder gates sequencialmente
3. Ao final, capturar lições aprendidas

### Gates

| Gate | Gatilho | Ação |
|------|---------|------|
| SCOPE_DEFINED | Escopo definido | Gerar scope-guard |
| ENTITIES_IDENTIFIED | Entidades identificadas | Gerar ddd-deep-domain |
| RISKS_RAISED | Riscos levantados | Documentar em rules/risks.md |
| STACK_DECIDED | Stack decidido | Documentar em rules/stack.md |
| SESSION_COMPLETE | Sessão finalizada | Compilar lições |

### Integração com Rules

O brainstorm é regido por \`rules/brainstorm.md\`:

- Nunca adotar decisão no calor da discussão
- Regra sem exemplo concreto = não criar
- Regras recorrentes em 3+ sessões → migrar para rules/

### Exemplo

\`\`\`bash
devorq brainstorm "sistema de pedidos"
# Responda gates...
# Ao final:
devorq lessons capture "scope de pedidos" --problem "definir escopo" --solution "limitar a MVP"
\`\`\`
EOF
}