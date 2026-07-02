#!/usr/bin/env bash
# shellcheck disable=SC1091,SC2086,SC2034,SC2015,SC2001,SC2162,SC1090,SC1010,SC2164,SC2155,SC2094,SC2005,SC2317,SC2129,SC2126,SC2120,SC2119,SC2116,SC2046
# lib/context7.sh — DEVORQ Context7 Integration
#
# Consulta documentação oficial via Context7.
# Suporta 3 modos: CLI (ctx7), MCP (opencode), API direta.
# Detecta automaticamente o melhor método disponível.
#
# Funções:
#   ctx7_check       — Verifica se Context7 está configurado e responde
#   ctx7_search      — Busca documentação por query
#   ctx7_resolve     — Resolve library ID e busca docs
#   ctx7_compare     — Compara múltiplas libs para uma query
#   ctx7_detect      — Detecta método disponível (cli/mcp/api/none)
#   ctx7_install     — Instala via cli|mcp|api
#
# Detecção automática de método (prioridade):
#   1. CLI (ctx7 no PATH)       — mais rápido, offline-capable
#   2. MCP (opencode plugin)    — protocolo nativo
#   3. API direta (REST)         — fallback
#
# Config (via env ou ~/.devorq/config):
#   OPENAI_API_KEY   — API key para Context7
#   OPENAI_BASE_URL  — Endpoint da API (default: https://api.context7.io/v1)
#   CTX7_MCP_URL     — URL do MCP server (default: https://mcp.context7.com/mcp)

set -euo pipefail

CTX7_CONFIG="${DEVORQ_CONFIG:-${HOME}/.devorq/config}"
CTX7_API_KEY="${OPENAI_API_KEY:-}"
CTX7_BASE_URL="${OPENAI_BASE_URL:-https://api.context7.io/v1}"
CTX7_MCP_URL="${CTX7_MCP_URL:-https://mcp.context7.com/mcp}"

# Carrega API key do config se existir
_load_config() {
    if [ -f "$CTX7_CONFIG" ]; then
        # PATCH F-01: substituir source <(grep ...) por leitura segura
        # O source original executava command substitution no shell atual
        # (RCE via payload no $CTX7_CONFIG). Agora validamos keys explicitamente.
        while IFS='=' read -r k v; do
            [[ "$k" =~ ^(OPENAI_API_KEY|CTX7_API_KEY|CTX7_MCP_URL)$ ]] || continue
            declare -gx "$k=$v"
        done < <(grep -E "^(OPENAI_API_KEY|CTX7_API_KEY|CTX7_MCP_URL)=" "$CTX7_CONFIG" 2>/dev/null)
        CTX7_API_KEY="${OPENAI_API_KEY:-${CTX7_API_KEY:-}}"
    fi
}

# ============================================================
# DETECÇÃO DE MÉTODO
# ============================================================

# Detecta método disponível: cli | mcp | api | none
# Prioridade: CLI > MCP > API
ctx7_detect() {
    if _ctx7_cli_available; then
        echo "cli"
    elif _ctx7_mcp_available; then
        echo "mcp"
    elif [ -n "${CTX7_API_KEY:-}" ]; then
        echo "api"
    else
        echo "none"
    fi
}

# Verifica se CLI ctx7 está disponível
_ctx7_cli_available() {
    command -v ctx7 &>/dev/null && return 0
    # npx ctx7 também funciona
    command -v npx &>/dev/null && npx ctx7 --version &>/dev/null 2>&1 && return 0
    return 1
}

# Verifica se MCP context7 está configurado
_ctx7_mcp_available() {
    # opencode com plugin context7
    if command -v opencode &>/dev/null; then
        opencode --list-plugins 2>/dev/null | grep -qi "context7" && return 0
    fi
    # Arquivo de config MCP
    if [ -f "${HOME}/.opencode/mcp.json" ] || [ -f "${HOME}/.config/opencode/mcp.json" ]; then
        return 0
    fi
    return 1
}

# Testa CLI mode
_ctx7_cli_test() {
    _load_config
    if ! _ctx7_cli_available; then
        return 1
    fi

    local output
    if command -v ctx7 &>/dev/null; then
        output=$(ctx7 library express "test query" 2>/dev/null || echo "")
    else
        output=$(npx ctx7 library express "test query" 2>/dev/null || echo "")
    fi

    [ -n "$output" ] && return 0
    return 1
}

