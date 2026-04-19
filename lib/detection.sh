#!/bin/bash

# ============================================================================
# DEVORQ - Detection Module
# ============================================================================
# Funções para detecção de stack, plataforma e contexto do projeto
# 
# Uso: source lib/detection.sh
# Dependências: lib/core.sh
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "ERRO: Este módulo deve ser carregado via 'source', não executado." >&2; exit 1; fi
# ============================================================================

# Variáveis de resultado de detecção
DETECTED_STACK=""
DETECTED_PLATFORM=""
DETECTED_LANGUAGE=""
DETECTED_PROJECT_NAME=""
DETECTED_MATURITY=""
DETECTED_STYLE=""
DETECTED_FRAMEWORK_VERSION=""
DETECTED_TECH_DEBT=""
DETECTED_RUNTIME=""
DETECTED_MCP_COMPATIBILITY=""

# ============================================================================
# Detecção de Stack
# ============================================================================

# Detecta stack do projeto baseado em arquivos de configuração
# Uso: detect_stack "/path/to/project"
# Retorna: nome da stack detectada
detect_stack() {
    local path="${1:-.}"
    
    if [ ! -d "$path" ]; then
        echo "generic"
        return
    fi
    
    # Salva diretório atual
    local original_dir="$PWD"
    cd "$path" || { echo "generic"; return; }

    # Override manual via .devorq/rules/project.md tem prioridade sobre detecção automática
    if [ -f ".devorq/rules/project.md" ]; then
        local override_stack
        override_stack=$(grep -m1 "^stack:" ".devorq/rules/project.md" 2>/dev/null | cut -d: -f2 | xargs)
        if [ -n "$override_stack" ] && [ "$override_stack" != "generic" ]; then
            cd "$original_dir"
            echo "$override_stack"
            return
        fi
    fi

    # Laravel/PHP
    if [ -f "composer.json" ]; then
        if grep -q "laravel/framework" composer.json 2>/dev/null; then
            if grep -q "filament" composer.json 2>/dev/null; then
                cd "$original_dir"
                echo "filament"
                return
            elif grep -q "livewire" composer.json 2>/dev/null; then
                cd "$original_dir"
                echo "livewire"
                return
            else
                cd "$original_dir"
                echo "laravel"
                return
            fi
        fi
        # PHP genérico
        cd "$original_dir"
        echo "php"
        return
    fi
    
    # Node.js
    if [ -f "package.json" ]; then
        if grep -q "\"next\"" package.json 2>/dev/null; then
            cd "$original_dir"
            echo "nextjs"
            return
        elif grep -q "\"react\"" package.json 2>/dev/null; then
            cd "$original_dir"
            echo "react"
            return
        elif grep -q "\"vue\"" package.json 2>/dev/null; then
            cd "$original_dir"
            echo "vue"
            return
        elif grep -q "\"express\"" package.json 2>/dev/null; then
            cd "$original_dir"
            echo "express"
            return
        else
            cd "$original_dir"
            echo "node"
            return
        fi
    fi
    
    # Python
    if [ -f "pyproject.toml" ]; then
        if grep -q "django" pyproject.toml 2>/dev/null; then
            cd "$original_dir"
            echo "django"
            return
        elif grep -q "fastapi" pyproject.toml 2>/dev/null; then
            cd "$original_dir"
            echo "fastapi"
            return
        elif grep -q "flask" pyproject.toml 2>/dev/null; then
            cd "$original_dir"
            echo "flask"
            return
        fi
        cd "$original_dir"
        echo "python"
        return
    fi
    
    if [ -f "requirements.txt" ]; then
        if grep -q "django" requirements.txt 2>/dev/null; then
            cd "$original_dir"
            echo "django"
            return
        elif grep -q "fastapi" requirements.txt 2>/dev/null; then
            cd "$original_dir"
            echo "fastapi"
            return
        fi
        cd "$original_dir"
        echo "python"
        return
    fi
    
    if [ -f "setup.py" ]; then
        cd "$original_dir"
        echo "python"
        return
    fi
    
    # Ruby
    if [ -f "Gemfile" ]; then
        if grep -q "rails" Gemfile 2>/dev/null; then
            cd "$original_dir"
            echo "rails"
            return
        fi
        cd "$original_dir"
        echo "ruby"
        return
    fi
    
    # Go
    if [ -f "go.mod" ]; then
        cd "$original_dir"
        echo "go"
        return
    fi
    
    # Rust
    if [ -f "Cargo.toml" ]; then
        cd "$original_dir"
        echo "rust"
        return
    fi
    
    cd "$original_dir"
    echo "generic"
}

