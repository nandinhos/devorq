#!/bin/bash

# ============================================================================
# AI Dev Superpowers V3 - Feature Lifecycle CLI Module
# ============================================================================
# Automatiza transições do fluxo: backlog → features → current → history
# Comandos: aidev plan | aidev start | aidev done | aidev complete
# ============================================================================

_SCRIPT_DIR_FLC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Diretórios (relativos ao CWD do projeto)
_FLC_BACKLOG_DIR="${FLC_BACKLOG_DIR:-.aidev/plans/backlog}"
_FLC_BRAINSTORM_DIR="${FLC_BRAINSTORM_DIR:-.aidev/plans/brainstorm}"
_FLC_FEATURES_DIR="${FLC_FEATURES_DIR:-.aidev/plans/features}"
_FLC_CURRENT_DIR="${FLC_CURRENT_DIR:-.aidev/plans/current}"
_FLC_HISTORY_DIR="${FLC_HISTORY_DIR:-.aidev/plans/history}"
_FLC_ROADMAP="${FLC_ROADMAP:-.aidev/plans/ROADMAP.md}"
_FLC_CHECKPOINTS_DIR="${FLC_CHECKPOINTS_DIR:-.aidev/state/sprints/current/checkpoints}"
_FLC_CHECKPOINTS_MAX="${FLC_CHECKPOINTS_MAX:-5}"

# ============================================================================
# UTILITÁRIOS INTERNOS
# ============================================================================

_flc_log() {
    local level="$1" msg="$2"
    echo "[$level] flc: $msg" >&2
}

# Converte título para kebab-case seguro
_flc_safe_name() {
    local title="$1"
    echo "$title" \
        | tr '[:upper:]' '[:lower:]' \
        | iconv -f utf-8 -t ascii//TRANSLIT 2>/dev/null \
        | sed 's/[^a-z0-9]/-/g; s/--*/-/g; s/^-//; s/-$//'
}

# Garante que o módulo de checkpoint está carregado
_flc_load_checkpoint() {
    type ckpt_create &>/dev/null && return 0
    local ckpt_lib
    ckpt_lib="$(dirname "$_SCRIPT_DIR_FLC")/../lib/checkpoint-manager.sh"
    [ -f "$ckpt_lib" ] || ckpt_lib="$_SCRIPT_DIR_FLC/checkpoint-manager.sh"
    source "$ckpt_lib" 2>/dev/null || true
}

# Executa git add nos arquivos afetados e exibe diff staged
_flc_stage_and_show() {
    local files=("$@")
    local staged=0
    for f in "${files[@]}"; do
        if [ -f "$f" ] || [ ! -e "$f" ]; then
            git add "$f" 2>/dev/null && ((staged++)) || true
        fi
    done
    if [ "$staged" -gt 0 ]; then
        echo ""
        print_section "Alteracoes preparadas para commit (git diff --staged)"
        git diff --staged --stat 2>/dev/null || true
        echo ""
        print_info "Revise e execute 'git commit' quando validado."
    fi
}

# ============================================================================
# flc_plan_create <titulo>
# Cria novo item de backlog com template padronizado
# ============================================================================
flc_plan_create() {
    local title="$1"
    [ -z "$title" ] && { print_error "Titulo obrigatorio"; return 1; }

    local safe_name
    safe_name=$(_flc_safe_name "$title")
    local date_prefix
    date_prefix=$(date +%Y-%m-%d)
    local dest_dir="$_FLC_BACKLOG_DIR"
    local dest_file="$dest_dir/${safe_name}.md"

    mkdir -p "$dest_dir"

    if [ -f "$dest_file" ]; then
        print_warning "Backlog '$safe_name' ja existe em $dest_file"
        return 0
    fi

    cat > "$dest_file" <<EOF
# Ideia: $title

**Status:** Ideia
**Prioridade:** Media
**Criado:** $date_prefix

---

## Problema

<!-- Descreva o problema ou necessidade que esta feature resolve -->

## Objetivo

<!-- O que queremos alcançar com esta feature -->

## Comportamento Desejado

<!-- Como o sistema deve se comportar após a implementação -->

## Criterios de Aceite

- [ ] <!-- Criterio 1 -->
- [ ] <!-- Criterio 2 -->

## Dependencias

<!-- Outras features ou módulos necessários -->

## Estimativa Preliminar

~N sprints de ~Xmin cada

## Prioridade

**MEDIA** — descrever impacto aqui

**Proximo passo:** Detalhar plano e mover para features/ quando priorizada.
EOF

    print_success "Backlog criado: $dest_file"
    print_info "Proximo passo: detalhe o plano e mova para features/ quando priorizada."

    _flc_stage_and_show "$dest_file"
}