# Testa MCP mode via HTTP POST com headers corretos
_ctx7_mcp_test() {
    _load_config
    [ -z "${CTX7_API_KEY:-}" ] && return 1

    local resp
    resp=$(curl -s --max-time 10 \
        -X POST \
        -H "Content-Type: application/json" \
        -H "Accept: application/json, text/event-stream" \
        -H "Authorization: Bearer ${CTX7_API_KEY}" \
        -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"devorq","version":"1.0"}}}' \
        "${CTX7_MCP_URL}" 2>/dev/null)

    echo "$resp" | grep -q "jsonrpc" && return 0
    return 1
}

# Testa API direta (REST fallback)
_ctx7_api_test() {
    _load_config
    [ -z "${CTX7_API_KEY:-}" ] && return 1

    local resp
    resp=$(_ctx7_req "/context7/resolve" \
        '{"library": "express", "query": "test"}' 2>/dev/null)

    [ -n "$resp" ] && return 0
    return 1
}

# Request com fallback para múltiplos endpoints
_ctx7_req_with_fallback() {
    local endpoint="${1:-}"
    local payload="${2:-}"
    local api_key="${3:-${CTX7_API_KEY}}"

    local base_urls=(
        "https://api.context7.io/v1"
        "https://api.context7.com/v1"
    )

    for base_url in "${base_urls[@]}"; do
        local resp
        resp=$(curl -s --max-time 15 \
            -X POST \
            -H "Authorization: Bearer ${api_key}" \
            -H "Content-Type: application/json" \
            -d "$payload" \
            "${base_url}${endpoint}" 2>/dev/null)

        if [ -n "$resp" ]; then
            echo "$resp"
            return 0
        fi
    done

    return 1
}

# ============================================================
# _ctx7_req — Faz request POST genérico ao Context7
# ============================================================

_ctx7_req() {
    local endpoint="${1:-}"
    local payload="${2:-}"
    local api_key="${3:-${CTX7_API_KEY}}"

    if [ -z "$api_key" ]; then
        echo "[ERROR] OPENAI_API_KEY não configurado" >&2
        return 1
    fi

    curl -s --fail-with-body \
        -X POST \
        -H "Authorization: Bearer ${api_key}" \
        -H "Content-Type: application/json" \
        -d "$payload" \
        "${CTX7_BASE_URL}${endpoint}" 2>/dev/null
}

# ============================================================
# ctx7_check — Verifica se Context7 responde (auto-detect)
# ============================================================
# Chamado por GATE-6. Detecta melhor método e testa.
# Retorna 0 se qualquer método funcionar.

ctx7_check() {
    _load_config

    local method
    method=$(ctx7_detect)

    echo "[INFO] Context7: método detectado = $method"

    case "$method" in
        cli)
            echo "[INFO] Context7: testando CLI..."
            if _ctx7_cli_test; then
                echo "[OK] Context7: CLI respondendo"
                return 0
            else
                echo "[WARN] Context7: CLI disponível mas não respondeu"
            fi
            ;;
        mcp)
            echo "[INFO] Context7: testando MCP..."
            if _ctx7_mcp_test; then
                echo "[OK] Context7: MCP respondendo"
                return 0
            else
                echo "[WARN] Context7: MCP configurado mas não respondeu"
            fi
            ;;
        api)
            echo "[INFO] Context7: testando API direta..."
            if _ctx7_api_test; then
                echo "[OK] Context7: API respondendo"
                return 0
            else
                echo "[WARN] Context7: API não respondeu"
            fi
            ;;
        *)
            echo "[WARN] Context7: OPENAI_API_KEY não configurado"
            echo "[INFO] Para instalar: devorq context7 install"
            return 1
            ;;
    esac

    echo "[WARN] Context7: nenhum método funcionou"
    return 1
}

# ============================================================
# ctx7_search — Busca documentação por query
# ============================================================
# Uso: ctx7_search "<query>"
# Retorna: resultados formatados em markdown

