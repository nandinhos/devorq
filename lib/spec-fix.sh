#!/bin/bash

# ============================================================================
# DEVORQ - Spec Fix Module
# ============================================================================
# Sistema de auto-correção de specs com detecção de tipo e rollback
#
# Uso: source lib/spec-fix.sh
# ============================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "ERRO: Este módulo deve ser carregado via 'source', não executado." >&2
    exit 1
fi

# ----------------------------------------------------------------------------
# CONSTANTES
# ----------------------------------------------------------------------------

readonly SPEC_FIX_BACKUP_DIR="${DEVORQ_ROOT_DIR:-.devorq}/backups"

readonly VALID_DOMAINS="arquitetura|importacao|ui_ux|refactor|seguranca|operacao"
readonly VALID_PRIORITIES="low|medium|high|critical"
readonly VALID_STATUSES="backlog|brainstorming|draft|approved|planning|in_progress|validated|implemented|blocked|archived"

readonly REQUIRED_SPEC_FIELDS=(id title domain status priority owner created_at updated_at source related_tasks related_files)
readonly REQUIRED_LESSON_FIELDS=(id title skill_target status created_at)

declare -A FIELD_DEFAULTS=(
    ["domain"]="arquitetura"
    ["priority"]="medium"
    ["owner"]="team-core"
    ["source"]="manual"
)
readonly FIELD_DEFAULTS

# ----------------------------------------------------------------------------
# HELPERS
# ----------------------------------------------------------------------------

spec_fix_log() {
    echo "[SPEC-FIX] $1"
}

spec_fix_error() {
    echo "[SPEC-FIX] ERRO: $1" >&2
}

# ----------------------------------------------------------------------------
# DETECÇÃO DE TIPO (SPEC vs LESSON)
# ----------------------------------------------------------------------------

detect_artifact_type() {
    local file="$1"
    local type="unknown"

    if grep -q "^id: SPEC-" "$file" 2>/dev/null; then
        type="spec"
    elif grep -q "^id: LESSON-" "$file" 2>/dev/null; then
        type="lesson"
    elif grep -q "^skill_target:" "$file" 2>/dev/null; then
        type="lesson"
    elif grep -q "^# Lição" "$file" 2>/dev/null; then
        type="lesson"
    elif grep -qE "^# (Spec|Proposta)" "$file" 2>/dev/null; then
        type="spec"
    elif [[ "$file" =~ /lessons-(learned|pending|validated|applied)/ ]]; then
        type="lesson"
    elif [[ "$file" =~ /docs/specs/ ]]; then
        type="spec"
    fi

    echo "$type"
}

# ----------------------------------------------------------------------------
# EXTRAÇÃO DE CAMPOS
# ----------------------------------------------------------------------------

extract_field() {
    local file="$1"
    local field="$2"
    awk -v field="${field}" '
        /^---$/ { n++; next }
        n == 1 && $0 ~ "^" field ":[[:space:]]*" {
            sub("^" field ":[[:space:]]*", "")
            print
            exit
        }
        n >= 2 { exit }
    ' "$file" 2>/dev/null | xargs
}

extract_first_heading() {
    local file="$1"
    grep -m1 "^# " "$file" 2>/dev/null | sed 's/^# //' | xargs
}

# ----------------------------------------------------------------------------
# VALIDAÇÃO DE ID
# ----------------------------------------------------------------------------

validate_spec_id() {
    local id="$1"
    [[ "$id" =~ ^SPEC-[0-9]{4}-[0-9]{2}-[0-9]{2}-.*$ ]]
}

