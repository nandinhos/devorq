#!/bin/bash
# DEVORQ - Módulo de Detecção
# Funções de detecção de contexto, stack, LLM, tipo de projeto

# =====================================================
# DETECÇÃO DE LLM
# =====================================================

detect_llm() {
    # 1. Verificar variáveis de ambiente (primário)
    if [[ "$OPENCODE" == "1" ]] || [[ "$OPENCODE" == "true" ]]; then
        echo "opencode"
        return
    fi
    
    if [[ "$PROMPT" == *"Antigravity"* ]] || [[ "$ANTIGRAVITY" == "true" ]]; then
        echo "antigravity"
        return
    fi
    
    if [[ "$PROMPT" == *"Gemini"* ]] || [[ "$GEMINI" == "true" ]]; then
        echo "gemini"
        return
    fi
    
    if [[ "$PROMPT" == *"Claude"* ]] || [[ "$CLAUDE" == "true" ]]; then
        echo "claude"
        return
    fi
    
    if [[ "$PROMPT" == *"MiniMax"* ]] || [[ "$MINIMAX" == "true" ]]; then
        echo "minimax"
        return
    fi
    
    # 2. Verificar CLAUDE_TASK_ID (Claude Code)
    if [ -n "$CLAUDE_TASK_ID" ]; then
        if [[ "$CLAUDE_TASK_ID" == *"antigravity"* ]]; then
            echo "antigravity"
            return
        fi
    fi
    
    # 3. Fallback: verificar context.json do DEVORQ (funciona no Docker)
    local devorq_context="${DEVORQ_DIR:-.devorq}/state/context.json"
    if [ -f "$devorq_context" ]; then
        local llm_from_context=$(grep -o '"llm"[[:space:]]*:[[:space:]]*"[^"]*"' "$devorq_context" 2>/dev/null | cut -d'"' -f4)
        if [ -n "$llm_from_context" ] && [[ "$llm_from_context" != "unknown" ]]; then
            echo "$llm_from_context"
            return
        fi
    fi
    
    # 4. Detecção por arquivo de sessão
    local devorq_session="${DEVORQ_DIR:-.devorq}/state/session.json"
    if [ -f "$devorq_session" ]; then
        local llm_from_session=$(grep -o '"llm"[[:space:]]*:[[:space:]]*"[^"]*"' "$devorq_session" 2>/dev/null | head -1 | cut -d'"' -f4)
        if [ -n "$llm_from_session" ] && [[ "$llm_from_session" != "unknown" ]]; then
            echo "$llm_from_session"
            return
        fi
    fi
    
    # 5. Detecção por nome do container/podman
    if [ -f "/.dockerenv" ]; then
        # Dentro do Docker, tentar detectar pelo hostname
        if hostname | grep -qi "opencode"; then
            echo "opencode"
            return
        fi
        if hostname | grep -qi "claude"; then
            echo "claude"
            return
        fi
    fi
    
    echo "unknown"
}

# =====================================================
# DETECÇÃO DE STACK
# =====================================================

detect_stack() {
    local root="${1:-.}"
    
    if [ -f "$root/composer.json" ]; then
        if grep -q '"laravel/framework"' "$root/composer.json" 2>/dev/null; then
            echo "laravel"
            return
        fi
        if grep -q '"php"' "$root/composer.json" 2>/dev/null; then
            echo "php"
            return
        fi
    fi
    
    if [ -f "$root/package.json" ]; then
        if grep -q '"next"' "$root/package.json" 2>/dev/null; then
            echo "nextjs"
            return
        fi
        if grep -q '"react"' "$root/package.json" 2>/dev/null; then
            echo "react"
            return
        fi
        if grep -q '"vue"' "$root/package.json" 2>/dev/null; then
            echo "vue"
            return
        fi
        echo "node"
        return
    fi
    
    if [ -f "$root/requirements.txt" ] || [ -f "$root/pyproject.toml" ]; then
        if [ -f "$root/pyproject.toml" ]; then
            if grep -q '"django"' "$root/pyproject.toml" 2>/dev/null; then
                echo "django"
                return
            fi
            if grep -q '"fastapi"' "$root/pyproject.toml" 2>/dev/null; then
                echo "fastapi"
                return
            fi
        fi
        echo "python"
        return
    fi
    
    if [ -f "$root/go.mod" ]; then
        echo "go"
        return
    fi
    
    if [ -f "$root/Cargo.toml" ]; then
        echo "rust"
        return
    fi
    
    echo "generic"
}