# ============================================================================
# Detecção de Plataforma
# ============================================================================

# Detecta plataforma de IA disponível
# Uso: detect_platform
# Retorna: nome da plataforma detectada
detect_platform() {
    # Antigravity (prioridade - ambiente atual)
    if [ -d "$HOME/.gemini/antigravity" ]; then
        echo "antigravity"
        return
    fi
    
    # Claude Code
    if command -v claude &> /dev/null; then
        echo "claude-code"
        return
    fi
    
    # Gemini CLI
    if command -v gemini &> /dev/null; then
        echo "gemini"
        return
    fi
    
    # OpenCode
    if [ -d "$HOME/.config/opencode" ] || command -v opencode &> /dev/null; then
        echo "opencode"
        return
    fi
    
    # Rovo
    if command -v rovo &> /dev/null; then
        echo "rovo"
        return
    fi
    
    # Codex
    if [ -d "$HOME/.codex" ] || command -v codex &> /dev/null; then
        echo "codex"
        return
    fi
    
    # Aider
    if command -v aider &> /dev/null; then
        echo "aider"
        return
    fi
    
    # Cursor (verificando processo ou instalação)
    if [ -d "/Applications/Cursor.app" ] || [ -d "$HOME/.cursor" ]; then
        echo "cursor"
        return
    fi
    
    # Continue.dev
    if [ -d "$HOME/.continue" ]; then
        echo "continue"
        return
    fi
    
    echo "generic"
}

# ============================================================================
# Detecção de Runtime
# ============================================================================

# Detecta o runtime atual (e.g., terminal-cli, vscode-extension, web-app)
# Uso: detect_runtime
# Retorna: nome do runtime detectado
detect_runtime() {
    # 0. Antigravity (Specific)
    if [ -n "$ANTIGRAVITY_AGENT" ]; then
        echo "antigravity"
        return
    fi

    # 1. VS Code Extension
    if [ -n "$VSCODE_CWD" ] || [ -n "$VSCODE_PID" ]; then
        echo "vscode-extension"
        return
    fi

    # 2. Web App (e.g., Codespaces, Gitpod)
    if [ -n "$CODESPACES" ] || [ -n "$GITPOD_WORKSPACE_ID" ]; then
        echo "web-app"
        return
    fi

    # 3. Docker Container
    if [ -f "/.dockerenv" ] || grep -q "docker" /proc/self/cgroup 2>/dev/null; then
        echo "docker-container"
        return
    fi

    # 4. Fallback
    echo "terminal-cli"
}

# ============================================================================
# Detecção de Linguagem Principal
# ============================================================================

# Detecta linguagem principal do projeto
# Uso: detect_language "/path/to/project"
detect_language() {
    local path="${1:-.}"
    
    # Baseado nos arquivos de configuração
    if [ -f "$path/composer.json" ]; then
        echo "php"
        return
    fi
    
    if [ -f "$path/package.json" ]; then
        if [ -f "$path/tsconfig.json" ]; then
            echo "typescript"
        else
            echo "javascript"
        fi
        return
    fi
    
    if [ -f "$path/pyproject.toml" ] || [ -f "$path/requirements.txt" ] || [ -f "$path/setup.py" ]; then
        echo "python"
        return
    fi
    
    if [ -f "$path/Gemfile" ]; then
        echo "ruby"
        return
    fi
    
    if [ -f "$path/go.mod" ]; then
        echo "go"
        return
    fi
    
    if [ -f "$path/Cargo.toml" ]; then
        echo "rust"
        return
    fi
    
    if [ -f "$path/pom.xml" ] || [ -f "$path/build.gradle" ]; then
        echo "java"
        return
    fi
    
    if [ -f "$path/*.csproj" ] || [ -f "$path/*.sln" ]; then
        echo "csharp"
        return
    fi
    
    echo "unknown"
}

# ============================================================================
# Detecção de Nome do Projeto
# ============================================================================