is_old_spec_pattern() {
    local id="$1"
    [[ "$id" =~ ^SPEC-[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{3}$ ]]
}

# ----------------------------------------------------------------------------
# GERAÇÃO DE ID CANÔNICO
# ----------------------------------------------------------------------------

get_next_spec_number() {
    local specs_dir="${1:-$DEVORQ_ROOT_DIR/docs/specs}"
    local max_num=0

    shopt -s globstar 2>/dev/null || true
    for spec_file in "$specs_dir"/**/*.md; do
        [ -f "$spec_file" ] || continue
        [ "$(basename "$spec_file")" = "_index.md" ] && continue

        local spec_id
        spec_id=$(extract_field "$spec_file" "id")

        if ! validate_spec_id "$spec_id"; then
            continue
        fi

        local num=""
        if [[ "$spec_id" =~ ^SPEC-([0-9]{4})- ]]; then
            num="${BASH_REMATCH[1]}"
        fi

        if [ -n "$num" ] && [ "$num" -gt "$max_num" ]; then
            max_num="$num"
        fi
    done

    printf "%04d" $((10#$max_num + 1))
}

generate_canonical_id() {
    local current_id="$1"
    local title="$2"
    local specs_dir="${3:-$DEVORQ_ROOT_DIR/docs/specs}"

    local new_num
    new_num=$(get_next_spec_number "$specs_dir")

    local date_part=""
    if [[ "$current_id" =~ [0-9]{2}-[0-9]{2}-[0-9]{4} ]]; then
        date_part="${BASH_REMATCH[0]}"
    else
        date_part=$(date +"%d-%m-%Y")
    fi

    local slug=""
    if [ -n "$title" ]; then
        slug=$(echo "$title" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9 ]//g' | tr ' ' '-' | cut -c1-40)
    fi

    echo "SPEC-${new_num}-${date_part}${slug:+-$slug}"
}

check_id_collision() {
    local new_id="$1"
    local specs_dir="${2:-$DEVORQ_ROOT_DIR/docs/specs}"

    shopt -s globstar 2>/dev/null || true
    for spec_file in "$specs_dir"/**/*.md; do
        [ -f "$spec_file" ] || continue
        [ "$(basename "$spec_file")" = "_index.md" ] && continue

        local existing_id
        existing_id=$(extract_field "$spec_file" "id")

        if [[ "$existing_id" == "$new_id" ]]; then
            return 1
        fi
    done
    return 0
}

# ----------------------------------------------------------------------------
# DETECÇÃO DE PROBLEMAS
# ----------------------------------------------------------------------------

get_missing_fields() {
    local file="$1"
    local type="$2"
    local missing=""

    if [[ "$type" == "spec" ]]; then
        for field in "${REQUIRED_SPEC_FIELDS[@]}"; do
            local value
            value=$(extract_field "$file" "$field")
            if [ -z "$value" ]; then
                [ -n "$missing" ] && missing="$missing,"
                missing="$missing$field"
            fi
        done
    elif [[ "$type" == "lesson" ]]; then
        for field in "${REQUIRED_LESSON_FIELDS[@]}"; do
            local value
            value=$(extract_field "$file" "$field")
            if [ -z "$value" ]; then
                [ -n "$missing" ] && missing="$missing,"
                missing="$missing$field"
            fi
        done
    fi

    echo "${missing:-}"
}

detect_pipe_literals() {
    local file="$1"
    local field="$2"
    local value
    value=$(extract_field "$file" "$field")

    if [[ "$value" =~ \| ]]; then
        echo "$value"
        return 0
    fi
    return 1
}

check_status_directory_mismatch() {
    local file="$1"
    local specs_dir="$2"

    local status
    status=$(extract_field "$file" "status")

    if [ -z "$status" ]; then
        return 1
    fi

    local expected_dir="$specs_dir/$status"
    local actual_dir
    actual_dir=$(readlink -f "$(dirname "$file")")

    if [[ "$expected_dir" != "$actual_dir" ]]; then
        echo "$expected_dir"
        return 0
    fi
    return 1
}

detect_cross_contamination() {
    local file="$1"
    local type="$2"

    if [[ "$type" == "lesson" ]] && [[ "$file" =~ /docs/specs/ ]]; then
        echo "LESSON_IN_SPECS"
    elif [[ "$type" == "spec" ]] && [[ "$file" =~ /lessons- ]]; then
        echo "SPEC_IN_LESSONS"
    else
        echo ""
    fi
}

# ----------------------------------------------------------------------------
# OPERAÇÕES DE CORREÇÃO
# ----------------------------------------------------------------------------

spec_fix_add_fields() {
    local file="$1"
    local type="$2"

    if [[ "$type" != "spec" ]]; then
        return 0
    fi

    for field in domain priority owner source related_tasks related_files; do
        local current
        current=$(extract_field "$file" "$field")

        if [ -z "$current" ]; then
            local default="${FIELD_DEFAULTS[$field]:-}"
            if [ -n "$default" ]; then
                awk -v field="$field" -v value="$default" '
                    BEGIN { in_fm = 0 }
                    /^---$/ {
                        if (in_fm == 0) {
                            in_fm = 1
                            print
                            next
                        } else {
                            print field ": " value
                            print
                            next
                        }
                    }
                    in_fm == 1 { print; next }
                    { print }
                ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
                spec_fix_log "  + Adicionado $field: $default"
            fi
        fi
    done
}

spec_fix_fix_pipe() {
    local file="$1"

    local domain_value
    domain_value=$(extract_field "$file" "domain")

    if [[ "$domain_value" =~ \| ]]; then
        local first_value
        first_value=$(echo "$domain_value" | cut -d'|' -f1 | xargs)
        awk -v value="$first_value" '
            /^---$/ { n++; next }
            n == 1 && /^domain:/ {
                print "domain: " value
                next
            }
            { print }
        ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
        spec_fix_log "  + Fix pipe literal: domain = $first_value"
        return 0
    fi
    return 1
}

spec_fix_update_id() {
    local file="$1"
    local new_id="$2"

    awk -v new_id="$new_id" '
        /^---$/ { n++; next }
        n == 1 && /^id:/ {
            print "id: " new_id
            next
        }
        { print }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
    spec_fix_log "  + ID atualizado para: $new_id"
}

spec_fix_update_status() {
    local file="$1"
    local new_status="$2"

    awk -v status="$new_status" '
        /^---$/ { n++; next }
        n == 1 && /^status:/ {
            print "status: " status
            next
        }
        { print }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
    spec_fix_log "  + Status atualizado para: $new_status"
}

spec_fix_update_timestamp() {
    local file="$1"
    local timestamp
    timestamp=$(date +"%Y-%m-%d")

    awk -v ts="$timestamp" '
        /^---$/ { n++; next }
        n == 1 && /^updated_at:/ {
            print "updated_at: " ts
            next
        }
        { print }
    ' "$file" > "${file}.tmp" && mv "${file}.tmp" "$file"
}

spec_fix_rename_file() {
    local file="$1"
    local new_name="$2"
    local base_dir
    base_dir=$(dirname "$file")

    local new_path="$base_dir/$new_name"
    if [ -f "$new_path" ]; then
        spec_fix_error "Arquivo já existe: $new_path"
        return 1
    fi

    mv "$file" "$new_path"
    spec_fix_log "  + Renomeado para: $new_name"
    echo "$new_path"
}

spec_fix_move_file() {
    local file="$1"
    local new_dir="$2"

    if [ ! -d "$new_dir" ]; then
        mkdir -p "$new_dir"
    fi

    local base_name
    base_name=$(basename "$file")
    local new_path="$new_dir/$base_name"

    if [ -f "$new_path" ]; then
        spec_fix_error "Arquivo já existe no destino: $new_path"
        return 1
    fi

    mv "$file" "$new_path"
    spec_fix_log "  + Movido para: $new_dir"
    echo "$new_path"
}

spec_fix_reclassify() {
    local file="$1"
    local from_type="$2"
    local devorq_root="${3:-$DEVORQ_ROOT_DIR}"

    if [[ "$from_type" == "lesson" ]]; then
        local new_dir="$devorq_root/.devorq/state/lessons-pending"
        spec_fix_move_file "$file" "$new_dir"
    elif [[ "$from_type" == "spec" ]]; then
        local new_dir="$devorq_root/docs/specs/draft"
        spec_fix_move_file "$file" "$new_dir"
        spec_fix_update_status "$file" "draft"
    fi
}

# ----------------------------------------------------------------------------
# BACKUP E ROLLBACK
# ----------------------------------------------------------------------------

spec_fix_backup() {
    local file="$1"
    local backup_type="${2:-full}"

    local timestamp
    timestamp=$(date +"%Y-%m-%d_%H-%M-%S")

    local backup_dir="$SPEC_FIX_BACKUP_DIR/$timestamp"
    mkdir -p "$backup_dir"

    cp "$file" "$backup_dir/"
    spec_fix_log "  + Backup criado: $backup_dir/$(basename "$file")"

    echo "$backup_dir"
}

spec_fix_backup_all() {
    local files=("$@")
    local timestamp
    timestamp=$(date +"%Y-%m-%d_%H-%M-%S")

    local backup_dir="$SPEC_FIX_BACKUP_DIR/$timestamp"
    mkdir -p "$backup_dir"

    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            cp "$file" "$backup_dir/"
        fi
    done

    spec_fix_log "Backup em massa: $backup_dir ($((${#files[@]})) arquivos)"
    echo "$backup_dir"
}

spec_fix_rollback() {
    local backup_dir="$1"
    local devorq_root="${2:-$DEVORQ_ROOT_DIR}"

    spec_fix_error "ROLLBACK: Restaurando arquivos..."

    if [ -d "$backup_dir" ]; then
        for backup_file in "$backup_dir"/*.md; do
            if [ -f "$backup_file" ]; then
                local base_name
                base_name=$(basename "$backup_file")

                find "$devorq_root" -name "$base_name" -type f 2>/dev/null | while read -r original_file; do
                    cp "$backup_file" "$original_file"
                    spec_fix_log "  + Restaurado: $original_file"
                done
            fi
        done
        spec_fix_error "Rollback concluído."
    fi
}

# ----------------------------------------------------------------------------
# ANÁLISE DE ARQUIVO
# ----------------------------------------------------------------------------

analyze_spec_file() {
    local file="$1"
    local specs_dir="$2"
    local devorq_root="${3:-$DEVORQ_ROOT_DIR}"

    local type
    type=$(detect_artifact_type "$file")

    if [[ "$type" == "unknown" ]]; then
        return 1
    fi

    local issues=()
    local operations=()

    local current_id
    current_id=$(extract_field "$file" "id")

    if [[ "$type" == "spec" ]]; then
        if ! validate_spec_id "$current_id"; then
            issues+=("ID não-canônico: $current_id")
            operations+=("RENAME_ID")
        elif is_old_spec_pattern "$current_id"; then
            issues+=("ID formato antigo: $current_id")
            operations+=("RENAME_ID")
        fi

        local missing
        missing=$(get_missing_fields "$file" "$type")
        if [ -n "$missing" ]; then
            issues+=("Campos ausentes: $missing")
            operations+=("ADD_FIELDS")
        fi

        if detect_pipe_literals "$file" "domain"; then
            issues+=("Pipe literal em domain")
            operations+=("FIX_PIPE")
        fi

        local expected_dir
        if check_status_directory_mismatch "$file" "$specs_dir" >/dev/null; then
            expected_dir=$(check_status_directory_mismatch "$file" "$specs_dir")
            issues+=("Status ≠ diretório (esperado: $expected_dir)")
            operations+=("MOVE_FILE")
        fi

        local cross
        cross=$(detect_cross_contamination "$file" "$type")
        if [ -n "$cross" ]; then
            issues+=("Cross-contamination: $cross")
            operations+=("RECLASSIFY")
        fi
    fi

    if [[ "$type" == "lesson" ]]; then
        local cross
        cross=$(detect_cross_contamination "$file" "$type")
        if [ -n "$cross" ]; then
            issues+=("Cross-contamination: $cross")
            operations+=("RECLASSIFY")
        fi
    fi

    if [ ${#issues[@]} -eq 0 ]; then
        return 1
    fi

    echo "$type|${issues[*]}|${operations[*]}"
}

# ----------------------------------------------------------------------------
# DRY RUN
# ----------------------------------------------------------------------------

spec_fix_dry_run() {
    local devorq_root="${1:-$DEVORQ_ROOT_DIR}"
    local specs_dir="$devorq_root/docs/specs"

    echo "=== SPEC FIX — DRY RUN ==="
    echo ""

    local total_issues=0
    local files_to_fix=()

    shopt -s globstar 2>/dev/null || true

    for f in "$specs_dir"/**/SPEC-*.md "$devorq_root"/.devorq/state/lessons-*/**/*.md; do
        [ -f "$f" ] || continue
        [ "$(basename "$f")" == "_index.md" ] && continue

        local result
        result=$(analyze_spec_file "$f" "$specs_dir" "$devorq_root" 2>&1) || true

        if [ -n "$result" ]; then
            ((total_issues++)) || true
            files_to_fix+=("$f")

            IFS='|' read -r type issues ops <<< "$result"

            echo "$(basename "$f"):"
            echo "  Tipo: $type"
            echo "  ✗ $issues"
            echo "  Operações: ${ops// /, }"
            echo ""
        fi
    done

    echo "---"
    echo "Total: $total_issues arquivo(s) com problema(s)"
    echo ""
    echo "Para corrigir automaticamente, execute:"
    echo "  ./bin/devorq spec fix --force"
}

# ----------------------------------------------------------------------------
# EXECUÇÃO COM CONFIRMAÇÃO
# ----------------------------------------------------------------------------

spec_fix_execute() {
    local devorq_root="${1:-$DEVORQ_ROOT_DIR}"
    local specs_dir="$devorq_root/docs/specs"
    local dry_run="${2:-false}"

    echo "=== SPEC FIX — EXECUÇÃO ==="
    echo ""

    local files_to_fix=()
    local all_operations=()
    local files_backup=()

    shopt -s globstar 2>/dev/null || true

    for f in "$specs_dir"/**/SPEC-*.md "$devorq_root"/.devorq/state/lessons-*/**/*.md; do
        [ -f "$f" ] || continue
        [ "$(basename "$f")" == "_index.md" ] && continue

        local result
        result=$(analyze_spec_file "$f" "$specs_dir" "$devorq_root")

        if [ $? -eq 0 ]; then
            files_to_fix+=("$f")
        fi
    done

    if [ ${#files_to_fix[@]} -eq 0 ]; then
        echo "Nenhum problema encontrado."
        return 0
    fi

    if [[ "$dry_run" == "false" ]]; then
        local timestamp
        timestamp=$(date +"%Y-%m-%d_%H-%M-%S")
        local backup_dir="$SPEC_FIX_BACKUP_DIR/$timestamp"
        mkdir -p "$backup_dir"

        echo "Backup será salvo em: $backup_dir"
        echo ""
    fi

    for file in "${files_to_fix[@]}"; do
        local result
        result=$(analyze_spec_file "$file" "$specs_dir" "$devorq_root")
        IFS='|' read -r type issues ops <<< "$result"

        echo "$(basename "$file"):"
        echo "  Tipo: $type"

        local ops_list=($ops)
        for op in "${ops_list[@]}"; do
            case "$op" in
                RENAME_ID)
                    echo "  ✗ RENAME_ID: Gerar novo ID canônico"
                    ;;
                ADD_FIELDS)
                    local missing=$(get_missing_fields "$file" "$type")
                    echo "  ✗ ADD_FIELDS: $missing"
                    ;;
                FIX_PIPE)
                    local pipe_val
                    pipe_val=$(detect_pipe_literals "$file" "domain")
                    echo "  ✗ FIX_PIPE: domain '$pipe_val'"
                    ;;
                MOVE_FILE)
                    local expected
                    expected=$(check_status_directory_mismatch "$file" "$specs_dir")
                    echo "  ✗ MOVE_FILE: → $expected"
                    ;;
                RECLASSIFY)
                    local cross
                    cross=$(detect_cross_contamination "$file" "$type")
                    echo "  ✗ RECLASSIFY: $cross"
                    ;;
            esac
        done
        echo ""
    done

    if [[ "$dry_run" == "true" ]]; then
        echo "DRY-RUN: Nenhuma modificação realizada."
        return 0
    fi

    echo "Deseja aplicar estas correções? [y/N]"
    read -r confirm

    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo "Operação cancelada."
        return 1
    fi

    local failed=0
    local backup_created=""

    for file in "${files_to_fix[@]}"; do
        local result
        result=$(analyze_spec_file "$file" "$specs_dir" "$devorq_root")
        IFS='|' read -r type issues ops <<< "$result"

        if [ -z "$backup_created" ]; then
            backup_created=$(spec_fix_backup_all "${files_to_fix[@]}" 2>/dev/null)
        fi

        echo ""
        echo "Processando: $(basename "$file")"

        local ops_list=($ops)
        local current_file="$file"
        local need_backup=1

        for op in "${ops_list[@]}"; do
            echo -n "  Aplicar $op? [y/N] "
            read -r op_confirm

            if [[ "$op_confirm" != "y" && "$op_confirm" != "Y" ]]; then
                continue
            fi

            case "$op" in
                RENAME_ID)
                    if [[ "$type" == "spec" ]]; then
                        local title
                        title=$(extract_first_heading "$current_file")
                        local new_id
                        new_id=$(generate_canonical_id "$(extract_field "$current_file" "id")" "$title" "$specs_dir")

                        if ! check_id_collision "$new_id" "$specs_dir"; then
                            new_id=$(generate_canonical_id "" "$title" "$specs_dir")
                        fi

                        spec_fix_update_id "$current_file" "$new_id"
                    fi
                    ;;
                ADD_FIELDS)
                    spec_fix_add_fields "$current_file" "$type"
                    ;;
                FIX_PIPE)
                    spec_fix_fix_pipe "$current_file"
                    ;;
                MOVE_FILE)
                    local expected_dir
                    expected_dir=$(check_status_directory_mismatch "$current_file" "$specs_dir")
                    if [ -n "$expected_dir" ]; then
                        current_file=$(spec_fix_move_file "$current_file" "$expected_dir")
                    fi
                    ;;
                RECLASSIFY)
                    spec_fix_reclassify "$current_file" "$type" "$devorq_root"
                    current_file=""
                    break
                    ;;
            esac
        done

        if [ -n "$current_file" ] && [ -f "$current_file" ]; then
            spec_fix_update_timestamp "$current_file"
        fi

        if [ $? -ne 0 ]; then
            ((failed++))
            spec_fix_error "Falha ao processar: $(basename "$file")"
        fi
    done

    echo ""
    if [ $failed -gt 0 ]; then
        spec_fix_error "$failed arquivo(s) falharam. Rollback disponível em: $backup_created"
        spec_fix_rollback "$backup_created" "$devorq_root"
        return 1
    fi

    echo "Correções aplicadas com sucesso!"
    echo "Backup em: $backup_created"

    if [ -f "$devorq_root/bin/spec-index" ]; then
        echo ""
        echo "Atualizando índice..."
        "$devorq_root/bin/spec-index"
    fi

    return 0
}
