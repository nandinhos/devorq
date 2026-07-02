#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2086,SC2034,SC2015,SC2001,SC2162,SC1090,SC1010,SC2164,SC2155,SC2094,SC2005,SC2317,SC2129,SC2126,SC2120,SC2119,SC2116,SC2046
# lib/context.sh — DEVORQ Context-Mode
#
# Ferramentas para análise, compressão e merge de contexto.
# Token-aware: sabe quando está excedendo limites de contexto.

set -euo pipefail

# ============================================================
# ctx_lint — Verifica sanidade do context.json
# ============================================================

ctx_lint() {
    local ctx_file="${PWD}/.devorq/state/context.json"
    local errors=0

    if [ ! -f "$ctx_file" ]; then
        echo "[WARN] context.json não encontrado"
        return 1
    fi

    if command -v jq &>/dev/null; then
        # Verificar campos obrigatórios
        for field in project intent stack; do
            if ! jq -e "has(\"$field\")" "$ctx_file" >/dev/null 2>&1; then
                echo "[WARN] Campo '$field' ausente em context.json"
                errors=$((errors+1))
            fi
        done

        # Verificar se é objecto válido
        if ! jq -e 'type == "object"' "$ctx_file" >/dev/null 2>&1; then
            echo "[ERROR] context.json não é um objeto JSON válido"
            errors=$((errors+1))
        fi

        # success_criteria recomendado quando intent preenchido (v3.8+)
        local intent_val
        intent_val=$(jq -r '.intent // ""' "$ctx_file" 2>/dev/null)
        if [ -n "$intent_val" ] && [ "$intent_val" != "null" ]; then
            if ! jq -e 'has("success_criteria")' "$ctx_file" >/dev/null 2>&1; then
                echo "[WARN] Campo 'success_criteria' ausente — defina metas verificáveis (rules/agent-discipline.md)"
            else
                local sc_len
                sc_len=$(jq -r '.success_criteria | length' "$ctx_file" 2>/dev/null || echo "0")
                if [ "$sc_len" = "0" ]; then
                    echo "[WARN] success_criteria vazio — transforme intent em critérios verificáveis"
                fi
            fi
        fi
    else
        # Fallback grep
        for field in project intent stack; do
            if ! grep -q "\"$field\"" "$ctx_file" 2>/dev/null; then
                echo "[WARN] Campo '$field' não encontrado (jq não disponível)"
            fi
        done
    fi

    if [ $errors -eq 0 ]; then
        echo "[PASS] context.json OK"
        return 0
    else
        echo "[ERROR] $errors problema(s) em context.json"
        return 1
    fi
}

# ============================================================
# ctx_stats — Estatísticas de tamanho do contexto
# ============================================================
# Retorna: total_chars, total_tokens (estimado), breakdown

ctx_stats() {
    local ctx_file="${PWD}/.devorq/state/context.json"

    if [ ! -f "$ctx_file" ]; then
        echo "context.json não encontrado — 0 tokens"
        return 1
    fi

    local chars
    chars=$(wc -c < "$ctx_file" 2>/dev/null || echo "0")

    # Estimativa rough: 4 chars ≈ 1 token
    local tokens
    tokens=$((chars / 4))

    echo "=== CONTEXT STATS ==="
    echo "Chars: $chars"
    echo "Tokens (estimado): ~$tokens"
    echo "Limite sugerido: 120k tokens (restam ~$((120000 - tokens)) disponível)"

    if command -v jq &>/dev/null; then
        local sections
        sections=$(jq -r 'keys[]' "$ctx_file" 2>/dev/null | tr '\n' ' ')
        echo "Seções: $sections"

        # Breakdown por seção
        while IFS= read -r key; do
            [ -z "$key" ] && continue
            local val_size
            val_size=$(jq -r ".[\"$key\"] | if type == \"string\" then length elif type == \"array\" then length else tostring | length end" "$ctx_file" 2>/dev/null || echo "?")
            echo "  $key: $val_size"
        done < <(jq -r 'keys[]' "$ctx_file" 2>/dev/null)
    fi

    # Alerta se exceder threshold (60k tokens = 240k chars)
    if [ "$chars" -gt 240000 ]; then
        echo ""
        echo "[WARN] Contexto grande detectado — considere comprimir com ctx_pack"
    fi
}

# ============================================================
# ctx_pack — Comprime contexto para handoff
# ============================================================
# Reduz context.json para formato minimal de handoff.