# ============================================================================
# flc_feature_start <feature-id>
# Move features/<id>.md → current/<id>.md
# Valida que current/ só tem 1 feature ativa
# Atualiza READMEs + gera checkpoint
# ============================================================================
flc_feature_start() {
    local feature_id="$1"
    [ -z "$feature_id" ] && { print_error "feature-id obrigatorio"; return 1; }

    local safe_name
    safe_name=$(_flc_safe_name "$feature_id")

    # Busca o arquivo em features/ (por nome exato ou parcial)
    local source_file
    source_file=$(find "$_FLC_FEATURES_DIR" -name "${safe_name}.md" 2>/dev/null | head -1)
    [ -z "$source_file" ] && source_file=$(find "$_FLC_FEATURES_DIR" -name "*${safe_name}*.md" 2>/dev/null | head -1)

    # Gate: se não está em features/, verifica se está em brainstorm/ ou backlog/ e bloqueia
    if [ -z "$source_file" ] || [ ! -f "$source_file" ]; then
        local brainstorm_file
        brainstorm_file=$(find "$_FLC_BRAINSTORM_DIR" -name "${safe_name}.md" 2>/dev/null | head -1)
        [ -z "$brainstorm_file" ] && brainstorm_file=$(find "$_FLC_BRAINSTORM_DIR" -name "*${safe_name}*.md" 2>/dev/null | head -1)

        if [ -n "$brainstorm_file" ] && [ -f "$brainstorm_file" ]; then
            print_error "Feature '$feature_id' esta em brainstorm/ e ainda nao foi promovida a features/."
            print_info "Execute primeiro: aidev create-feature $feature_id"
            print_info "Isso converte o brainstorm em plano detalhado com sprints definidos."
            return 1
        fi

        local backlog_file
        backlog_file=$(find "$_FLC_BACKLOG_DIR" -name "${safe_name}.md" 2>/dev/null | head -1)
        [ -z "$backlog_file" ] && backlog_file=$(find "$_FLC_BACKLOG_DIR" -name "*${safe_name}*.md" 2>/dev/null | head -1)

        if [ -n "$backlog_file" ] && [ -f "$backlog_file" ]; then
            print_error "Feature '$feature_id' esta em backlog/ e ainda nao passou por brainstorm."
            print_info "Execute: aidev brainstorm $feature_id"
            print_info "Ou refine diretamente: aidev refine $feature_id"
            return 1
        fi
    fi

    if [ -z "$source_file" ] || [ ! -f "$source_file" ]; then
        print_error "Feature nao encontrada em features/ nem em backlog/: $feature_id"
        print_info "Arquivos disponíveis:"
        ls "$_FLC_FEATURES_DIR"/*.md 2>/dev/null | xargs -n1 basename 2>/dev/null | grep -v README || \
            print_info "  (nenhuma feature em features/)"
        ls "$_FLC_BACKLOG_DIR"/*.md 2>/dev/null | xargs -n1 basename 2>/dev/null | grep -v README || \
            print_info "  (nenhuma feature em backlog/)"
        return 1
    fi

    # Verifica unicidade em current/
    local active_features
    active_features=$(find "$_FLC_CURRENT_DIR" -name "*.md" ! -name "README.md" 2>/dev/null | wc -l)
    if [ "$active_features" -gt 0 ]; then
        local active_name
        active_name=$(find "$_FLC_CURRENT_DIR" -name "*.md" ! -name "README.md" 2>/dev/null | head -1 | xargs basename)
        print_error "Ja existe uma feature ativa em current/: $active_name"
        print_info "Execute 'aidev complete <id>' para finalizar antes de iniciar nova."
        return 1
    fi

    local feature_basename
    feature_basename=$(basename "$source_file")
    local dest_file="$_FLC_CURRENT_DIR/$feature_basename"

    mkdir -p "$_FLC_CURRENT_DIR"
    mv "$source_file" "$dest_file"

    # Extrai título do arquivo
    local feature_title
    feature_title=$(grep "^# " "$dest_file" | head -1 | sed 's/^# //')
    [ -z "$feature_title" ] && feature_title="$feature_id"

    # Atualiza current/README.md
    _flc_update_current_readme "$feature_basename" "$feature_title"

    # Atualiza features/README.md
    _flc_update_features_readme_start "$feature_basename" "$feature_title"

    print_success "Feature iniciada: $feature_title"
    print_info "Arquivo: current/$feature_basename"

    # Checkpoint automático
    _flc_load_checkpoint
    if type ckpt_create &>/dev/null; then
        ckpt_create "." "task_started" "Feature iniciada: $feature_id - $feature_title" 2>/dev/null || true
    fi

    _flc_stage_and_show "$dest_file" "$_FLC_CURRENT_DIR/README.md" "$_FLC_FEATURES_DIR/README.md"
}

# Atualiza current/README.md com tabela de sprints (baseada no arquivo da feature)
_flc_update_current_readme() {
    local feature_file="$1"
    local feature_title="$2"
    local readme="$_FLC_CURRENT_DIR/README.md"
    local started_date
    started_date=$(date +%Y-%m-%d)

    # Extrai sprints do arquivo da feature (linhas de dados, exclui cabecalho)
    local sprints_table
    sprints_table=$(grep -E "^\| Sprint [0-9]|\| Pré-Sprint|\| Pre-Sprint" \
        "$_FLC_CURRENT_DIR/$feature_file" 2>/dev/null | head -20 || true)

    # Marca Sprint 1 como "Em andamento" automaticamente
    local sprints_rendered=""
    if [ -n "$sprints_table" ]; then
        # Substitui Pendente da primeira linha por "Em andamento"
        sprints_rendered=$(echo "$sprints_table" | awk 'NR==1{sub(/Pendente/, "Em andamento")} {print}')
    else
        sprints_rendered="| Sprint 1 | A definir | Em andamento |"
    fi

    # Conta total de sprints
    local total_sprints
    total_sprints=$(echo "$sprints_rendered" | grep -cE "^\| Sprint" || true)
    total_sprints="${total_sprints:-1}"

    cat > "$readme" <<EOF
# Current - Em Execucao

> Feature sendo executada agora. Maximo 1 por vez.

---

## Fluxo

\`\`\`
backlog/ (ideia) → features/ (planejada) → current/ (executando) → history/YYYY-MM/ (concluida)
\`\`\`

**Regras:**
- Apenas 1 feature ativa aqui por vez
- Checkpoint atualizado a cada sprint concluida
- Ao concluir: usar \`aidev complete <id>\`

---

## Feature Ativa

### $feature_title

**Arquivo:** [$feature_file]($feature_file)
**Iniciada:** $started_date
**Sprints:** $total_sprints planejados

| Sprint | Objetivo | Status |
|---|---|---|
$sprints_rendered

**Proximo passo:** Executar Sprint 1 — RED → GREEN → REFACTOR

---

## Workflow TDD Ativo

\`\`\`
RED   → Escreva o teste que falha primeiro
GREEN → Implemente o mínimo para passar
REFACTOR → Limpe sem quebrar os testes
\`\`\`

Ao concluir cada sprint: \`aidev done sprint-N "descricao"\`

---

*Ultima atualizacao: $started_date*
EOF
}

# Atualiza features/README.md movendo item para "Em Execucao"
_flc_update_features_readme_start() {
    local feature_file="$1"
    local feature_title="$2"
    local readme="$_FLC_FEATURES_DIR/README.md"
    local date_now
    date_now=$(date +%Y-%m-%d)

    [ ! -f "$readme" ] && return 0

    # Adiciona ou atualiza a seção "Em Execucao"
    if grep -q "Em Execucao\|Em Execução" "$readme"; then
        # Adiciona linha na tabela existente
        sed -i "/Em Execucao\|Em Execução/,/^---/{
            /^\| [A-Za-z]/a\| $feature_title | [current/](../current/$feature_file) | $date_now |
        }" "$readme" 2>/dev/null || true
    fi
}

# ============================================================================
# flc_sprint_done <sprint-id> [descricao]
# Atualiza status da sprint na tabela de current/README.md
# Gera checkpoint + git stage
# ============================================================================
flc_sprint_done() {
    local sprint_id="$1"
    local description="${2:-Sprint concluida}"

    [ -z "$sprint_id" ] && { print_error "sprint-id obrigatorio"; return 1; }

    local readme="$_FLC_CURRENT_DIR/README.md"
    if [ ! -f "$readme" ]; then
        print_error "Nao ha feature ativa em current/ (README nao encontrado)"
        return 1
    fi

    local date_now
    date_now=$(date +%Y-%m-%d)

    # Atualiza status na tabela: extrai número do sprint e busca linha "Sprint N"
    local sprint_num
    sprint_num=$(echo "$sprint_id" | grep -oE '[0-9]+' | head -1)
    local safe_sprint
    if [ -n "$sprint_num" ]; then
        safe_sprint="Sprint $sprint_num"
    else
        safe_sprint=$(echo "$sprint_id" | sed 's/[\/&]/\\&/g')
    fi

    sed -i "/${safe_sprint}/s/Pendente\|Em andamento\|PROXIMO\|PRÓXIMO/Concluida ($date_now)/g" "$readme" 2>/dev/null || true

    print_success "Sprint '$sprint_id' marcada como concluida"

    # Verifica se todas as sprints estão concluídas e determina próxima ação
    local pending_lines
    pending_lines=$(grep -cE "Pendente|Em andamento|PROXIMO|PRÓXIMO" "$readme" 2>/dev/null || true)
    pending_lines=$(echo "$pending_lines" | grep -o '[0-9]*' | tail -1)

    local next_sprint_action=""
    if [ "${pending_lines:-1}" = "0" ]; then
        print_info ""
        print_info "Todas as sprints concluidas!"
        local feature_file
        feature_file=$(find "$_FLC_CURRENT_DIR" -name "*.md" ! -name "README.md" 2>/dev/null | head -1 | xargs basename 2>/dev/null)
        local feature_id_next="${feature_file%.md}"
        next_sprint_action="aidev complete $feature_id_next"
        print_info "Execute: $next_sprint_action"
    else
        # Extrai próximo sprint pendente da tabela do README
        local next_sprint_line
        next_sprint_line=$(grep -E "Pendente|PROXIMO|PRÓXIMO" "$readme" 2>/dev/null | head -1)
        local next_sprint_name
        next_sprint_name=$(echo "$next_sprint_line" | grep -oE 'Sprint [0-9]+[^|]*' | sed 's/[[:space:]]*$//' | head -1)
        [ -n "$next_sprint_name" ] && next_sprint_action="Iniciar: $next_sprint_name"
    fi

    # Persiste next_action no checkpoint.md para recuperação entre sessões
    local checkpoint_file="${_FLC_STATE_DIR:-$(dirname "$_FLC_CURRENT_DIR")}/checkpoint.md"
    if [ -z "$checkpoint_file" ] || [ ! -d "$(dirname "$checkpoint_file")" ]; then
        checkpoint_file="$(dirname "$_FLC_CURRENT_DIR")/checkpoint.md"
    fi
    if [ -n "$next_sprint_action" ] && [ -f "$checkpoint_file" ]; then
        # Atualiza ou insere seção "Próxima Ação"
        if grep -q "Próxima Ação" "$checkpoint_file" 2>/dev/null; then
            sed -i "/Próxima Ação/{ n; s/.*/- $next_sprint_action/; }" "$checkpoint_file" 2>/dev/null || true
        else
            printf '\n## Próxima Ação\n- %s\n' "$next_sprint_action" >> "$checkpoint_file"
        fi
        print_info "Próxima ação registrada: $next_sprint_action"
    fi

    # Checkpoint automático
    _flc_load_checkpoint
    if type ckpt_create &>/dev/null; then
        ckpt_create "." "task_completed" "Sprint $sprint_id concluida: $description" 2>/dev/null || true
    fi

    _flc_stage_and_show "$readme"
}

