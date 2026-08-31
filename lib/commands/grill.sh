#!/usr/bin/env bash
# lib/commands/grill.sh — DEVORQ Grill Command
#
# Sessão de sparring estruturado para questionar soluções até encontrar fragilidades.
# Integração: devorq::rules::load() carrega rules/grill.md
#
# Princípio: Grill não é debate — é demolição estruturada.
#
# Fluxo:
#   devorq grill <topic>
#     → PREMISSA_QUESTIONADA → log to rules/premises.md
#     → DESIGN_FLAW_FOUND   → devorq lessons capture
#     → TRADE-OFF_ACCEPTED  → document in rules/tradeoffs.md
#     → GRILL_COMPLETE      → compile lessons → skill

set -euo pipefail

# ============================================================
# devorq::cmd_grill
# ============================================================

devorq::cmd_grill() {
    local topic="${1:-}"
    local action="${2:-}"

    # Help
    if [[ "$topic" == "--help" || "$topic" == "-h" || "$topic" == "help" ]]; then
        devorq::grill::help
        return 0
    fi

    if [ -z "$topic" ]; then
        devorq::grill::usage
        return 0
    fi

    # M6: grill persiste sessoes em JSON — jq e obrigatorio (fail early)
    devorq::contracts::require_jq || return 1

    case "$action" in
        start)
            devorq::grill::start "$topic"
            ;;
        premise)
            devorq::grill::capture_premise "${3:-}" "$topic"
            ;;
        flaw)
            devorq::grill::capture_flaw "${3:-}" "$topic"
            ;;
        tradeoff)
            devorq::grill::capture_tradeoff "${3:-}" "${4:-}" "$topic"
            ;;
        list)
            devorq::grill::list
            ;;
        help)
            devorq::grill::help
            ;;
        "")
            devorq::grill::interactive "$topic"
            ;;
        *)
            echo "[ERROR] Ação '$action' desconhecida."
            devorq::grill::usage
            return 1
            ;;
    esac
}

# ============================================================
# Usage
# ============================================================

devorq::grill::usage() {
    cat << EOF
Uso: devorq grill <topic> [ação]

Sessões de sparring (grill) para questionar soluções até encontrar fragilidades.

Princípio: Grill não é debate — é demolição estruturada.

Ações:
  start <topic>     Iniciar sessão de grill
  premise <text>    Registrar premissa questionada
  flaw <description> Registrar falha de design encontrada
  tradeoff <desc> <context>  Registrar trade-off aceito
  list              Listar sessões anteriores
  help              Mostrar este help

Gates de captura:
  PREMISSA_QUESTIONADA   Premissa questionada durante sparring
  DESIGN_FLAW_FOUND      Falha de design identificada
  TRADE-OFF_ACCEPTED     Trade-off válido aceito
  GRILL_COMPLETE         Sessão finalizada

Regras:
  - Nenhuma solução é óbvia — se parece óbvia, questionar mais fundo
  - Dados de produção > opinião — pedir números antes de aceitar
  - Três sessões de grill no mesmo ponto → criar regra permanente

Exemplos:
  devorq grill "microservices vs monolith"
  devorq grill "api rest" start
  devorq grill "api rest" premise "monolith é mais simples"
  devorq grill "auth" flaw "sessions não escalam"
  devorq grill list
EOF
}

# ============================================================
# devorq::grill::interactive
# ============================================================

