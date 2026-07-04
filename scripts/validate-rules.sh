#!/usr/bin/env bash
# scripts/validate-rules.sh — Valida se as diretrizes estão sendo seguidas
#
# Uso: bash scripts/validate-rules.sh [--strict]
#
# Este script verifica:
# 1. Diretrizes Globais
# 2. Diretrizes de Desenvolvimento
# 3. Boas Práticas

set -euo pipefail

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STRICT="${1:-}"

PASS_COUNT=0
FAIL_COUNT=0
WARN_COUNT=0

pass() { 
    echo -e "${GREEN}[PASS]${NC} $*"; 
    ((PASS_COUNT++)) || true; 
}

fail() { 
    echo -e "${RED}[FAIL]${NC} $*"; 
    ((FAIL_COUNT++)) || true; 
}

warn() { 
    echo -e "${YELLOW}[WARN]${NC} $*"; 
    ((WARN_COUNT++)) || true; 
}

info() { 
    echo -e "${BLUE}[INFO]${NC} $*"; 
}

echo ""
echo "═══════════════════════════════════════════"
echo "  DEVORQ — Validação de Diretrizes"
echo "═══════════════════════════════════════════"
echo ""

# ============================================================
# 1. Verificar Diretrizes Globais
# ============================================================

info "═══ Diretrizes Globais ═══"

# 1.1 Verificar se existe project_rules.md
if [ -f "$PROJECT_ROOT/.trae/project_rules.md" ]; then
    pass "project_rules.md existe"
else
    fail "project_rules.md não encontrado"
fi

# 1.2 Verificar se existe SPEC.md
if [ -f "$PROJECT_ROOT/SPEC.md" ]; then
    pass "SPEC.md existe"
else
    warn "SPEC.md não encontrado (opcional para CLI)"
fi

# 1.3 Verificar se existe README.md
if [ -f "$PROJECT_ROOT/README.md" ]; then
    pass "README.md existe"
else
    fail "README.md não encontrado"
fi

# 1.4 Verificar se existe .gitignore
if [ -f "$PROJECT_ROOT/.gitignore" ]; then
    pass ".gitignore existe"
    
    # Verificar se .devorq está no .gitignore
    if grep -q "\.devorq" "$PROJECT_ROOT/.gitignore" 2>/dev/null; then
        pass ".devorq está no .gitignore"
    else
        warn ".devorq não está no .gitignore (recomendado)"
    fi
else
    fail ".gitignore não encontrado"
fi

echo ""

# ============================================================
# 2. Verificar Estrutura do Projeto
# ============================================================

info "═══ Estrutura do Projeto ═══"

# 2.1 Verificar bin/devorq
if [ -f "$PROJECT_ROOT/bin/devorq" ]; then
    pass "bin/devorq existe"
    
    # Verificar se é executável
    if [ -x "$PROJECT_ROOT/bin/devorq" ]; then
        pass "bin/devorq é executável"
    else
        warn "bin/devorq não é executável (execute: chmod +x bin/devorq)"
    fi
else
    fail "bin/devorq não encontrado"
fi

# 2.2 Verificar diretório lib/
if [ -d "$PROJECT_ROOT/lib" ]; then
    pass "lib/ existe"
    
    lib_count=$(find "$PROJECT_ROOT/lib" -maxdepth 1 -name "*.sh" -type f 2>/dev/null | wc -l)
    info "lib/ contém $lib_count módulos"
    
    # Verificar módulos essenciais
    for module in gates lessons context compact debug stats vps; do
        if [ -f "$PROJECT_ROOT/lib/${module}.sh" ]; then
            pass "lib/${module}.sh existe"
        else
            warn "lib/${module}.sh não encontrado"
        fi
    done
else
    fail "lib/ não encontrado"
fi

# 2.3 Verificar diretório skills/
if [ -d "$PROJECT_ROOT/skills" ]; then
    pass "skills/ existe"
    
    skill_count=
    skill_count=$(find "$PROJECT_ROOT/skills" -maxdepth 1 -type d 2>/dev/null | wc -l)
    ((skill_count--)) || true  # Subtrai o próprio diretório skills
    info "skills/ contém $skill_count skills"