# ============================================================================
# flc_feature_complete <feature-id>
# Finaliza feature: current/ → history/YYYY-MM/
# Atualiza todos os READMEs e reconstrói ROADMAP como índice
# ============================================================================
flc_feature_complete() {
    local feature_id="$1"
    [ -z "$feature_id" ] && { print_error "feature-id obrigatorio"; return 1; }

    local safe_name
    safe_name=$(_flc_safe_name "$feature_id")

    # Busca arquivo em current/
    local source_file
    source_file=$(find "$_FLC_CURRENT_DIR" -name "${safe_name}.md" ! -name "README.md" 2>/dev/null | head -1)
    [ -z "$source_file" ] && source_file=$(find "$_FLC_CURRENT_DIR" -name "*${safe_name}*.md" ! -name "README.md" 2>/dev/null | head -1)

    if [ -z "$source_file" ] || [ ! -f "$source_file" ]; then
        print_error "Feature nao encontrada em current/: $feature_id"
        print_info "Features ativas:"
        find "$_FLC_CURRENT_DIR" -name "*.md" ! -name "README.md" 2>/dev/null | xargs -n1 basename 2>/dev/null || \
            print_info "  (nenhuma)"
        return 1
    fi

    local feature_basename
    feature_basename=$(basename "$source_file")
    local feature_title
    feature_title=$(grep "^# " "$source_file" | head -1 | sed 's/^# //')
    [ -z "$feature_title" ] && feature_title="$feature_id"

    local month
    month=$(date +%Y-%m)
    local day
    day=$(date +%d)
    local history_month_dir="$_FLC_HISTORY_DIR/$month"

    mkdir -p "$history_month_dir"

    # Atualiza status no arquivo antes de mover
    sed -i "s/\*\*Status:\*\* .*/\*\*Status:\*\* Concluido/g" "$source_file" 2>/dev/null || true

    local dest_file="$history_month_dir/${feature_basename%.md}-${day}.md"
    mv "$source_file" "$dest_file"

    # Limpa current/README.md
    _flc_reset_current_readme

    # Atualiza features/README.md (seção Concluídas)
    _flc_update_features_readme_complete "$feature_basename" "$feature_title"

    # Atualiza backlog/README.md
    _flc_update_backlog_readme_complete "$feature_basename" "$feature_title"

    # Reconstrói ROADMAP como índice
    _flc_roadmap_rebuild

    # Reconstrói history/README.md como índice consolidado
    _flc_history_index_rebuild

    print_success "Feature concluida: $feature_title"
    print_info "Arquivada em: $dest_file"

    # Checkpoint automático
    _flc_load_checkpoint
    if type ckpt_create &>/dev/null; then
        ckpt_create "." "task_completed" "Feature concluida: $feature_id - $feature_title" 2>/dev/null || true
    fi

    local files_to_stage=(
        "$dest_file"
        "$_FLC_CURRENT_DIR/README.md"
        "$_FLC_FEATURES_DIR/README.md"
        "$_FLC_BACKLOG_DIR/README.md"
        "$_FLC_ROADMAP"
        "$_FLC_HISTORY_DIR/README.md"
    )
    _flc_stage_and_show "${files_to_stage[@]}"
}

