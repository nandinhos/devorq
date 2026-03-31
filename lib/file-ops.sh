#!/bin/bash

# ============================================================================
# AI Dev Superpowers V3 - File Operations Module
# ============================================================================
# Funções para operações de arquivo e diretório
# 
# Uso: source lib/file-ops.sh
# Dependências: lib/core.sh
# ============================================================================

# Variáveis de controle de comportamento
AIDEV_DRY_RUN="${AIDEV_DRY_RUN:-false}"
AIDEV_FORCE="${AIDEV_FORCE:-false}"

# ============================================================================
# Operações de Diretório
# ============================================================================

# Cria diretório se não existir
# Uso: ensure_dir "/path/to/dir"
ensure_dir() {
    local dir="$1"
    
    if [ -z "$dir" ]; then
        print_error "ensure_dir: caminho vazio"
        return 1
    fi
    
    if [ "$AIDEV_DRY_RUN" = "true" ]; then
        print_info "[DRY-RUN] Criaria diretório: $dir"
        return 0
    fi
    
    if [ ! -d "$dir" ]; then
        mkdir -p "$dir"
        increment_dirs
        print_debug "Diretório criado: $dir"
    fi
}

# Alias para ensure_dir
create_dir() {
    ensure_dir "$@"
}

# Verifica se diretório existe
# Uso: dir_exists "/path/to/dir" && echo "existe"
dir_exists() {
    [ -d "$1" ]
}

# ============================================================================
# Operações de Arquivo
# ============================================================================

# Escreve conteúdo em arquivo, respeitando flags de controle
# Uso: write_file "/path/to/file" "conteúdo"
write_file() {
    local file="$1"
    local content="$2"
    
    if [ -z "$file" ]; then
        print_error "write_file: caminho vazio"
        return 1
    fi
    
    if [ "$AIDEV_DRY_RUN" = "true" ]; then
        print_info "[DRY-RUN] Criaria arquivo: $file"
        return 0
    fi
    
    if [ -f "$file" ] && [ "$AIDEV_FORCE" = "false" ]; then
        print_warning "Arquivo existe (use --force): $file"
        return 0
    fi
    
    # Garante que o diretório pai existe
    ensure_dir "$(dirname "$file")"
    
    # Escreve conteúdo
    echo "$content" > "$file"
    increment_files
    print_debug "Arquivo criado: $file"
}

# Escreve conteúdo sem newline final (para templates precisos)
# Uso: write_file_exact "/path/to/file" "conteúdo"
write_file_exact() {
    local file="$1"
    local content="$2"
    
    if [ -z "$file" ]; then
        print_error "write_file_exact: caminho vazio"
        return 1
    fi
    
    if [ "$AIDEV_DRY_RUN" = "true" ]; then
        print_info "[DRY-RUN] Criaria arquivo: $file"
        return 0
    fi
    
    if [ -f "$file" ] && [ "$AIDEV_FORCE" = "false" ]; then
        print_warning "Arquivo existe (use --force): $file"
        return 0
    fi
    
    ensure_dir "$(dirname "$file")"
    printf '%s' "$content" > "$file"
    increment_files
}

# Verifica se arquivo existe
# Uso: file_exists "/path/to/file" && echo "existe"
file_exists() {
    [ -f "$1" ]
}

# Faz backup de arquivo existente
# Uso: backup_file "/path/to/file"
backup_file() {
    local file="$1"
    local backup="${file}.bak.$(date +%Y%m%d%H%M%S)"
    
    if [ -f "$file" ]; then
        if [ "$AIDEV_DRY_RUN" = "true" ]; then
            print_info "[DRY-RUN] Faria backup: $file -> $backup"
            return 0
        fi
        cp "$file" "$backup"
        print_info "Backup criado: $backup"
    fi
}

# Verifica se arquivo é gravável
# Uso: is_writable "/path/to/file" && echo "gravável"
is_writable() {
    local path="$1"
    
    if [ -e "$path" ]; then
        [ -w "$path" ]
    else
        [ -w "$(dirname "$path")" ]
    fi
}

# Determina se deve escrever arquivo (lógica de conflito)
# Uso: should_write_file "/path" && write_file "$path" "content"
# Com upgrade module: delega para upgrade_should_overwrite (checksum + manifesto)
# Sem upgrade module: fallback para logica original (existencia + force)
should_write_file() {
    local file="$1"

    # Em modo dry-run, apenas simula
    if [ "$AIDEV_DRY_RUN" = "true" ]; then
        print_info "[DRY-RUN] Verificaria arquivo: $file"
        return 1  # Não escreve em dry-run
    fi

    # Se upgrade module esta disponivel, delegar decisao
    if type upgrade_should_overwrite &>/dev/null 2>&1; then
        local project_root="${AIDEV_PROJECT_ROOT:-$(pwd)}"
        upgrade_should_overwrite "$file" "$project_root"
        return $?
    fi

    # Fallback: logica original
    if [ ! -f "$file" ]; then
        return 0  # Não existe, pode escrever
    fi

    if [ "$AIDEV_FORCE" = "true" ]; then
        return 0  # Force está ativo
    fi

    return 1  # Existe e force não está ativo
}

# ============================================================================
# Operações de Cópia
# ============================================================================

# Copia arquivo com verificação
# Uso: copy_file "origem" "destino"
copy_file() {
    local src="$1"
    local dest="$2"
    
    if [ ! -f "$src" ]; then
        print_error "Arquivo origem não existe: $src"
        return 1
    fi
    
    if [ "$AIDEV_DRY_RUN" = "true" ]; then
        print_info "[DRY-RUN] Copiaria: $src -> $dest"
        return 0
    fi
    
    ensure_dir "$(dirname "$dest")"
    cp "$src" "$dest"
    increment_files
}

# ============================================================================
# Leitura de Arquivo
# ============================================================================

# Lê conteúdo de arquivo
# Uso: content=$(read_file "/path/to/file")
read_file() {
    local file="$1"
    
    if [ -f "$file" ]; then
        cat "$file"
    else
        echo ""
    fi
}

# Lê primeira linha de arquivo
# Uso: first_line=$(read_first_line "/path/to/file")
read_first_line() {
    local file="$1"
    
    if [ -f "$file" ]; then
        head -n 1 "$file"
    else
        echo ""
    fi
}
