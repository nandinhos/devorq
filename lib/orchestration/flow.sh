#!/bin/bash
# DEVORQ - Orquestrador Principal
# Executa o fluxo completo automaticamente

set -eEo pipefail

DEVORQ_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../" && pwd)"
DEVORQ_DIR="$DEVORQ_ROOT/.devorq"
DOCS_DIR="$DEVORQ_ROOT/docs"

# Carregar módulos
source "$DEVORQ_ROOT/lib/detect.sh"

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log() { echo -e "${CYAN}[DEVORQ]${NC} $1"; }
log_step() { echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n${GREEN}► $1${NC}\n"; }
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }

# =====================================================
# FASE 1: DETECÇÃO DE CONTEXTO
# =====================================================

phase1_detection() {
    log_step "FASE 1: DETECÇÃO DE CONTEXTO"
    
    local stack=$(detect_stack "$DEVORQ_ROOT")
    log_info "Stack: $stack"
    
    local project_type=$(detect_project_type "$DEVORQ_ROOT")
    log_info "Tipo: $project_type"
    
    local llm=$(detect_llm)
    log_info "LLM: $llm"
    
    local runtime=$(detect_runtime)
    log_info "Runtime: $runtime"
    
    local db=$(detect_database)
    log_info "Banco: $db"
    
    # Salvar no state
    mkdir -p "$DEVORQ_DIR/state"
    cat > "$DEVORQ_DIR/state/context.json" << EOF
{
  "stack": "$stack",
  "project_type": "$project_type",
  "llm": "$llm",
  "runtime": "$runtime",
  "database": "$db",
  "detected_at": "$(date -Iseconds)"
}
EOF
    
    echo "$stack:$project_type:$llm:$runtime:$db"
}

# =====================================================
# FASE 2: ANÁLISE DE PROJETO
# =====================================================

phase2_analysis() {
    local stack="$1"
    local project_type="$2"
    
    log_step "FASE 2: ANÁLISE DE PROJETO"
    
    # Verificar PRD
    local prd_file=$(check_prd_exists "$DEVORQ_ROOT")
    
    if [ -n "$prd_file" ]; then
        log_info "PRD encontrado: $prd_file"
        analyze_prd "$prd_file"
        echo "existing_with_prd"
        return
    fi
    
    log_info "PRD não encontrado"
    
    if [ "$project_type" = "greenfield" ]; then
        log_info "Tipo: Greenfield - Sistema novo"
        echo "greenfield"
        return
    fi
    
    # Verificar se é legado
    if is_legacy "$DEVORQ_ROOT"; then
        log_info "Sistema LEGADO detectado"
        echo "legacy"
    else
        log_info "Sistema brownfield"
        echo "brownfield"
    fi
}

analyze_prd() {
    local prd_file="$1"
    
    log_info "Analisando PRD..."
    
    local project_name=$(grep -m1 "^# " "$prd_file" 2>/dev/null | sed 's/^# //' || echo "Projeto")
    local features_count=$(grep -c "^- " "$prd_file" 2>/dev/null || echo "0")
    
    log_info "Projeto: $project_name"
    log_info "Features: $features_count"
    
    mkdir -p "$DEVORQ_DIR/state"
    cat > "$DEVORQ_DIR/state/prd_analysis.json" << EOF
{
  "project_name": "$project_name",
  "features_count": $features_count,
  "analyzed_at": "$(date -Iseconds)"
}
EOF
}

# =====================================================
# FASE 3: REGRAS GLOBAIS
# =====================================================

phase3_rules() {
    local project_type="$1"
    local stack="$2"
    
    log_step "FASE 3: ESTABELECER REGRAS GLOBAIS"
    
    mkdir -p "$DEVORQ_DIR/rules"
    
    case "$project_type" in
        "greenfield")
            cat > "$DEVORQ_DIR/rules/project.md" << 'EOF'
# Regras do Projeto - Greenfield

## Contexto
- Tipo: Sistema novo (greenfield)
- Regra de Ouro: Arquitetura primeiro, código depois