ctx_pack() {
    local ctx_file="${PWD}/.devorq/state/context.json"
    local output="${1:-${PWD}/.devorq/state/handoff.json}"

    if [ ! -f "$ctx_file" ]; then
        echo "[ERROR] context.json não encontrado"
        return 1
    fi

    echo "[INFO] Comprimindo contexto para handoff..."

    if command -v jq &>/dev/null; then
        # Extrai apenas campos essenciais para handoff
        jq '{
            project: (.project // ""),
            intent: (.intent // ""),
            stack: (.stack // [] | if type == "array" then . else [] end),
            gates_completed: (.gates_completed // [] | if type == "array" then . else [] end),
            pending_gates: (.pending_gates // [] | if type == "array" then . else [] end),
            last_session: (.last_session // ""),
            pending: (.pending // ""),
            timestamp: (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
        }' "$ctx_file" > "$output"
    else
        # Fallback: copiar só campos críticos via grep
        echo "{"
        echo "  \"project\": \"$(grep '"project"' "$ctx_file" | head -1 | cut -d'"' -f4 || echo '')\","
        echo "  \"intent\": \"$(grep '"intent"' "$ctx_file" | head -1 | cut -d'"' -f4 || echo '')\","
        echo "  \"stack\": [],"
        echo "  \"gates_completed\": [],"
        echo "  \"pending_gates\": [],"
        echo "  \"pending\": \"\","
        echo "  \"timestamp\": \"$(date -u +%Y-%m-%dT%H:%M:%SZ)\""
        echo "}" > "$output"
    fi

    echo "[OK] Handoff salvo: $output"
}

# ============================================================
# ctx_merge — Merge de dois contextos
# ============================================================
# Uso: ctx_merge <incoming.json> [base.json]
# Incoming tem prioridade sobre base.

ctx_merge() {
    local incoming="${1:-}"
    local base="${2:-${PWD}/.devorq/state/context.json}"

    if [ -z "$incoming" ]; then
        echo "[ERROR] Uso: ctx_merge <incoming.json> [base.json]"
        return 1
    fi

    if [ ! -f "$incoming" ]; then
        echo "[ERROR] Arquivo não encontrado: $incoming"
        return 1
    fi

    local output="${PWD}/.devorq/state/context.json"

    echo "[INFO] Merge: $incoming + $(basename "$base") -> context.json"

    if command -v jq &>/dev/null; then
        # base vem primeiro, incoming sobrescreve campos comuns
        jq -s '.[0] * .[1]' "$base" "$incoming" > "$output.tmp" 2>/dev/null && mv "$output.tmp" "$output"
    else
        # Fallback: substitui todo o contexto
        cp "$incoming" "$output"
    fi

    echo "[OK] Contexto mesclado: $output"
    ctx_stats
}

# ============================================================
# ctx_set — Define um campo no context.json
# ============================================================
# Uso: ctx_set <campo> <valor>

ctx_set() {
    local field="${1:-}"
    local value="${2:-}"
    local ctx_file="${PWD}/.devorq/state/context.json"

    if [ -z "$field" ]; then
        echo "[ERROR] Uso: ctx_set <campo> <valor>"
        return 1
    fi

    mkdir -p "$(dirname "$ctx_file")"

    if [ ! -f "$ctx_file" ]; then
        echo "{}" > "$ctx_file"
    fi

        # PATCH F-02: exigir jq (sed fallback era vulneravel a injection)
    if ! command -v jq &>/dev/null; then
        echo "[ERROR] ctx_set requer 'jq' instalado (sed fallback removido por seguranca)" >&2
        echo "        Instale: apt install jq  /  brew install jq" >&2
        return 1
    fi

    local tmp
    tmp=$(mktemp)
    if echo "$value" | jq -e . >/dev/null 2>&1; then
        jq --arg f "$field" --argjson v "$value" '.[$f] = $v' "$ctx_file" > "$tmp"
    else
        jq --arg f "$field" --arg v "$value" '.[$f] = $v' "$ctx_file" > "$tmp"
    fi
    mv "$tmp" "$ctx_file"


    echo "[OK] $field = $value"
}

# ============================================================
# ctx_mark_gate — Persiste um gate concluido em gates_completed
# (idempotente). Faz a observabilidade (stats/handoff/GATE-7) e a
# retomada do flow refletirem a execucao real, em vez de estado-fantasma. DQ-007.
# ============================================================

ctx_mark_gate() {
    local gate="${1:-}"
    local ctx_file="${PWD}/.devorq/state/context.json"
    [ -z "$gate" ] && return 0
    command -v jq &>/dev/null || return 0

    mkdir -p "$(dirname "$ctx_file")"
    [ -f "$ctx_file" ] || echo "{}" > "$ctx_file"

    local ts tmp
    ts=$(date +%Y-%m-%dT%H:%M:%SZ)
    tmp=$(mktemp)
    if jq --arg g "$gate" --arg ts "$ts" '
            .gates_completed = ((.gates_completed // []) + [$g] | unique)
            | .last_session = $ts
        ' "$ctx_file" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
        mv "$tmp" "$ctx_file"
    else
        rm -f "$tmp"
        return 1
    fi
}

# ============================================================
# ctx_clear — Limpa contexto
# ============================================================

ctx_clear() {
    local ctx_file="${PWD}/.devorq/state/context.json"

    if [ -f "$ctx_file" ]; then
        rm "$ctx_file"
        echo "[OK] context.json removido"
    else
        echo "[INFO] Nenhum context.json para limpar"
    fi
}

# ============================================================
# ctx_get — Exibe o contexto atual
# ============================================================

ctx_get() {
    local ctx_file="${PWD}/.devorq/state/context.json"

    if [ ! -f "$ctx_file" ]; then
        echo "[WARN] context.json não encontrado. Execute 'devorq init' ou configure um contexto."
        return 1
    fi

    if command -v jq &>/dev/null; then
        jq . "$ctx_file"
    else
        cat "$ctx_file"
    fi
}