else
    warn "skills/ não encontrado (opcional)"
fi

echo ""

# ============================================================
# 3. Verificar Diretrizes de Desenvolvimento
# ============================================================

info "═══ Diretrizes de Desenvolvimento ═══"

# 3.1 Verificar testes E2E
if [ -d "$PROJECT_ROOT/e2e-tests" ]; then
    pass "e2e-tests/ existe"
    
    # Verificar package.json
    if [ -f "$PROJECT_ROOT/e2e-tests/package.json" ]; then
        pass "e2e-tests/package.json existe"
    else
        warn "e2e-tests/package.json não encontrado"
    fi
    
    # Verificar Playwright config
    if [ -f "$PROJECT_ROOT/e2e-tests/playwright.config.ts" ]; then
        pass "playwright.config.ts existe"
    else
        warn "playwright.config.ts não encontrado"
    fi
    
    # Verificar se há testes
    test_count=
    test_count=$(find "$PROJECT_ROOT/e2e-tests/tests" -name "*.spec.ts" -type f 2>/dev/null | wc -l)
    if [ "$test_count" -gt 0 ]; then
        pass "Encontrados $test_count arquivos de teste"
    else
        warn "Nenhum arquivo de teste encontrado em e2e-tests/tests/"
    fi
else
    warn "e2e-tests/ não encontrado (recomendado)"
fi

# 3.2 Verificar scripts de teste bash
if [ -f "$PROJECT_ROOT/scripts/e2e-test.sh" ]; then
    pass "scripts/e2e-test.sh existe"
    
    # Verificar se é executável
    if [ -x "$PROJECT_ROOT/scripts/e2e-test.sh" ]; then
        pass "scripts/e2e-test.sh é executável"
    else
        warn "scripts/e2e-test.sh não é executável"
    fi
else
    warn "scripts/e2e-test.sh não encontrado"
fi

if [ -f "$PROJECT_ROOT/scripts/ci-test.sh" ]; then
    pass "scripts/ci-test.sh existe"
else
    warn "scripts/ci-test.sh não encontrado"
fi

echo ""

# ============================================================
# 4. Verificar Convenções de Commits
# ============================================================

info "═══ Convenções de Commits ═══"

# 4.1 Verificar últimos commits
if [ -d "$PROJECT_ROOT/.git" ]; then
    pass "Repositório Git inicializado"
    
    # Verificar se há commits recentes
    commit_count=
    commit_count=$(git -C "$PROJECT_ROOT" rev-list --count HEAD 2>/dev/null || echo "0")
    info "Total de commits: $commit_count"
    
    # Verificar último commit
    last_commit=
    last_commit=$(git -C "$PROJECT_ROOT" log -1 --oneline 2>/dev/null || echo "Nenhum commit")
    info "Último commit: $last_commit"
    
    # Verificar se há coauthor (contra as diretrizes)
    coauthor_count=
    coauthor_count=$(git -C "$PROJECT_ROOT" log --grep="Co-authored-by" --format="%H" 2>/dev/null | wc -l || echo "0")
    coauthor_count=$(echo "$coauthor_count" | tr -d ' ')
    if [ "$coauthor_count" -gt 0 ]; then
        fail "Encontrados $coauthor_count commits com Co-authored-by (proibido — rules/commit-convention.md)"
    else
        pass "Nenhum commit com Co-authored-by encontrado"
    fi
else
    warn "Repositório Git não encontrado"
fi

# 4.2 Verificar .cursor/ não versionado no repo canônico
if git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
    if git -C "$PROJECT_ROOT" ls-files --error-unmatch .cursor 2>/dev/null; then
        fail ".cursor/ versionado no repo (use devorq rules export cursor localmente)"
    else
        pass ".cursor/ não versionado"
    fi
fi
if grep -q '^\.cursor/' "$PROJECT_ROOT/.gitignore" 2>/dev/null; then
    pass ".cursor/ no .gitignore"
else
    warn ".cursor/ não está no .gitignore"
fi

# 4.3 Verificar AGENTS.md e arquitetura agnóstica
if [ -f "$PROJECT_ROOT/AGENTS.md" ]; then
    pass "AGENTS.md existe"
else
    fail "AGENTS.md não encontrado"
fi