ctx7_search() {
    local query="${1:-}"
    _load_config

    if [ -z "$query" ]; then
        echo "[ERROR] Uso: ctx7_search \"<query>\""
        return 1
    fi

    if [ -z "${CTX7_API_KEY:-}" ]; then
        echo "[WARN] Context7: OPENAI_API_KEY não configurado"
        return 1
    fi

    echo "[INFO] Context7: buscando '$query'..."

    local resp
    resp=$(_ctx7_req "/context7/resolve" \
        "$(jq -n --arg q "$query" '{"library": "_auto", "query": $q}')" 2>/dev/null)

    if [ -z "$resp" ]; then
        echo "[WARN] Context7: sem resposta para '$query'"
        return 1
    fi

    # Extrai conteúdo relevante do response
    if command -v jq &>/dev/null; then
        echo "$resp" | jq -r '.results // [.documents // .[]] | .[:5] | .[] | "- **\(.title // "Sem título")**\n  \(.content // .snippet // . // "" | .[0:300])..."' 2>/dev/null || echo "$resp"
    else
        echo "$resp"
    fi
}

# ============================================================
# ctx7_resolve — Resolve biblioteca e busca docs
# ============================================================
# Uso: ctx7_resolve <library> "<query>"
# Exemplo: ctx7_resolve "react" "useEffect hook"

ctx7_resolve() {
    local library="${1:-}"
    local query="${2:-}"
    _load_config

    if [ -z "$library" ] || [ -z "$query" ]; then
        echo "[ERROR] Uso: ctx7_resolve <library> \"<query>\""
        return 1
    fi

    if [ -z "${CTX7_API_KEY:-}" ]; then
        echo "[WARN] Context7: OPENAI_API_KEY não configurado"
        return 1
    fi

    echo "[INFO] Context7: resolvendo $library para '$query'..."

    local resp
    resp=$(_ctx7_req "/context7/resolve" \
        "$(jq -n --arg lib "$library" --arg q "$query" '{"library": $lib, "query": $q}')" 2>/dev/null)

    if [ -z "$resp" ]; then
        echo "[WARN] Context7: sem resposta"
        return 1
    fi

    # Formata saída
    if command -v jq &>/dev/null; then
        local content
        content=$(echo "$resp" | jq -r '.content // .documents // .[0].content // .text // .' 2>/dev/null || echo "$resp")
        echo "$content"
    else
        echo "$resp"
    fi
}

# ============================================================
# ctx7_compare — Compara múltiplas libs para uma query
# ============================================================
# Uso: ctx7_compare "<query>" <lib1> <lib2> ...
# Exemplo: ctx7_compare "http server" express fastify koa

ctx7_compare() {
    local query="${1:-}"
    shift
    local libs=("$@")
    _load_config

    if [ -z "$query" ] || [ ${#libs[@]} -eq 0 ]; then
        echo "[ERROR] Uso: ctx7_compare \"<query>\" <lib1> <lib2> ..."
        return 1
    fi

    if [ -z "${CTX7_API_KEY:-}" ]; then
        echo "[WARN] Context7: OPENAI_API_KEY não configurado"
        return 1
    fi

    echo "[INFO] Context7: comparando ${libs[*]} para '$query'"
    echo ""

    for lib in "${libs[@]}"; do
        echo "=== $lib ==="
        ctx7_resolve "$lib" "$query"
        echo ""
    done
}

# ============================================================
# ctx7_install — Instala Context7 via método escolhido
# ============================================================
# Uso: ctx7_install [cli|mcp|api]
# Sem argumento: detecta melhor opção e pergunta

ctx7_install() {
    local method="${1:-}"
    _load_config

    echo "═══ Context7 Installer ═══"
    echo ""

    # Fase 1: Detectar plataforma
    echo "[1/4] Detectando plataforma..."
    if command -v node &>/dev/null; then
        echo "  ✓ Node.js $(node --version 2>/dev/null)"
    fi
    if command -v npm &>/dev/null; then
        echo "  ✓ npm $(npm --version 2>/dev/null)"
    fi
    if command -v opencode &>/dev/null; then
        echo "  ✓ opencode disponível"
    fi
    echo ""

    # Sem Node.js → só API direta
    if ! command -v node &>/dev/null; then
        echo "[INFO] Node.js não encontrado — API direta é a única opção"
        echo "[INFO] Configure OPENAI_API_KEY em ~/.devorq/config"
        echo ""
        echo "Exemplo:"
        echo "  echo 'OPENAI_API_KEY=sua_chave_aqui' >> ~/.devorq/config"
        return 0
    fi

    # Se não especificou método, mostra opções
    if [ -z "$method" ]; then
        echo "[2/4] Selecione o método de instalação:"
        echo ""
        echo "  [1] CLI + Skills (RECOMENDADO)"
        echo "      npm install -g ctx7"
        echo "      Mais rápido, offline-capable"
        echo ""
        echo "  [2] MCP Server"
        echo "      Configura opencode com plugin context7"
        echo "      Requer opencode instalado"
        echo ""
        echo "  [3] API Direta (fallback)"
        echo "      Usa REST API diretamente"
        echo "      Precisa de OPENAI_API_KEY no config"
        echo ""
        read -p "[3/4] Opção [1]: " method
        method="${method:-1}"
    fi

    echo "[3/4] Instalando..."
    echo ""

    case "$method" in
        1|cli)
            _install_cli
            ;;
        2|mcp)
            _install_mcp
            ;;
        3|api)
            _install_api
            ;;
        *)
            echo "[ERROR] Opção inválida: $method"
            echo "Use: cli | mcp | api"
            return 1
            ;;
    esac

    echo ""
    echo "[4/4] Validando..."
    echo ""

    # Testa o que foi instalado
    local test_method
    test_method=$(ctx7_detect)
    echo "  Método detectado após instalação: $test_method"

    if [ "$test_method" != "none" ]; then
        echo ""
        echo "✓ Context7 instalado com sucesso!"
        echo "  Execute 'devorq gate 6' para testar"
    else
        echo ""
        echo "⚠ Context7 não pôde ser validado automaticamente"
        echo "  Configure OPENAI_API_KEY manualmente em ~/.devorq/config"
    fi

    echo ""
    echo "═══ Concluído ═══"
}