devorq::grill::interactive() {
    local topic="$1"
    local session_id
    session_id="grill_$(date '+%Y%m%d_%H%M%S')"
    local session_file="${PWD}/.devorq/state/sessions/${session_id}.json"

    mkdir -p "${PWD}/.devorq/state/sessions"
    mkdir -p "${PWD}/.devorq/rules"

    echo ""
    echo "═══════════════════════════════════════════"
    echo "  DEVORQ Grill — $topic"
    echo "═══════════════════════════════════════════"
    echo ""
    echo "Sessão: $session_id"
    echo "Data: $(date '+%Y-%m-%d %H:%M:%S')"
    echo ""
    echo "Princípio: Grill não é debate — é demolição estruturada."
    echo "Três strikes = regra nova."
    echo ""

    # Inicializar sessão
    devorq::grill::init_session "$session_id" "$topic" "$session_file"

    # Contadores
    local premises=0 flaws=0 tradeoffs=0

    # Loop de sparring
    while true; do
        echo ""
        echo "───────────────────────────────────────────"
        echo "Opções:"
        echo "  1. Questionar premissa"
        echo "  2. Registrar falha de design"
        echo "  3. Registrar trade-off aceito"
        echo "  4. Finalizar sessão"
        echo ""
        echo -n "Escolha (1-4): "
        read -r choice

        case "$choice" in
            1)
                echo ""
                echo -n "Premissa questionada: "
                read -r premise
                if [ -n "$premise" ]; then
                    devorq::grill::capture_premise "$premise" "$topic" "$session_file"
                    ((premises++)) || true
                fi
                ;;
            2)
                echo ""
                echo -n "Descrição da falha de design: "
                read -r flaw
                if [ -n "$flaw" ]; then
                    devorq::grill::capture_flaw "$flaw" "$topic" "$session_file"
                    ((flaws++)) || true

                    # Capture lesson automatically
                    devorq::grill::auto_capture_lesson "$flaw" "$topic"
                fi
                ;;
            3)
                echo ""
                echo -n "Descrição do trade-off: "
                read -r tradeoff_desc
                echo -n "Contexto: "
                read -r tradeoff_context
                if [ -n "$tradeoff_desc" ]; then
                    devorq::grill::capture_tradeoff "$tradeoff_desc" "$tradeoff_context" "$topic" "$session_file"
                    ((tradeoffs++)) || true
                fi
                ;;
            4)
                break
                ;;
            *)
                echo "[WARN] Escolha inválida."
                ;;
        esac
    done

    # Gate: GRILL_COMPLETE
    devorq::grill::capture_complete "$session_id" "$session_file"

    # Resumo
    echo ""
    echo "═══════════════════════════════════════════"
    echo "  Grill Completo"
    echo "═══════════════════════════════════════════"
    echo ""
    echo "Sessão: $session_id"
    echo "Tópico: $topic"
    echo "Premissas questionadas: $premises"
    echo "Falhas de design: $flaws"
    echo "Trade-offs aceitos: $tradeoffs"
    echo ""
    echo "Arquivo: $session_file"
    echo ""

    # Check: 3+ sessões no mesmo ponto = regra nova
    if [ "$premises" -ge 3 ]; then
        echo "[HINT] 3+ premissas questionadas. Considere criar regra em rules/premises.md"
    fi

    echo ""
    echo "Após resolver falhas, capture lições:"
    echo "  devorq lessons capture <title> --problem <p> --solution <s>"
    echo ""
}

# ============================================================
# devorq::grill::init_session
# ============================================================

devorq::grill::init_session() {
    local session_id="$1"
    local topic="$2"
    local session_file="$3"

    cat > "$session_file" << EOF
{
  "id": "$session_id",
  "topic": "$topic",
  "started_at": "$(date '+%Y-%m-%dT%H:%M:%S')",
  "premises": [],
  "flaws": [],
  "tradeoffs": [],
  "strikes": 0
}
EOF

    devorq::info "Sessão iniciada: $session_id"
}

# ============================================================
# devorq::grill::capture_premise
# ============================================================