# Detecta nome do projeto
# Uso: detect_project_name "/path/to/project"
detect_project_name() {
    local path="${1:-.}"
    
    # Tenta extrair de package.json
    if [ -f "$path/package.json" ]; then
        local name
        name=$(grep -o '"name":[[:space:]]*"[^"]*"' "$path/package.json" 2>/dev/null | head -1 | sed 's/.*"name":[[:space:]]*"\([^"]*\)".*/\1/' || echo "")
        if [ -n "$name" ]; then
            echo "$name"
            return
        fi
    fi
    
    # Tenta extrair de composer.json
    if [ -f "$path/composer.json" ]; then
        local name
        name=$(grep -o '"name":[[:space:]]*"[^"]*"' "$path/composer.json" 2>/dev/null | head -1 | sed 's/.*"name":[[:space:]]*"\([^"]*\)".*/\1/' || echo "")
        if [ -n "$name" ]; then
            # Remove prefixo vendor/ se existir
            echo "${name##*/}"
            return
        fi
    fi
    
    # Tenta extrair de pyproject.toml
    if [ -f "$path/pyproject.toml" ]; then
        local name
        name=$(grep -o '^name[[:space:]]*=[[:space:]]*"[^"]*"' "$path/pyproject.toml" 2>/dev/null | sed 's/.*"\([^"]*\)".*/\1/' || echo "")
        if [ -n "$name" ]; then
            echo "$name"
            return
        fi
    fi
    
    # Fallback: nome do diretório
    basename "$(cd "$path" && pwd)"
}

# ============================================================================
# Detecção de Contexto Completo
# ============================================================================

# Detecta todo o contexto do projeto e popula variáveis globais
# Uso: detect_project_context "/path/to/project"
detect_project_context() {
    local path="${1:-.}"
    
    DETECTED_STACK=$(detect_stack "$path")
    DETECTED_PLATFORM=$(detect_platform)
    DETECTED_LANGUAGE=$(detect_language "$path")
    DETECTED_PROJECT_NAME=$(detect_project_name "$path")
    DETECTED_MATURITY=$(detect_maturity "$path")
    DETECTED_STYLE=$(detect_style "$path")
    
    DETECTED_FRAMEWORK_VERSION=$(detect_framework_version "$path")
    DETECTED_TECH_DEBT=$(detect_technical_debt "$path")
    DETECTED_RUNTIME=$(detect_runtime)
    DETECTED_MCP_COMPATIBILITY=$(detect_mcp_compatibility "$DETECTED_STACK")
    
    print_debug "Stack detectada: $DETECTED_STACK"
    print_debug "Versao Framework: $DETECTED_FRAMEWORK_VERSION"
    print_debug "Maturidade: $DETECTED_MATURITY"
    print_debug "Divida Tecnica: $DETECTED_TECH_DEBT"
    print_debug "Estilo: $DETECTED_STYLE"
    print_debug "Plataforma detectada: $DETECTED_PLATFORM"
    print_debug "Linguagem detectada: $DETECTED_LANGUAGE"
    print_debug "Nome do projeto: $DETECTED_PROJECT_NAME"
    print_debug "Runtime: $DETECTED_RUNTIME"
}

# ============================================================================
# Detecção de Módulos Existentes
# ============================================================================

# Verifica se projeto já tem devorq instalado
# Uso: has_devorq_installed "/path/to/project"
has_devorq_installed() {
    local path="${1:-.}"
    [ -d "$path/.devorq" ]
}

# Lista agentes instalados
# Uso: list_installed_agents "/path/to/project"
list_installed_agents() {
    local path="${1:-.}"
    local agents_dir="$path/.devorq/agents"
    
    if [ -d "$agents_dir" ]; then
        find "$agents_dir" -name "*.md" -exec basename {} .md \;
    fi
}

# Lista skills instaladas
# Uso: list_installed_skills "/path/to/project"
list_installed_skills() {
    local path="${1:-.}"
    local skills_dir="$path/.devorq/skills"
    
    if [ -d "$skills_dir" ]; then
        find "$skills_dir" -name "SKILL.md" -exec dirname {} \; | xargs -I{} basename {}
    fi
}

# ============================================================================
# Detecção de Maturidade e Estilo (Smart Context)
# ============================================================================