## Regras de Ouro
1. **TDD Obrigatório**: Testes antes de código
2. **PRD como fonte de verdade**: Seguir especificações
3. **Code Review**: Antes de qualquer merge

## Padrões
- Estrutura: MVC/Laravel padrão
- Testes: Feature tests
- Linter: Pint
EOF
            ;;
        "legacy")
            cat > "$DEVORQ_DIR/rules/project.md" << 'EOF'
# Regras do Projeto - Legado

## Contexto
- Tipo: Sistema legado (refatoração necessária)
- Regra de Ouro: "First, do no harm"

## Regras de Ouro
1. **Análise primeiro**: Mapear dependências antes de modificar
2. **Testes obrigatórios**: Nova funcionalidade = novos testes
3. **Minimalismo**: Mudar apenas o necessário
4. **Documentar desvios**: Se preciso alterar padrão, documentar

## Prioridades
1. Estabilidade
2. Testes
3. Modernização gradual
EOF
            ;;
        "brownfield"|"existing_with_prd")
            cat > "$DEVORQ_DIR/rules/project.md" << 'EOF'
# Regras do Projeto - Brownfield

## Contexto
- Tipo: Projeto em andamento
- Regra de Ouro: Respeitar padrões existentes

## Regras de Ouro
1. **Consistência**: Manter padrões do projeto
2. **TDD**: Testes para funcionalidades novas
3. **Minimalismo**: Mudar apenas o necessário
4. **Documentar**: Usar /learned-lesson
EOF
            ;;
    esac
    
    log_success "Regras estabelecidas"
}

# =====================================================
# FASE 4: BRAINSTORM RIGOROSO
# =====================================================

phase4_brainstorm() {
    local user_intent="$1"
    
    log_step "FASE 4: BRAINSTORM RIGOROSO"
    
    if [ -z "$user_intent" ]; then
        log_warn "Nenhum intent. Use: devorq flow 'minha task'"
        return 1
    fi
    
    log_info "Intent: $user_intent"
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local brainstorm_file="$DEVORQ_DIR/state/brainstorms/br_${timestamp}.md"
    mkdir -p "$DEVORQ_DIR/state/brainstorms"
    
    cat > "$brainstorm_file" << EOF
# Brainstorm - $user_intent

## Identificação
- **Intent**: $user_intent
- **Data**: $(date +%Y-%m-%d\ %H:%M:%S)
- **Stack**: $(detect_stack "$DEVORQ_ROOT")

## Análise do Problema
### O que precisa resolver?
[Extrair do intent: o que o usuário quer]

### Por que precisa resolver?
[Motivação business]

### Quais são as restrições?
- [Restrição 1: tempo, budget, tecnologia, etc]

## Alternativas
### Opção 1: [Solução mais simples]
- Prós: [lista]
- Contras: [lista]
- Complexidade: baixa/média/alta

### Opção 2: [Solução mais completa]
- Prós: [lista]
- Contras: [lista]
- Complexidade: baixa/média/alta

## Riscos
| Risco | Probabilidade | Impacto | Mitigação |
|-------|---------------|---------|-----------|
| Risco 1 | Alta/Média/Baixa | Alto/Médio/Baixo | Como evitar |

## Decisão
- **Caminho**: [Escolhido]
- **Justificativa**: [Por quê]

## Próximos Passos
1. ☐ Refinar com /scope-guard
2. ☐ Gerar contrato
3. ☐ Implementar
EOF
    
    log_success "Brainstorm: $brainstorm_file"
    echo "$brainstorm_file"
}

# =====================================================
# FASE 5: CONTRATO
# =====================================================