devorq::grill::capture_premise() {
    local premise="$1"
    local topic="${2:-}"
    local session_file="${3:-}"

    local timestamp
    timestamp="$(date '+%Y-%m-%dT%H:%M:%S')"

    echo ""
    echo "[PREMISSA QUESTIONADA] $premise"
    echo ""

    # Adicionar à sessão
    if [ -n "$session_file" ] && [ -f "$session_file" ]; then
        local entry
        entry=$(jq -n \
            --arg text "$premise" \
            --arg topic "$topic" \
            --arg timestamp "$timestamp" \
            '{text: $text, topic: $topic, timestamp: $timestamp}')
        
        jq --argjson entry "$entry" \
           '.premises += [$entry]' \
           "$session_file" > "${session_file}.tmp" && \
            mv "${session_file}.tmp" "$session_file"
    fi

    # Log para rules/premises.md se existir
    local premises_file="${PWD}/.devorq/rules/premises.md"
    if [ -f "$premises_file" ]; then
        echo "- **$timestamp**: $premise" >> "$premises_file"
    fi

    # Incrementar strikes
    if [ -n "$session_file" ] && [ -f "$session_file" ]; then
        jq '.strikes += 1' "$session_file" > "${session_file}.tmp" && \
            mv "${session_file}.tmp" "$session_file"
        
        local strikes
        strikes=$(jq -r '.strikes' "$session_file")
        if [ "$strikes" -ge 3 ]; then
            echo ""
            echo "[RULE TRIGGER] 3 strikes! Considere criar regra permanente."
            echo "  → rules/premises.md"
        fi
    fi
}

# ============================================================
# devorq::grill::capture_flaw
# ============================================================

devorq::grill::capture_flaw() {
    local flaw="$1"
    local topic="${2:-}"
    local session_file="${3:-}"

    local timestamp
    timestamp="$(date '+%Y-%m-%dT%H:%M:%S')"

    echo ""
    echo "[DESIGN FLAW FOUND] $flaw"
    echo ""

    # Adicionar à sessão
    if [ -n "$session_file" ] && [ -f "$session_file" ]; then
        local entry
        entry=$(jq -n \
            --arg text "$flaw" \
            --arg topic "$topic" \
            --arg timestamp "$timestamp" \
            '{text: $text, topic: $topic, timestamp: $timestamp}')
        
        jq --argjson entry "$entry" \
           '.flaws += [$entry]' \
           "$session_file" > "${session_file}.tmp" && \
            mv "${session_file}.tmp" "$session_file"
    fi

    # Log para rules/design-flaws.md se existir
    local flaws_file="${PWD}/.devorq/rules/design-flaws.md"
    if [ -f "$flaws_file" ]; then
        echo "- **$timestamp** [$topic]: $flaw" >> "$flaws_file"
    fi
}

# ============================================================
# devorq::grill::capture_tradeoff
# ============================================================

devorq::grill::capture_tradeoff() {
    local tradeoff="$1"
    local context="${2:-}"
    local topic="${3:-}"
    local session_file="${4:-}"

    local timestamp
    timestamp="$(date '+%Y-%m-%dT%H:%M:%S')"

    echo ""
    echo "[TRADE-OFF ACCEPTED] $tradeoff"
    echo "  Contexto: $context"
    echo ""

    # Adicionar à sessão
    if [ -n "$session_file" ] && [ -f "$session_file" ]; then
        local entry
        entry=$(jq -n \
            --arg text "$tradeoff" \
            --arg context "$context" \
            --arg topic "$topic" \
            --arg timestamp "$timestamp" \
            '{text: $text, context: $context, topic: $topic, timestamp: $timestamp}')
        
        jq --argjson entry "$entry" \
           '.tradeoffs += [$entry]' \
           "$session_file" > "${session_file}.tmp" && \
            mv "${session_file}.tmp" "$session_file"
    fi

    # Log para rules/tradeoffs.md se existir
    local tradeoffs_file="${PWD}/.devorq/rules/tradeoffs.md"
    if [ -f "$tradeoffs_file" ]; then
        echo "## $timestamp [$topic]" >> "$tradeoffs_file"
        echo "" >> "$tradeoffs_file"
        echo "**Trade-off:** $tradeoff" >> "$tradeoffs_file"
        echo "" >> "$tradeoffs_file"
        echo "**Contexto:** $context" >> "$tradeoffs_file"
        echo "" >> "$tradeoffs_file"
    fi
}

# ============================================================
# devorq::grill::capture_complete
# ============================================================