# Detecta maturidade do projeto (greenfield vs brownfield)
# Uso: detect_maturity "/path/to/project"
detect_maturity() {
    local path="${1:-.}"
    
    # Se diretorio nao existe, eh greenfield
    if [ ! -d "$path" ]; then
        echo "greenfield"
        return
    fi

    # Se não tem git, assume greenfield se tiver poucos arquivos
    if [ ! -d "$path/.git" ]; then
        local file_count
        file_count=$(find "$path" -maxdepth 2 -type f -not -path '*/.*' 2>/dev/null | wc -l)
        if [ "$file_count" -lt 5 ]; then
            echo "greenfield"
            return
        fi
    fi
    
    # Com git, verifica profundidade do histórico
    if command -v git >/dev/null 2>&1 && [ -d "$path/.git" ]; then
         local commit_count
         commit_count=$(git -C "$path" rev-list --count HEAD 2>/dev/null || echo 0)
         if [ "$commit_count" -lt 10 ]; then
             echo "greenfield"
             return
         fi
    fi
    
    echo "brownfield"
}

# Detecta estilo de código e linters
# Uso: detect_style "/path/to/project"
detect_style() {
    local path="${1:-.}"
    local styles=""
    
    # PHP/Laravel
    [ -f "$path/pint.json" ] && styles="${styles}pint,"
    [ -f "$path/.php-cs-fixer.php" ] && styles="${styles}php-cs-fixer,"
    [ -f "$path/phpcs.xml" ] && styles="${styles}phpcs,"
    
    # JS/TS
    ([ -f "$path/.eslintrc" ] || [ -f "$path/.eslintrc.json" ] || [ -f "$path/.eslintrc.js" ]) && styles="${styles}eslint,"
    ([ -f "$path/.prettierrc" ] || [ -f "$path/prettier.config.js" ]) && styles="${styles}prettier,"
    [ -f "$path/biome.json" ] && styles="${styles}biome,"
    (grep -q "eslintConfig" "$path/package.json" 2>/dev/null) && styles="${styles}eslint,"
    
    # Python
    [ -f "$path/.pylintrc" ] && styles="${styles}pylint,"
    ([ -f "$path/pyproject.toml" ] && grep -q "black" "$path/pyproject.toml" 2>/dev/null) && styles="${styles}black,"
    ([ -f "$path/pyproject.toml" ] && grep -q "ruff" "$path/pyproject.toml" 2>/dev/null) && styles="${styles}ruff,"
    
    # Ruby
    [ -f "$path/.rubocop.yml" ] && styles="${styles}rubocop,"
    
    # Remove vírgula final
    echo "${styles%,}"
}

# ============================================================================
# Smart Context Avançado
# ============================================================================

# Detecta versão do framework principal
# Uso: detect_framework_version "/path/to/project"
detect_framework_version() {
    local path="${1:-.}"
    local version=""
    
    # Laravel
    if [ -f "$path/composer.json" ]; then
        version=$(grep '"laravel/framework":' "$path/composer.json" 2>/dev/null | head -1 | grep -o '[0-9]\+\.[0-9]\+' | head -1)
        if [ -n "$version" ]; then
            echo "Laravel $version"
            return
        fi
    fi
    
    # Next.js / React
    if [ -f "$path/package.json" ]; then
        if grep -q '"next":' "$path/package.json" 2>/dev/null; then
            version=$(grep '"next":' "$path/package.json" 2>/dev/null | head -1 | grep -o '[0-9]\+\.[0-9]\+' | head -1)
            [ -n "$version" ] && echo "Next.js $version" && return
        fi
        
        if grep -q '"react":' "$path/package.json" 2>/dev/null; then
            version=$(grep '"react":' "$path/package.json" 2>/dev/null | head -1 | grep -o '[0-9]\+\.[0-9]\+' | head -1)
            [ -n "$version" ] && echo "React $version" && return
        fi
    fi
    
    # Python - Django/Flask/FastAPI
    if [ -f "$path/requirements.txt" ] || [ -f "$path/pyproject.toml" ]; then
        local file="$path/requirements.txt"
        [ -f "$path/pyproject.toml" ] && file="$path/pyproject.toml"
        
        if grep -q "Django" "$file" 2>/dev/null; then
            version=$(grep -i "Django" "$file" | grep -o '[0-9]\+\.[0-9]\+' | head -1)
            [ -n "$version" ] && echo "Django $version" && return
        fi
    fi
    
    echo "unknown"
}