_install_cli() {
    if command -v ctx7 &>/dev/null; then
        echo "  ✓ ctx7 já está instalado"
    else
        # Permite fixar a versao (supply-chain): DEVORQ_CTX7_VERSION pin o pacote
        # global em vez de instalar sempre o latest (DQ-015).
        local ctx7_pkg="ctx7@${DEVORQ_CTX7_VERSION:-latest}"
        echo "  → npm install -g ${ctx7_pkg}"
        if npm install -g "${ctx7_pkg}" 2>&1; then
            echo "  ✓ ctx7 instalado via npm"
        else
            echo "  ✗ npm install falhou"
            return 1
        fi
    fi

    # Configura API key se tiver
    if [ -n "${CTX7_API_KEY:-}" ]; then
        echo "  → ctx7 config set api-key"
        ctx7 config set api-key "${CTX7_API_KEY}" 2>/dev/null || true
    fi

    # Setup opencode se disponível
    if command -v opencode &>/dev/null; then
        echo "  → ctx7 setup --opencode"
        ctx7 setup --opencode 2>/dev/null || true
    fi

    echo "  ✓ CLI instalada"
}

_install_mcp() {
    local mcp_config="${HOME}/.opencode/mcp.json"
    mkdir -p "$(dirname "$mcp_config")"

    if [ -f "$mcp_config" ]; then
        echo "  → Backup: ${mcp_config}.bak"
        cp "$mcp_config" "${mcp_config}.bak"
    fi

    # Resolve a chave em tempo de escrita (heredoc SEM aspas no delimitador para
    # expandir ${api_key}). Antes, << 'MCPEOF' gravava o literal ${OPENAI_API_KEY}
    # e o MCP nunca autenticava (DQ-025).
    local api_key="${CTX7_API_KEY:-${OPENAI_API_KEY:-}}"
    if [ -z "$api_key" ]; then
        echo "  [WARN] CTX7_API_KEY/OPENAI_API_KEY não definida — MCP config sem token" >&2
    fi

    cat > "$mcp_config" << MCPEOF
{
  "mcpServers": {
    "context7": {
      "url": "https://mcp.context7.com/mcp",
      "headers": {
        "Authorization": "Bearer ${api_key}"
      }
    }
  }
}
MCPEOF

    chmod 600 "$mcp_config" 2>/dev/null || true   # contem Bearer token — nao expor
    echo "  ✓ MCP configurado em $mcp_config"
    echo "  → Reinicie o opencode para aplicar"
}

_install_api() {
    if [ -n "${CTX7_API_KEY:-}" ]; then
        echo "  ✓ API key já configurada em ~/.devorq/config"
        echo "  ✓ Nada a fazer — API direta não requer instalação"
    else
        echo "  ⚠ OPENAI_API_KEY não configurada"
        echo "  → Adicione ao config:"
        echo "  echo 'OPENAI_API_KEY=sua_chave' >> ~/.devorq/config"
    fi
}