devorq::grill::capture_complete() {
    local session_id="$1"
    local session_file="$2"

    if [ -f "$session_file" ]; then
        jq '.ended_at = "'$(date '+%Y-%m-%dT%H:%M:%S')'" | .complete = true' \
           "$session_file" > "${session_file}.tmp" && \
            mv "${session_file}.tmp" "$session_file"
    fi

    echo "[OK] Sessão de grill finalizada."
}

# ============================================================
# devorq::grill::auto_capture_lesson
# ============================================================

devorq::grill::auto_capture_lesson() {
    local flaw="$1"
    local topic="$2"

    echo ""
    echo "[HINT] Falha de design detectada. Considere capturar lição:"
    echo "  devorq lessons capture \"design flaw: $flaw\" \\"
    echo "    --problem \"$topic\" \\"
    echo "    --solution \"corrigir: $flaw\" \\"
    echo "    --stack devorq --tags design,grill"
}

# ============================================================
# devorq::grill::start
# ============================================================

devorq::grill::start() {
    local topic="$1"
    devorq::grill::interactive "$topic"
}

# ============================================================
# devorq::grill::list
# ============================================================

devorq::grill::list() {
    local sessions_dir="${PWD}/.devorq/state/sessions"

    if [ ! -d "$sessions_dir" ]; then
        echo "[INFO] Nenhuma sessão de grill encontrada."
        return 0
    fi

    echo ""
    echo "═══════════════════════════════════════════"
    echo "  Sesses de Grill"
    echo "═══════════════════════════════════════════"
    echo ""

    local count=0
    for session_file in "${sessions_dir}"/grill_*.json; do
        if [ -f "$session_file" ]; then
            local id topic started_at premises_count flaws_count tradeoffs_count
            id=$(jq -r '.id' "$session_file")
            topic=$(jq -r '.topic' "$session_file")
            started_at=$(jq -r '.started_at' "$session_file")
            premises_count=$(jq -r '.premises | length' "$session_file")
            flaws_count=$(jq -r '.flaws | length' "$session_file")
            tradeoffs_count=$(jq -r '.tradeoffs | length' "$session_file")
            
            echo "  $id"
            echo "    Tópico: $topic"
            echo "    Iniciado: $started_at"
            echo "    Premissas: $premises_count | Flaws: $flaws_count | Trade-offs: $tradeoffs_count"
            echo ""
            ((count++)) || true
        fi
    done

    echo "Total: $count sessão(ões)"
    echo ""
}

# ============================================================
# devorq::grill::help
# ============================================================

devorq::grill::help() {
    cat << EOF
## DEVORQ Grill

Sessões de sparring para questionar soluções até encontrar fragilidades.

### Princípio

**Grill não é debate — é demolição estruturada.**

### Perguntas de grill

- "O que acontece se X falhar?"
- "E se a escala for 100x?"
- "Qual o pior cenário?"
- "Dados de produção > opinião"
- "Se não pode medir, nãoaceita"

### Gates de captura

| Gate | Gatilho | Ação |
|------|---------|------|
| PREMISSA_QUESTIONADA | Premissa questionada | Log to rules/premises.md |
| DESIGN_FLAW_FOUND | Falha de design | devorq lessons capture |
| TRADE-OFF_ACCEPTED | Trade-off válido | Log to rules/tradeoffs.md |
| GRILL_COMPLETE | Sessão finalizada | Compilar lições |

### Três strikes = regra nova

Se a mesma objeção aparecer em 3+ sessões, criar regra permanente em rules/.

### Integração com Rules

O grill é regido por \`rules/grill.md\`:

- Decisão de grill é condicional — nunca "sim ou não", sempre "sim SE X, não SE Y"
- Três sessões de grill no mesmo ponto → criar regra permanente

### Exemplo

\`\`\`bash
devorq grill "microservices vs monolith"
# Questionar premissas...
# Registrar falhas de design...
# Registrar trade-offs aceitos...
# Ao final:
devorq lessons capture "monolith melhor para MVP" \\
    --problem "microservices complexidade desnecessária" \\
    --solution "usar monolith modular para projetos < 10 desenvolvedores"
\`\`\`
EOF
}