if [ -f "$PROJECT_ROOT/docs/ARQUITETURA-AGNOSTICA-LLM.md" ]; then
    pass "docs/ARQUITETURA-AGNOSTICA-LLM.md existe"
else
    fail "docs/ARQUITETURA-AGNOSTICA-LLM.md não encontrado"
fi

echo ""

# ============================================================
# 5. Verificar Documentação
# ============================================================

info "═══ Documentação ═══"

# 5.1 Verificar CHANGELOG.md
if [ -f "$PROJECT_ROOT/CHANGELOG.md" ]; then
    pass "CHANGELOG.md existe"
else
    warn "CHANGELOG.md não encontrado (recomendado)"
fi

# 5.2 Verificar INSTALL.md
if [ -f "$PROJECT_ROOT/INSTALL.md" ]; then
    pass "INSTALL.md existe"
else
    warn "INSTALL.md não encontrado (recomendado)"
fi

# 5.3 Verificar EXTRAS.md
if [ -f "$PROJECT_ROOT/EXTRAS.md" ]; then
    pass "EXTRAS.md existe"
else
    warn "EXTRAS.md não encontrado (recomendado)"
fi

# 5.4 Verificar docs/
if [ -d "$PROJECT_ROOT/docs" ]; then
    pass "docs/ existe"
    
    doc_count=
    doc_count=$(find "$PROJECT_ROOT/docs" -name "*.md" -type f 2>/dev/null | wc -l)
    info "docs/ contém $doc_count arquivos"
else
    warn "docs/ não encontrado (recomendado)"
fi

echo ""

# ============================================================
# 6. Verificar Boas Práticas
# ============================================================

info "═══ Boas Práticas ═══"

# 6.1 Verificar sintaxe dos scripts principais
if command -v shellcheck &>/dev/null; then
    info "shellcheck disponível - verificando scripts..."
    
    shell_errors=0
    for script in "$PROJECT_ROOT/bin/devorq" "$PROJECT_ROOT/lib"/*.sh; do
        if [ -f "$script" ]; then
            if shellcheck -S error "$script" 2>/dev/null | grep -q "SC[12]"; then
                ((shell_errors++)) || true
            fi
        fi
    done
    
    if [ "$shell_errors" -eq 0 ]; then
        pass "Scripts passaram em shellcheck"
    else
        warn "$shell_errors script(s) com erros de shellcheck"
    fi
else
    info "shellcheck não disponível (opcional)"
fi

# 6.2 Verificar VERSION
if [ -f "$PROJECT_ROOT/VERSION" ]; then
    version=
    version=$(cat "$PROJECT_ROOT/VERSION" 2>/dev/null || echo "desconhecida")
    pass "VERSÃO: $version"
else
    warn "VERSION não encontrado"
fi

echo ""
echo "═══════════════════════════════════════════"
echo "  RESUMO DA VALIDAÇÃO"
echo "═══════════════════════════════════════════"
echo ""
echo -e "${GREEN}Passed:${NC}  $PASS_COUNT"
echo -e "${RED}Failed:${NC}   $FAIL_COUNT"
echo -e "${YELLOW}Warnings:${NC} $WARN_COUNT"
echo ""

# ============================================================
# Resultado Final
# ============================================================

if [ "$FAIL_COUNT" -eq 0 ]; then
    # --strict: trata warnings como falha (antes a flag era capturada mas no-op). DQ-030
    if [ "$STRICT" = "--strict" ] && [ "$WARN_COUNT" -gt 0 ]; then
        echo -e "${RED}═══════════════════════════════════════════"
        echo -e "  ✗ MODO --strict: $WARN_COUNT warning(s) tratados como falha"
        echo -e "═══════════════════════════════════════════${NC}"
        echo ""
        exit 1
    fi
    echo -e "${GREEN}═══════════════════════════════════════════"
    echo -e "  ✓ TODAS AS VALIDAÇÕES PASSARAM"
    echo -e "═══════════════════════════════════════════${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}═══════════════════════════════════════════"
    echo -e "  ✗ ALGUMAS VALIDAÇÕES FALHARAM"
    echo -e "═══════════════════════════════════════════${NC}"
    echo ""
    exit 1
fi
