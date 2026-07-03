#!/usr/bin/env bash
# grill-refine.sh — Fase 3: Refinamento interativo de CONTEXT.md
#
# Uso: grill-refine.sh <project_root> [--generate]
#
# Comportamento:
#   - Lê CONTEXT.md existente
#   - Identifica [PLACEHOLDER] terms
#   - Questiona cada termo 1-a-1 (para o agente/orquestrador)
#   - Atualiza definições no arquivo
#   - Quando todos resolvidos: BREAK final confirming
#
# Exit codes:
#   0 = Todos termos refinados e salvos
#   1 = Erro ou usuário cancelou
#   2 = Usage error

set -uo pipefail

PROJECT_ROOT="${1:-}"
GENERATE_MODE="${2:-}"

# Cores
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
GREEN='\033[0;32m'
BOLD='\033[1m'
RESET='\033[0m'

# ============================================================
# Helpers
# ============================================================

usage() {
    echo "Uso: grill-refine.sh <project_root> [--generate]"
    echo ""
    echo "Refina CONTEXT.md existente:"
    echo "  - Identifica [PLACEHOLDER] terms"
    echo "  - Questiona cada termo 1-a-1"
    echo "  - Atualiza definições"
    echo ""
    echo "  --generate: modo não-interativo (gera template se não existe)"
    exit 2
}

[ -z "$PROJECT_ROOT" ] && usage

CONTEXT_FILE="$PROJECT_ROOT/CONTEXT.md"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GRILL_ROOT="$(dirname "$SCRIPT_DIR")"

# ============================================================
# Verificar dependências
# ============================================================

if [ ! -f "$CONTEXT_FILE" ]; then
    echo -e "${RED}✗${RESET} CONTEXT.md não encontrado em $PROJECT_ROOT"
    echo ""
    echo "  Use --generate para gerar template inicial primeiro:"
    echo "    grill-init-context.sh \"$PROJECT_ROOT\" \"<intent>\" > CONTEXT.md"
    echo "    grill-refine.sh \"$PROJECT_ROOT\""
    exit 1
fi

# ============================================================
# Extrair placeholders do CONTEXT.md
# ============================================================

extract_placeholders() {
    local file="$1"
    grep -n "PLACEHOLDER" "$file" 2>/dev/null || true
}

count_placeholders() {
    local file="$1"
    grep -c "PLACEHOLDER" "$file" 2>/dev/null || echo "0"
}

# ============================================================
# Extrair termos não-resolvidos (que têm PLACEHOLDER)
# ============================================================

get_unresolved_terms() {
    local file="$1"
    # Extrai linhas que têm **termo**: com PLACEHOLDER depois
    grep -B1 "PLACEHOLDER" "$file" 2>/dev/null \
        | grep "^**" \
        | sed 's/^\*\*//; s/\*\*://; s/^[[:space:]]*//' \
        || true
}

# ============================================================
# Refinar um único termo
# ============================================================

refine_term() {
    local term="$1"
    local line_num="$2"
    local file="$3"

    echo ""
    echo -e "${BOLD}═══════════════════════════════════════════════════════════${RESET}"
    echo -e "${BOLD}Termo:${RESET} $term"
    echo ""
    echo -e "  ${CYAN}Pergunta:${RESET} O que '$term' significa neste contexto?"
    echo ""
    echo "  Digite a definição (uma frase curta, o que É, não o que faz):"
    echo "  Ou 'skip' para pular, 'cancel' para abortar."
    echo ""
    echo -n "  > "
}

# ============================================================
# Atualizar definição de um termo no arquivo
# ============================================================

update_term_definition() {
    local term="$1"
    local new_definition="$2"
    local file="$3"

    # Normalizar termo para busca
    local term_normalized
    term_normalized=$(echo "$term" | sed 's/[][.*^$+?{}()|\\]/\\&/g')

    # Encontrar a linha do **Termo** e a linha do PLACEHOLDER
    local term_line
    term_line=$(grep -n "^\\*\\*$term_normalized\\*\\*:" "$file" 2>/dev/null | cut -d: -f1 || true)

    if [ -z "$term_line" ]; then
        # Tentar versão case-insensitive
        term_line=$(grep -ni "^\\*\\*$term_normalized\\*\\*:" "$file" 2>/dev/null | head -1 | cut -d: -f1 || true)
    fi

    if [ -z "$term_line" ]; then
        echo -e "${RED}✗${RESET} Não consegui encontrar '$term' no arquivo"
        return 1
    fi

    # A linha seguinte ao **Termo**: é a que tem o PLACEHOLDER
    local placeholder_line=$((term_line + 1))

    # Verificar se realmente tem PLACEHOLDER
    if ! sed -n "${placeholder_line}p" "$file" 2>/dev/null | grep -q "PLACEHOLDER"; then
        echo -e "${YELLOW}⚠${RESET} Linha $placeholder_line não tem PLACEHOLDER, pulando..."
        return 0
    fi

    # Substituir a linha do PLACEHOLDER
    local temp_file
    temp_file=$(mktemp)

    sed "${placeholder_line}s/.*/[PLACEHOLDER: $new_definition]/" "$file" > "$temp_file"

    if mv "$temp_file" "$file"; then
        echo -e "${GREEN}✓${RESET} '$term' definido: $new_definition"
        return 0
    else
        echo -e "${RED}✗${RESET} Falha ao salvar"
        rm -f "$temp_file"
        return 1
    fi
}