phase5_contract() {
    local brainstorm_file="$1"
    local user_intent="$2"
    
    log_step "FASE 5: REFINAMENTO E CONTRATO"
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local contract_file="$DEVORQ_DIR/state/contracts/ct_${timestamp}.md"
    mkdir -p "$DEVORQ_DIR/state/contracts"
    
    cat > "$contract_file" << EOF
# CONTRATO DE ESCOPO - $user_intent

## IDENTIFICAÇÃO
- **Task**: $user_intent
- **Tipo**: feature
- **Complexidade**: a definir
- **Estimativa**: a definir

## FAZER
1. [Funcionalidade 1 - específica]
2. [Funcionalidade 2 - específica]
3. [Funcionalidade N - específica]

## NÃO FAZER
1. [O que NÃO fazer 1]
2. [O que NÃO fazer 2]

## ARQUIVOS PERMITIDOS
- `caminho/arquivo1.php`
- `caminho/arquivo2.js`

## ARQUIVOS PROIBIDOS
- `app/Models/User.php`
- `config/auth.php`

## DONE_CRITERIA (Objetivos)
- [ ] Critério verificável 1
- [ ] Critério verificável 2

## RISCO_IDENTIFICADO
- [Riscos conhecidos]
EOF
    
    log_success "Contrato: $contract_file"
    echo "$contract_file"
}

# =====================================================
# FASE 6: SPEC
# =====================================================

phase6_spec() {
    local contract_file="$1"
    local user_intent="$2"
    
    log_step "FASE 6: SPEC DETALHADA"
    
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local spec_file="$DEVORQ_DIR/state/specs/sp_${timestamp}.md"
    mkdir -p "$DEVORQ_DIR/state/specs"
    
    cat > "$spec_file" << EOF
# SPEC DETALHADA - $user_intent

## Contrato Base
$(cat "$contract_file")

## Especificação Técnica
### Stack
- Framework: $(detect_stack "$DEVORQ_ROOT")
- Runtime: $(detect_runtime)
- Banco: $(detect_database)

### Artefatos Necessários
- Models: [lista]
- Controllers: [lista]
- Migrations: [lista]
- Tests: [lista]

### Decisões de Design
- [Decisão 1]: [justificativa]
- [Decisão 2]: [justificativa]

### Dependências
- [Dependência]: [versão]
EOF
    
    log_success "Spec: $spec_file"
    echo "$spec_file"
}

# =====================================================
# FLUXO COMPLETO
# =====================================================

run_full_flow() {
    local user_intent="$1"
    
    log "🚀 INICIANDO FLUXO DEVORQ"
    echo ""
    
    # FASE 1
    local context=$(phase1_detection)
    local stack=$(echo "$context" | cut -d: -f1)
    local project_type=$(echo "$context" | cut -d: -f2)
    
    # FASE 2
    local analysis=$(phase2_analysis "$stack" "$project_type")
    
    # FASE 3
    phase3_rules "$analysis" "$stack"
    
    # Se há intent
    if [ -n "$user_intent" ]; then
        # FASE 4
        local brainstorm=$(phase4_brainstorm "$user_intent")
        
        # FASE 5
        local contract=$(phase5_contract "$brainstorm" "$user_intent")
        
        # FASE 6
        local spec=$(phase6_spec "$contract" "$user_intent")
        
        log_step "✅ FLUXO COMPLETO FINALIZADO"
        log_info "Artifacts gerados:"
        log_info "  - Brainstorm: $brainstorm"
        log_info "  - Contrato: $contract"
        log_info "  - Spec: $spec"
    else
        log_info "Projeto configurado. Use 'devorq flow \"task\"' para iniciar"
    fi
}

# =====================================================
# MAIN
# =====================================================

case "${1:-}" in
    flow)
        shift
        run_full_flow "$1"
        ;;
    init)
        phase1_detection
        phase2_analysis "$(detect_stack "$DEVORQ_ROOT")" "$(detect_project_type "$DEVORQ_ROOT")"
        phase3_rules "brownfield" "$(detect_stack "$DEVORQ_ROOT")"
        ;;
    context)
        export_context
        ;;
    *)
        echo "DEVORQ - Orquestrador"
        echo ""
        echo "Uso: devorq <comando>"
        echo ""
        echo "Comandos:"
        echo "  init           Configurar projeto (detectar stack, tipo, regras)"
        echo "  flow           Executar fluxo completo"
        echo "  flow 'intent'  Executar fluxo para task específica"
        echo "  context        Mostrar contexto atual"
        ;;
esac