# Analisa Divida Tecnica e Maturidade Real
# Uso: detect_technical_debt "/path/to/project"
detect_technical_debt() {
    local path="${1:-.}"
    
    local todo_count
    todo_count=$(grep -r "TODO" "$path" 2>/dev/null | grep -v "node_modules" | grep -v "vendor" | wc -l)
    local fixme_count
    fixme_count=$(grep -r "FIXME" "$path" 2>/dev/null | grep -v "node_modules" | grep -v "vendor" | wc -l)
    local has_tests=false
    
    if [ -d "$path/tests" ] || [ -d "$path/__tests__" ] || echo "$path"/*test* >/dev/null 2>&1; then
        has_tests=true
    fi
    
    echo "{\"todos\": $todo_count, \"fixmes\": $fixme_count, \"has_tests\": $has_tests}"
}

# Detecta compatibilidade com servidores MCP baseada na stack
# Uso: detect_mcp_compatibility "laravel"
# Retorna: lista de MCPs compativeis (separados por virgula)
detect_mcp_compatibility() {
    local stack="${1:-$DETECTED_STACK}"
    local mcps=""
    
    case "$stack" in
        laravel|filament|livewire)
            mcps="laravel-boost"
            ;;
        javascript|typescript|nextjs|react|vue|express|node)
            mcps="context7"
            ;;
        python|django|fastapi|flask)
            mcps="context7"
            ;;
    esac
    
    echo "$mcps"
}
# ============================================================================
# Funções migradas de detect.sh (compatibilidade)
# ============================================================================

# Detecção de qual LLM está ativo
detect_llm() {
    # 1. Variáveis de ambiente primárias (mais confiáveis)
    if [[ "$CLAUDECODE" == "1" ]] || [[ "$CLAUDE_CODE_ENTRYPOINT" != "" ]]; then
        echo "claude-code"
        return
    fi

    if [[ "$OPENCODE" == "1" ]] || [[ "$OPENCODE" == "true" ]]; then
        echo "opencode"
        return
    fi

    if [[ "$ANTIGRAVITY" == "true" ]]; then
        echo "antigravity"
        return
    fi

    if [[ "$GEMINI" == "true" ]]; then
        echo "gemini"
        return
    fi

    if [[ "$CLAUDE" == "true" ]]; then
        echo "claude"
        return
    fi

    if [[ "$MINIMAX" == "true" ]]; then
        echo "minimax"
        return
    fi

    # 2. Detecção por $PROMPT (fallback para LLMs sem env dedicada)
    if [[ "$PROMPT" == *"Antigravity"* ]]; then
        echo "antigravity"
        return
    fi

    if [[ "$PROMPT" == *"Gemini"* ]]; then
        echo "gemini"
        return
    fi

    if [[ "$PROMPT" == *"Claude"* ]]; then
        echo "claude"
        return
    fi

    if [[ "$PROMPT" == *"MiniMax"* ]]; then
        echo "minimax"
        return
    fi

    # 3. Verificar CLAUDE_TASK_ID (Claude Code)
    if [ -n "$CLAUDE_TASK_ID" ]; then
        if [[ "$CLAUDE_TASK_ID" == *"antigravity"* ]]; then
            echo "antigravity"
            return
        fi
    fi

    # 4. Fallback: context.json persistido pelo devorq
    local devorq_context="${DEVORQ_DIR:-.devorq}/state/context.json"
    if [ -f "$devorq_context" ]; then
        local llm_from_context
        llm_from_context=$(grep -o '"llm"[[:space:]]*:[[:space:]]*"[^"]*"' "$devorq_context" 2>/dev/null | cut -d'"' -f4)
        if [ -n "$llm_from_context" ] && [[ "$llm_from_context" != "unknown" ]]; then
            echo "$llm_from_context"
            return
        fi
    fi

    # 5. Fallback: session.json
    local devorq_session="${DEVORQ_DIR:-.devorq}/state/session.json"
    if [ -f "$devorq_session" ]; then
        local llm_from_session
        llm_from_session=$(grep -o '"llm"[[:space:]]*:[[:space:]]*"[^"]*"' "$devorq_session" 2>/dev/null | head -1 | cut -d'"' -f4)
        if [ -n "$llm_from_session" ] && [[ "$llm_from_session" != "unknown" ]]; then
            echo "$llm_from_session"
            return
        fi
    fi

    # 6. Fallback: hostname do container (útil em Docker)
    if [ -f "/.dockerenv" ]; then
        if hostname | grep -qi "opencode"; then
            echo "opencode"
            return
        fi
        if hostname | grep -qi "claude"; then
            echo "claude-code"
            return
        fi
    fi

    echo "unknown"
}

# Detecção de tipo de projeto (greenfield vs brownfield)
detect_project_type() {
    local root="${1:-.}"

    # Indicadores de projeto em andamento (brownfield)
    local has_code=false
    [ -d "$root/vendor" ]       && has_code=true
    [ -d "$root/node_modules" ] && has_code=true
    [ -d "$root/app" ]          && has_code=true
    [ -d "$root/src" ]          && has_code=true
    # Projetos Bash/CLI estabelecidos: exige ambos bin/ + lib/ para evitar falso positivo
    { [ -d "$root/bin" ] && [ -d "$root/lib" ]; } && has_code=true

    if [ "$has_code" = true ]; then
        echo "brownfield"
        return
    fi

    echo "greenfield"
}

# Detecção de banco de dados via .env
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

# Verifica se projeto é legado (sem testes ou Laravel < 9)
is_legacy() {
    local root="${1:-.}"

    if [ -d "$root/tests" ]; then
        local test_count
        test_count=$(find "$root/tests" \( -name "*.php" -o -name "*.js" \) 2>/dev/null | wc -l)
        if [ "$test_count" -eq 0 ]; then
            return 0
        fi
    else
        return 0
    fi

    if [ -f "$root/composer.json" ]; then
        local version
        version=$(grep -o '"laravel/framework": "[0-9]*' "$root/composer.json" | grep -o '[0-9]*' | head -1)
        if [ -n "$version" ] && [ "$version" -lt 9 ] 2>/dev/null; then
            return 0
        fi
    fi

    return 1
}

# Verifica existência de PRD no projeto
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

# Verifica se cwd está num repositório git
check_git_repo() {
    if git rev-parse --git-dir > /dev/null 2>&1; then
        echo "true"
    else
        echo "false"
    fi
}

# Retorna branch git atual
get_git_branch() {
    git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown"
}

# Exibe resumo do contexto detectado
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

# ============================================================================
# DETECÇÃO DE CONTEXT-MODE (Modo Monstro)
# ============================================================================

detect_context_mode() {
    local root="${1:-.}"
    local home="${HOME:-/root}"

    if command -v ctx > /dev/null 2>&1; then
        ctx_bin="ctx"
    else
        local ctx_bin_paths=(
            "$home/.nvm/versions/node/v22.22.1/bin/context-mode"
            "$home/.npm-global/bin/context-mode"
            "$home/.local/bin/context-mode"
            "/usr/local/bin/context-mode"
        )
        for bin_path in "${ctx_bin_paths[@]}"; do
            if [ -f "$bin_path" ]; then
                ctx_bin="$bin_path"
                break
            fi
        done
    fi

    [ -z "$ctx_bin" ] && echo "not_installed" && return

    local session_dir="$home/.config/opencode/context-mode/content"
    [ ! -d "$session_dir" ] && echo "no_sessions" && return

    local project_hash
    project_hash=$(echo -n "$(cd "$root" && pwd)" | sha256sum | cut -c1-16)
    local db_path="$session_dir/$project_hash.db"

    if [ -f "$db_path" ]; then
        local db_size
        db_size=$(du -k "$db_path" 2>/dev/null | cut -f1 || echo "0")
        echo "active:$project_hash:$db_size"
    else
        echo "no_session"
    fi
}

# Retorna hash do projeto context-mode atual
get_context_mode_hash() {
    local ctx_status
    ctx_status=$(detect_context_mode "$1")
    if [[ "$ctx_status" == active:* ]]; then
        echo "$ctx_status" | cut -d: -f2
    fi
}

# Retorna tamanho do DB context-mode
get_context_mode_size() {
    local ctx_status
    ctx_status=$(detect_context_mode "$1")
    if [[ "$ctx_status" == active:* ]]; then
        echo "$ctx_status" | cut -d: -f3
    fi
}

# ============================================================================
# FIM DETECÇÃO CONTEXT-MODE
# ============================================================================

export -f detect_llm detect_stack detect_project_type detect_runtime detect_database is_legacy check_prd_exists get_git_branch export_context check_git_repo detect_mcp_compatibility detect_platform detect_language detect_project_name has_devorq_installed list_installed_agents list_installed_skills detect_maturity detect_context_mode get_context_mode_hash get_context_mode_size