# ============================================================
# Modo generate (não-interativo)
# ============================================================

run_generate_mode() {
    echo -e "${CYAN}Modo generate (não-interativo)${RESET}"
    echo ""
    echo "  Gera versão 'draft' do CONTEXT.md:"
    echo "  - Substitui [PLACEHOLDER] por [DRAFT: ...]"
    echo "  - Marca o arquivo como 'draft' no header"
    echo ""
    echo "  O orquestrador deve revisar manualmente depois."
    echo ""

    local temp_file
    temp_file=$(mktemp)

    # Adicionar status draft ao header
    sed '1a\
\
> **Status:** DRAFT — requer refinamento manual\
' "$CONTEXT_FILE" > "$temp_file" 2>/dev/null || cp "$CONTEXT_FILE" "$temp_file"

    # Substituir todos PLACEHOLDER por DRAFT
    sed -i 's/\[PLACEHOLDER: \([^\]]*\)\]/[DRAFT: \1]/g' "$temp_file"

    # Backup do original
    cp "$CONTEXT_FILE" "${CONTEXT_FILE}.backup"

    mv "$temp_file" "$CONTEXT_FILE"

    echo -e "${GREEN}✓${RESET} CONTEXT.md marcado como DRAFT"
    echo "  Backup salvo em: ${CONTEXT_FILE}.backup"

    return 0
}

# ============================================================
# Main — modo interativo
# ============================================================

main() {
    if [ "${GENERATE_MODE:-}" = "--generate" ]; then
        run_generate_mode
        exit $?
    fi

    local placeholder_count
    placeholder_count=$(count_placeholders "$CONTEXT_FILE")

    if [ "$placeholder_count" -eq 0 ]; then
        echo ""
        echo -e "${GREEN}✓${RESET} CONTEXT.md não tem placeholders pendentes"
        echo "  Todos os termos parecem estar definidos."
        echo ""
        echo "  Se quiser revisar algum termo:"
        echo "    1. Edite $CONTEXT_FILE manualmente"
        echo "    2. Ou delete uma linha PLACEHOLDER e rode novamente"
        exit 0
    fi

    echo ""
    echo -e "${CYAN}Refinando CONTEXT.md...${RESET}"
    echo -e "  Arquivo: $CONTEXT_FILE"
    echo -e "  Placeholders encontrados: $placeholder_count"
    echo ""
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════${RESET}"
    echo -e "${YELLOW}⚠${RESET} ${BOLD}REGRAS DO REFINAMENTO:${RESET}"
    echo "  - Defina o que o termo É, não o que FAZ"
    echo "  - Uma frase curta é suficiente"
    echo "  - Liste termos a evitar (aliases) depois de '_Avoid_:'"
    echo "  - 'skip' = pular este termo por enquanto"
    echo "  - 'cancel' = abortar (não salva nada)"
    echo -e "${YELLOW}═══════════════════════════════════════════════════════════${RESET}"
    echo ""

    # Extrair termos com placeholder
    local -a unresolved_terms=()
    while IFS= read -r line; do
        [ -n "$line" ] && unresolved_terms+=("$line")
    done < <(get_unresolved_terms "$CONTEXT_FILE")

    local total_terms=${#unresolved_terms[@]}
    local current=0
    local skipped=0
    local refined=0

    for term in "${unresolved_terms[@]}"; do
        current=$((current + 1))
        echo ""
        echo -e "${BOLD}[$current/$total_terms]${RESET} Refinando: $term"

        refine_term "$term"

        read -r definition
        definition=$(echo "$definition" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

        case "$definition" in
            cancel|CANCEL)
                echo ""
                echo -e "${RED}✗${RESET} Cancelado pelo usuário."
                echo "  Nenhuma alteração foi salva."
                exit 1
                ;;
            skip|SKIP)
                echo -e "${YELLOW}⚠${RESET} Pulando '$term'"
                skipped=$((skipped+1))
                continue
                ;;
            "")
                echo -e "${YELLOW}⚠${RESET} Definição vazia, pulando"
                skipped=$((skipped+1))
                continue
                ;;
            *)
                if update_term_definition "$term" "$definition" "$CONTEXT_FILE"; then
                    refined=$((refined+1))
                else
                    skipped=$((skipped+1))
                fi
                ;;
        esac
    done

    # ============================================================
    # Resumo e BREAK final
    # ============================================================

    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════════${RESET}"
    echo -e "${GREEN}✓${RESET} Refinamento concluído"
    echo ""
    echo -e "  ${GREEN}Termos refinados:${RESET} $refined"
    echo -e "  ${YELLOW}Termos pulados:${RESET} $skipped"

    local remaining
    remaining=$(count_placeholders "$CONTEXT_FILE")

    if [ "$remaining" -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}⚠${RESET} Ainda há $remaining placeholder(s) pendente(s)"
        echo "  Execute novamente para continuar o refinamento."
    else
        echo ""
        echo -e "${GREEN}✓${RESET} Todos os termos foram refinados!"
        echo ""
        echo -e "${BOLD}PRÓXIMOS PASSOS:${RESET}"
        echo "  1. Revise o CONTEXT.md final"
        echo "  2. Execute grill-suggest-adr.sh para identificar decisões que precisam de ADR"
        echo "  3. Prossiga com GATE-1 (SPEC.md exists)"
    fi

    echo -e "${GREEN}═══════════════════════════════════════════════════════════${RESET}"

    exit 0
}

main