# =====================================================
# DETECÇÃO DE TIPO DE PROJETO
# =====================================================

detect_project_type() {
    local root="${1:-.}"
    
    if [ ! -d "$root/vendor" ] && [ ! -d "$root/node_modules" ]; then
        local has_code=false
        [ -d "$root/app" ] && has_code=true
        [ -d "$root/src" ] && has_code=true
        
        if [ "$has_code" = false ]; then
            echo "greenfield"
            return
        fi
    fi
    
    echo "brownfield"
}

# =====================================================
# DETECÇÃO DE RUNTIME
# =====================================================

detect_runtime() {
    if [ -f "docker-compose.yml" ] || [ -f "Dockerfile" ]; then
        if [ -f "docker-compose.yml" ]; then
            if grep -q "sail" "docker-compose.yml" 2>/dev/null; then
                echo "docker-sail"
                return
            fi
        fi
        echo "docker"
        return
    fi
    
    echo "local"
}

# =====================================================
# DETECÇÃO DE BANCO
# =====================================================

detect_database() {
    if [ -f ".env" ]; then
        if grep -q "DB_CONNECTION=mysql" ".env" 2>/dev/null; then
            echo "mysql"
            return
        fi
        if grep -q "DB_CONNECTION=pgsql" ".env" 2>/dev/null; then
            echo "postgres"
            return
        fi
        if grep -q "DB_CONNECTION=sqlite" ".env" 2>/dev/null; then
            echo "sqlite"
            return
        fi
    fi
    echo "unknown"
}

# =====================================================
# DETECÇÃO DE LEGADO
# =====================================================

is_legacy() {
    local root="${1:-.}"
    
    if [ -d "$root/tests" ]; then
        local test_count=$(find "$root/tests" -name "*.php" -o -name "*.js" 2>/dev/null | wc -l)
        if [ "$test_count" -eq 0 ]; then
            return 0
        fi
    else
        return 0
    fi
    
    if [ -f "$root/composer.json" ]; then
        local version=$(grep -o '"laravel/framework": "[0-9]*' "$root/composer.json" | grep -o '[0-9]*' | head -1)
        if [ -n "$version" ] && [ "$version" -lt 9 ] 2>/dev/null; then
            return 0
        fi
    fi
    
    return 1
}

# =====================================================
# VERIFICAÇÕES
# =====================================================

check_prd_exists() {
    local root="${1:-.}"
    
    if [ -f "$root/docs/PRD.md" ]; then
        echo "$root/docs/PRD.md"
        return
    fi
    
    if [ -f "$root/PRD.md" ]; then
        echo "$root/PRD.md"
        return
    fi
    
    echo ""
}

check_git_repo() {
    if git rev-parse --git-dir > /dev/null 2>&1; then
        echo "true"
    else
        echo "false"
    fi
}

get_git_branch() {
    git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown"
}

# =====================================================
# EXPORTAR CONTEXTO
# =====================================================

export_context() {
    cat << EOF
=== DEVORQ CONTEXT ===
Stack: $(detect_stack)
LLM: $(detect_llm)
Tipo: $(detect_project_type)
Runtime: $(detect_runtime)
DB: $(detect_database)
Git: $(get_git_branch)
Legacy: $(is_legacy && echo "sim" || echo "não")
PRD: $(check_prd_exists || echo "não encontrado")
EOF
}

export -f detect_llm detect_stack detect_project_type detect_runtime detect_database is_legacy check_prd_exists get_git_branch export_context