# Reseta current/README.md para estado "sem feature ativa"
_flc_reset_current_readme() {
    local readme="$_FLC_CURRENT_DIR/README.md"
    local date_now
    date_now=$(date +%Y-%m-%d)

    cat > "$readme" <<EOF
# Current - Em Execucao

> Feature sendo executada agora. Maximo 1 por vez.

---

## Fluxo

\`\`\`
backlog/ (ideia) → features/ (planejada) → current/ (executando) → history/YYYY-MM/ (concluida)
\`\`\`

**Regras:**
- Apenas 1 feature ativa aqui por vez
- Checkpoint atualizado a cada sprint concluida
- Ao concluir: usar \`aidev complete <id>\`

---

## Feature Ativa

*Nenhuma feature em execucao no momento.*

Use \`aidev start <feature-id>\` para iniciar uma feature de features/.

---

*Ultima atualizacao: $date_now*
EOF
}

# Atualiza features/README.md adicionando à seção Concluídas (max 5 entradas)
_flc_update_features_readme_complete() {
    local feature_basename="$1"
    local feature_title="$2"
    local readme="$_FLC_FEATURES_DIR/README.md"
    local month
    month=$(date +%Y-%m)
    local date_now
    date_now=$(date +%Y-%m-%d)

    [ ! -f "$readme" ] && return 0

    # Remove da seção "Em Execucao" se estiver lá
    sed -i "/Em Execucao\|Em Execução/,/^---/{
        /$feature_basename/d
    }" "$readme" 2>/dev/null || true

    # Adiciona nova entrada ao final da seção Concluídas usando awk
    local new_row="| $feature_title | [history/$month/](../history/$month/) | $date_now |"
    _flc_readme_append_to_section "$readme" "Concluidas" "$new_row"

    # Trunca seção Concluídas a 5 entradas mais recentes
    _flc_truncate_readme_section "$readme" "Concluidas" 5
}

# Atualiza backlog/README.md movendo item para "Removidas/Concluídas" (max 5 entradas)
_flc_update_backlog_readme_complete() {
    local feature_basename="$1"
    local feature_title="$2"
    local readme="$_FLC_BACKLOG_DIR/README.md"
    local date_now
    date_now=$(date +%Y-%m-%d)

    [ ! -f "$readme" ] && return 0

    # Adiciona nova entrada ao final da seção Concluídas usando awk
    local new_row="| $feature_title | Concluido em history/ | $date_now |"
    _flc_readme_append_to_section "$readme" "Concluidas" "$new_row"

    # Trunca seção Concluídas a 5 entradas mais recentes
    _flc_truncate_readme_section "$readme" "Concluidas" 5
}

# Insere uma linha de dados no final de uma seção de tabela markdown (antes do próximo ---)
# Uso: _flc_readme_append_to_section <readme> <secao_pattern> <nova_linha>
_flc_readme_append_to_section() {
    local readme="$1"
    local section_pattern="$2"
    local new_row="$3"

    [ ! -f "$readme" ] && return 0
    grep -qE "($section_pattern)" "$readme" 2>/dev/null || return 0

    local tmpfile
    tmpfile=$(mktemp)

    # Estratégia: encontrar a última linha de dados (^\| ) da seção e inserir depois dela
    awk -v pattern="$section_pattern" -v row="$new_row" '
        BEGIN { in_s=0; last_data_line=0; inserted=0 }
        $0 ~ pattern { in_s=1 }
        in_s && NR>1 && /^## / && $0 !~ pattern { in_s=0 }
        in_s && /^\| / && !/^\|---/ { last_data_line=NR }
        { lines[NR]=$0 }
        END {
            for (i=1; i<=NR; i++) {
                print lines[i]
                if (i==last_data_line && !inserted) {
                    print row
                    inserted=1
                }
            }
            # Se não encontrou linha de dados, insere após o separador |---| da seção
            if (!inserted) {
                # Fallback: não faz nada (seção sem dados existentes é caso raro)
            }
        }
    ' "$readme" > "$tmpfile" && mv "$tmpfile" "$readme"
}

# Trunca uma seção de tabela markdown a N linhas de dados (mantém as N mais recentes)
# Uso: _flc_truncate_readme_section <readme> <secao_pattern> <max_linhas>
_flc_truncate_readme_section() {
    local readme="$1"
    local section_pattern="$2"
    local max_lines="${3:-5}"

    [ ! -f "$readme" ] && return 0

    # Conta linhas de dados da seção (linhas que começam com "| " mas não são cabeçalho |---|)
    local total_lines
    total_lines=$(awk "
        /${section_pattern}/ { in_s=1; next }
        in_s && /^---/ { in_s=0; next }
        in_s && /^\| / && !/\|---/ { count++ }
        END { print count+0 }
    " "$readme" 2>/dev/null)

    # Desconta o cabeçalho da tabela (a primeira linha de dados é o cabeçalho | Feature | ... |)
    # O cabeçalho é contado acima, então subtrai 1 para obter apenas as linhas de dados reais
    local data_lines=$(( total_lines - 1 ))

    # Se dentro do limite, nada a fazer
    [ "${data_lines}" -le "$max_lines" ] && return 0

    local lines_to_remove=$(( data_lines - max_lines ))

    local tmpfile
    tmpfile=$(mktemp)

    awk -v pattern="$section_pattern" -v remove="$lines_to_remove" '
        BEGIN { in_s=0; header_done=0; removed=0 }
        $0 ~ pattern { in_s=1; print; next }
        in_s && /^---/ { in_s=0; header_done=0; print; next }
        in_s && /^\|---/ { print; next }
        in_s && /^\| / {
            if (!header_done) { header_done=1; print; next }
            if (removed < remove) { removed++; next }
            print; next
        }
        { print }
    ' "$readme" > "$tmpfile" && mv "$tmpfile" "$readme"
}

# ============================================================================
# _flc_history_index_rebuild
# Reconstrói history/README.md como índice consolidado de todos os itens
# Varre history/YYYY-MM/*.md e extrai título + data
# ============================================================================
_flc_history_index_rebuild() {
    local history_dir="$_FLC_HISTORY_DIR"
    local index="$history_dir/README.md"
    local date_now
    date_now=$(date +%Y-%m-%d)

    mkdir -p "$history_dir"

    # Monta tabela por mês (desc)
    local rows=""
    for month_dir in $(ls -rd "$history_dir"/[0-9][0-9][0-9][0-9]-[0-9][0-9] 2>/dev/null); do
        local month_name
        month_name=$(basename "$month_dir")
        for f in "$month_dir"/*.md; do
            [ -f "$f" ] || continue
            local title
            title=$(grep "^# " "$f" 2>/dev/null | head -1 | sed 's/^# //' || true)
            [ -z "$title" ] && title=$(basename "$f" .md)
            local file_date
            file_date=$(grep -E "^\*\*Concluido\*\*:|^\*\*Data\*\*:" "$f" 2>/dev/null | head -1 | sed 's/.*: //' | tr -d ' ' || echo "$month_name")
            rows="${rows}| $title | $month_name | [ver]($(basename "$month_dir")/$(basename "$f")) |\n"
        done
    done

    cat > "$index" <<EOF
# History — Índice Consolidado

> Todas as features concluídas, organizadas por período.
> Atualizado automaticamente por \`aidev complete\`.
> Última atualização: $date_now

---

## Features Concluídas

| Feature | Período | Arquivo |
|---------|---------|---------|
$(printf "$rows")

---

*Detalhes completos em cada arquivo de history/YYYY-MM/*
EOF

    _flc_log "INFO" "history/README.md reconstruido: $index"
}

# ============================================================================
# _flc_roadmap_rebuild
# Reconstrói ROADMAP.md como índice leve (≤ 60 linhas)
# Conteúdo detalhado fica em cada arquivo de history/
# ============================================================================
_flc_roadmap_rebuild() {
    local roadmap="$_FLC_ROADMAP"
    local version
    version=$(cat VERSION 2>/dev/null | tr -d '[:space:]' || echo "?")
    local date_now
    date_now=$(date +%Y-%m-%d)

    # Feature ativa em current/
    local active_feature=""
    local active_file
    active_file=$(find "$_FLC_CURRENT_DIR" -name "*.md" ! -name "README.md" 2>/dev/null | head -1)
    if [ -n "$active_file" ]; then
        active_feature=$(grep "^# " "$active_file" | head -1 | sed 's/^# //')
    fi

    # Backlog priorizado
    local backlog_items=""
    for f in "$_FLC_BACKLOG_DIR"/*.md; do
        [ -f "$f" ] && [ "$(basename "$f")" != "README.md" ] || continue
        local item_title
        item_title=$(grep "^# " "$f" 2>/dev/null | head -1 | sed 's/^# //' | sed 's/Ideia: //' || true)
        local item_prio
        item_prio=$(grep -iE "^\*\*Prioridade\*\*:|^\*\*Priority\*\*:" "$f" 2>/dev/null | head -1 | sed 's/.*: //' | tr -d '**' | tr -d '\n' || true)
        [ -z "$item_prio" ] && item_prio="Media"
        backlog_items="${backlog_items}| $item_title | $item_prio |\n"
    done

    # Histórico por mês (links para pastas)
    local history_table=""
    for month_dir in $(ls -rd "$_FLC_HISTORY_DIR"/[0-9][0-9][0-9][0-9]-[0-9][0-9] 2>/dev/null | head -12); do
        local month_name
        month_name=$(basename "$month_dir")
        local count
        count=$(find "$month_dir" -name "*.md" 2>/dev/null | wc -l)
        history_table="${history_table}| $month_name | $count feature(s) | [ver](history/$month_name/) |\n"
    done

    cat > "$roadmap" <<EOF
# ROADMAP AI DEV SUPERPOWERS

> Indice de planejamento — conteudo detalhado em history/
> Versao atual: **v$version** | Atualizado: $date_now

---

## Estrutura de Planejamento

| Pasta | Conteudo | Status |
|-------|----------|--------|
| [Backlog](backlog/) | Ideias futuras | Nao priorizadas |
| [Features](features/) | Com plano completo | Prontas para execucao |
| [Current](current/) | Em execucao AGORA | Sprint ativa |
| [History](history/) | Concluidos | Arquivado por data |

**Fluxo:** backlog/ → features/ → current/ → history/YYYY-MM/
**Comandos:** \`aidev plan\` | \`aidev start\` | \`aidev done\` | \`aidev complete\`

---

## Feature em Execucao

$(if [ -n "$active_feature" ]; then echo "- **$active_feature** (em current/)"; else echo "- *Nenhuma feature ativa no momento*"; fi)

---

## Backlog Priorizado

| Feature | Prioridade |
|---------|------------|
$(printf "$backlog_items" | head -10)

---

## Historico de Releases

| Periodo | Features | Detalhes |
|---------|----------|---------|
$(printf "$history_table")

---

*Este arquivo e gerado automaticamente por \`aidev complete\`. Nao edite manualmente.*
EOF

    _flc_log "INFO" "ROADMAP reconstruido: $roadmap"
}

# ============================================================================
# _flc_cleanup_checkpoints
# Mantém apenas os últimos N checkpoints JSON (padrão: 5)
# ============================================================================
_flc_cleanup_checkpoints() {
    local dir="${1:-$_FLC_CHECKPOINTS_DIR}"
    local max="${2:-$_FLC_CHECKPOINTS_MAX}"

    [ -d "$dir" ] || return 0

    local total
    total=$(find "$dir" -maxdepth 1 -name "*.json" 2>/dev/null | wc -l)

    if [ "$total" -le "$max" ]; then
        return 0
    fi

    local to_delete=$(( total - max ))
    _flc_log "INFO" "Limpando checkpoints: $total encontrados, mantendo $max, removendo $to_delete"

    find "$dir" -maxdepth 1 -name "*.json" -printf "%T+ %p\n" 2>/dev/null \
        | sort \
        | head -n "$to_delete" \
        | awk '{print $2}' \
        | xargs rm -f 2>/dev/null || true

    _flc_log "INFO" "Checkpoints apos limpeza: $(find "$dir" -maxdepth 1 -name "*.json" 2>/dev/null | wc -l)"
}

# ============================================================================
# flc_brainstorm_create <backlog-id> [--auto]
# Cria documento de brainstorm a partir de um item do backlog
# Modos: interativo (padrão) | --auto (template pré-preenchido)
# ============================================================================
flc_brainstorm_create() {
    local item_id="${1:-}"
    local auto_mode=false

    # Detecta flag --auto
    if [ "$item_id" = "--auto" ]; then
        auto_mode=true
        item_id="${2:-}"
    elif [ "${2:-}" = "--auto" ]; then
        auto_mode=true
    fi

    if [ -z "$item_id" ]; then
        print_error "Uso: aidev brainstorm <backlog-id> [--auto]"
        print_info "  --auto: cria template sem interação"
        print_info "Items no backlog:"
        ls "$_FLC_BACKLOG_DIR"/*.md 2>/dev/null | grep -v README | xargs -n1 basename 2>/dev/null | sed 's/\.md$//' | sed 's/^/  - /' || print_info "  (backlog vazio)"
        return 1
    fi

    local safe_name
    safe_name=$(_flc_safe_name "$item_id")

    # Busca item no backlog
    local source_file
    source_file=$(find "$_FLC_BACKLOG_DIR" -name "${safe_name}.md" 2>/dev/null | head -1)
    [ -z "$source_file" ] && source_file=$(find "$_FLC_BACKLOG_DIR" -name "*${safe_name}*.md" 2>/dev/null | head -1)

    if [ -z "$source_file" ] || [ ! -f "$source_file" ]; then
        print_error "Item '$item_id' nao encontrado no backlog"
        return 1
    fi

    local item_title
    item_title=$(grep "^# " "$source_file" 2>/dev/null | head -1 | sed 's/^# //' || echo "$item_id")

    local dest_dir="$_FLC_BRAINSTORM_DIR"
    local dest_file="$dest_dir/${safe_name}.md"
    local date_now
    date_now=$(date +%Y-%m-%d)

    mkdir -p "$dest_dir"

    if [ -f "$dest_file" ]; then
        print_warning "Brainstorm '$safe_name' ja existe: $dest_file"
        return 0
    fi

    # Lê problema do backlog para pré-preencher
    local problema
    problema=$(awk '/^## Problema/{flag=1; next} /^##/{flag=0} flag' "$source_file" 2>/dev/null \
        | grep -v "^<!--" | grep -v "^-->" | head -3 | sed 's/^[[:space:]]*//' || true)

    cat > "$dest_file" <<EOF
# Brainstorm: $item_title

**Status:** Brainstorm
**Origem:** backlog/$safe_name.md
**Data:** $date_now
**Modo:** $( $auto_mode && echo "auto" || echo "interativo" )

---

## Problema

${problema:-<!-- Descreva o problema central que esta ideia resolve -->}

## Objetivo Principal

<!-- O que queremos alcançar? Qual o resultado esperado? -->

## Ideias e Abordagens

<!-- Liste as diferentes formas de resolver o problema -->

### Abordagem A
<!-- Descreva -->

### Abordagem B
<!-- Descreva -->

## Riscos e Incertezas

<!-- O que pode dar errado? O que ainda não sabemos? -->

## Decisão Preliminar

<!-- Qual abordagem seguir e por quê? -->

## Próximos Passos

<!-- O que precisa ser detalhado antes de criar o plano formal? -->

---

*Gerado por \`aidev brainstorm\`. Promova com \`aidev create-feature $safe_name\`.*
EOF

    print_success "Brainstorm criado: $dest_file"
    print_info "Edite o arquivo e depois execute: aidev create-feature $safe_name"

    _flc_stage_and_show "$dest_file"
}

# ============================================================================
# flc_feature_from_brainstorm <brainstorm-id>
# Promove brainstorm → features/ com template de plano detalhado
# ============================================================================
flc_feature_from_brainstorm() {
    local item_id="${1:-}"

    if [ -z "$item_id" ]; then
        print_error "Uso: aidev create-feature <brainstorm-id>"
        print_info "Items em brainstorm:"
        ls "$_FLC_BRAINSTORM_DIR"/*.md 2>/dev/null | grep -v README | xargs -n1 basename 2>/dev/null | sed 's/\.md$//' | sed 's/^/  - /' || print_info "  (nenhum brainstorm)"
        return 1
    fi

    local safe_name
    safe_name=$(_flc_safe_name "$item_id")

    local source_file
    source_file=$(find "$_FLC_BRAINSTORM_DIR" -name "${safe_name}.md" 2>/dev/null | head -1)
    [ -z "$source_file" ] && source_file=$(find "$_FLC_BRAINSTORM_DIR" -name "*${safe_name}*.md" 2>/dev/null | head -1)

    if [ -z "$source_file" ] || [ ! -f "$source_file" ]; then
        print_error "Brainstorm '$item_id' nao encontrado em brainstorm/"
        print_info "Execute primeiro: aidev brainstorm <backlog-id>"
        return 1
    fi

    local item_title
    item_title=$(grep "^# Brainstorm:" "$source_file" 2>/dev/null | head -1 | sed 's/^# Brainstorm: //' || echo "$item_id")

    local dest_dir="$_FLC_FEATURES_DIR"
    local dest_file="$dest_dir/${safe_name}.md"
    local date_now
    date_now=$(date +%Y-%m-%d)

    mkdir -p "$dest_dir"

    if [ -f "$dest_file" ]; then
        print_warning "Feature '$safe_name' ja existe em features/: $dest_file"
        return 0
    fi

    # Extrai decisão do brainstorm para pré-preencher
    local decisao
    decisao=$(awk '/^## Decisão Preliminar/{flag=1; next} /^##/{flag=0} flag' "$source_file" 2>/dev/null \
        | grep -v "^<!--" | grep -v "^-->" | head -5 | sed 's/^[[:space:]]*//' || true)

    cat > "$dest_file" <<EOF
# $item_title

**Status:** Planejada
**Prioridade:** Media
**Criado:** $date_now
**Brainstorm:** brainstorm/$safe_name.md

---

## Objetivo

${decisao:-<!-- Descreva o objetivo desta feature baseado no brainstorm -->}

## Escopo

<!-- O que está dentro e fora do escopo desta implementação -->

## Criterios de Aceite

- [ ] <!-- Criterio 1 -->
- [ ] <!-- Criterio 2 -->
- [ ] <!-- Criterio 3 -->

## Sprints

| Sprint | Objetivo | Status |
|--------|----------|--------|
| Sprint 1 | <!-- Objetivo --> | Pendente |
| Sprint 2 | <!-- Objetivo --> | Pendente |

## Dependencias

<!-- Outros módulos ou features necessários -->

## Notas Tecnicas

<!-- Decisões técnicas e arquiteturais -->

---

*Promovida de brainstorm por \`aidev create-feature\`. Inicie com \`aidev start $safe_name\`.*
EOF

    print_success "Feature criada em features/: $dest_file"
    print_info "Proximo passo: aidev start $safe_name"

    _flc_stage_and_show "$dest_file"
}

# ============================================================================
# ALIASES DE COMPATIBILIDADE (flc_* -> feature_*)
# Mantidos para backward compatibility
# ============================================================================

alias feature_plan_create=flc_plan_create
alias feature_start=flc_feature_start
alias feature_done=flc_sprint_done
alias feature_complete=flc_feature_complete
alias feature_safe_name=_flc_safe_name

# Exportar funcoes principais para uso em scripts externos
export -f flc_plan_create
export -f flc_feature_start
export -f flc_sprint_done
export -f flc_feature_complete
export -f flc_brainstorm_create
export -f flc_feature_from_brainstorm
export -f _flc_cleanup_checkpoints
