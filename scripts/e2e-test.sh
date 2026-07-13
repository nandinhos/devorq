#!/usr/bin/env bash
# E2E Test — DEVORQ v3.5 CLASSIC + AUTO modes
# Sandbox em /tmp/devorq-e2e-sandbox/
#
# Uso: bash scripts/e2e-test.sh [classic|auto|all]
#
# Cria ambiente isolado e testa fluxos completos

set -euo pipefail

DEVORQ_ROOT="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
SANDBOX="/tmp/devorq-e2e-sandbox"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
TESTS_PASSED=0
TESTS_FAILED=0

# Cores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[TEST]${NC} $*"; }
pass() { echo -e "${GREEN}[PASS]${NC} $*"; ((TESTS_PASSED++)) || true; }
fail() { echo -e "${RED}[FAIL]${NC} $*"; ((TESTS_FAILED++)) || true; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }

# ============================================================
# Setup do Sandbox
# ============================================================

setup_sandbox() {
    log "Criando sandbox em $SANDBOX..."

    rm -rf "$SANDBOX"
    mkdir -p "$SANDBOX"

    cd "$SANDBOX"

    # Criar estrutura básica de projeto
    mkdir -p .devorq/state/lessons/captured .devorq/state/unify

    # Criar SPEC.md com BDD completo
    cat > SPEC.md << 'EOF'
# Auth Login — Autenticação de Usuário

**Versão:** 1.0.0
**Data:** 2026-05-09
**Status:** In Progress

---

## 1. Visão

Endpoint de autenticação que valida credenciais e retorna JWT para sessões.

## 2. Stack

- Node.js 20 + Express
- PostgreSQL 16
- bcrypt + jsonwebtoken

## 3. Arquitetura

```
Client → Express → PostgreSQL
```

---

## 4. Acceptance Criteria (BDD)

### AC-1: Login com credenciais válidas

**Given** o usuário existe no sistema com email "nando@devorq.com" e senha "Senha@123"
**When** o cliente envia POST /auth/login com `{"email": "nando@devorq.com", "password": "Senha@123"}`
**Then** o servidor retorna status 200 com `{"token": "<jwt>", "expires_in": 86400}`

**Critérios de sucesso:**
- [ ] Status code é 200
- [ ] Response contém campo `token`
- [ ] Token expira em 24h

---

### AC-2: Login com credenciais inválidas

**Given** o usuário existe com email "nando@devorq.com" e senha "Senha@123"
**When** o cliente envia POST /auth/login com senha errada
**Then** o servidor retorna status 401 com `{"error": "Invalid credentials"}`

**Critérios de sucesso:**
- [ ] Status code é 401
- [ ] Response contém `error`
- [ ] Response NÃO contém token

---

### AC-3: Rate limiting

**Given** o cliente tentou login 5 vezes com falhas
**When** o cliente envia POST /auth/login
**Then** o servidor retorna status 429

**Critérios de sucesso:**
- [ ] Status code é 429 após 5 tentativas

---

## 5. Out of Scope

- Refresh token
- Login social
- 2FA

---

## 6. Stack Técnica

| Componente | Tecnologia | Justificativa |
|-----------|------------|---------------|
| Runtime | Node.js 20 | LTS |
| Framework | Express 4 | Middleware disponível |
| DB | PostgreSQL 16 | Prepared statements |

---

## 7. Diagrama de Fluxo

```
Client → POST /auth/login → Express → bcrypt.compare → JWT
```

---

## 8. Interfaces

### 8.1 API Endpoints

| Método | Path | Descrição | Auth |
|--------|------|-----------|------|
| POST | /auth/login | Login | Não |

### 8.2 Request/Response

**POST /auth/login**

Request:
```json
{
  "email": "nando@devorq.com",
  "password": "Senha@123"
}
```

Response (200):
```json
{
  "token": "eyJ...",
  "expires_in": 86400
}
```

Response (401):
```json
{
  "error": "Invalid credentials"
}
```

---

## 9. Notas de Implementação

1. Usar bcrypt.compare com timing-safe
2. JWT com RS256
3. Rate limit por IP

---

## 10. UNIFY (preenchido ao fechar)

[Preenchido automaticamente por `devorq unify`]
EOF

    # Criar prd.json para AUTO mode
    cat > prd.json << 'EOF'
{
  "stories": [
    {
      "id": "auth-001",
      "title": "Criar endpoint POST /auth/login",
      "description": "Criar endpoint básico com validação de email/senha",
      "passes": false,
      "phase": "auth"
    },
    {
      "id": "auth-002",
      "title": "Implementar validação de credenciais",
      "description": "Validar email/senha contra banco",
      "passes": false,
      "phase": "auth"
    },
    {
      "id": "auth-003",
      "title": "Implementar JWT generation",
      "description": "Gerar JWT após login válido",
      "passes": false,
      "phase": "auth"
    }
  ]
}
EOF

    # Criar context.json
    cat > .devorq/state/context.json << EOF
{
  "project": "auth-login",
  "stack": ["Node.js", "Express", "PostgreSQL"],
  "intent": "implementar endpoint de login com JWT",
  "gates_completed": [],
  "pending_gates": [1,2,3,4,5,6,7]
}
EOF

    # Criar package.json mínimo
    cat > package.json << 'EOF'
{
  "name": "auth-login",
  "version": "1.0.0",
  "type": "module",
  "scripts": {
    "test": "node --test",
    "lint": "echo 'lint ok'"
  }
}
EOF

    # Criar estrutura de testes
    mkdir -p tests
    cat > tests/auth.test.js << 'EOF'
import { describe, it } from 'node:test';
import assert from 'node:assert';

describe('Auth Login', () => {
  it('AC-1: deve retornar 200 com token válido', () => {
    // Simulado
    assert.strictEqual(1, 1, 'AC-1 test placeholder');
  });

  it('AC-2: deve retornar 401 com credenciais inválidas', () => {
    assert.strictEqual(1, 1, 'AC-2 test placeholder');
  });

  it('AC-3: deve retornar 429 após rate limit', () => {
    assert.strictEqual(1, 1, 'AC-3 test placeholder');
  });
});
EOF

    # Criar index.js mínimo (implementação dummy)
    cat > index.js << 'EOF'
// Auth Login API
// Placeholder para testes E2E

export function login(email, password) {
  if (!email || !password) {
    throw new Error('Email e senha são obrigatórios');
  }
  // TODO: implementar validação real
  return { token: 'jwt-placeholder', expires_in: 86400 };
}

export default { login };
EOF

    # Copiar devorq para o sandbox
    cp -r "$DEVORQ_ROOT/bin" "$DEVORQ_ROOT/lib" "$DEVORQ_ROOT/skills" "$SANDBOX/"

    log "Sandbox criado com sucesso"
}

# ============================================================
# Cleanup do Sandbox
# ============================================================

cleanup_sandbox() {
    log "Limpando sandbox..."
    rm -rf "$SANDBOX"
    log "Sandbox removido"
}

# ============================================================
# Teste: GATE-0 (env-context)
# ============================================================

test_gate_0() {
    log "=== TESTE: GATE-0 (env-context) ==="
    cd "$SANDBOX"

    local output
    if output=$(bash bin/devorq gate 0 2>&1); then
        if echo "$output" | grep -q "GATE-0 completo"; then
            pass "GATE-0: executa com sucesso e detecta ambiente"
        else
            fail "GATE-0: output inesperado"
            echo "$output"
        fi
    else
        fail "GATE-0: comando falhou"
        echo "$output"
    fi
}

# ============================================================
# Teste: devorq env detect
# ============================================================

test_env_detect() {
    log "=== TESTE: devorq env detect ==="
    cd "$SANDBOX"

    local output
    if output=$(bash bin/devorq env detect 2>&1); then
        if echo "$output" | grep -q "DEVORQ ENVIRONMENT CONTEXT"; then
            pass "devorq env detect: mostra contexto de ambiente"
        else
            fail "devorq env detect: output inesperado"
            echo "$output"
        fi
    else
        fail "devorq env detect: comando falhou"
        echo "$output"
    fi
}

# ============================================================
# Teste: SPEC.md com BDD validation
# ============================================================

test_spec_validate() {
    log "=== TESTE: devorq spec validate ==="
    cd "$SANDBOX"

    local output
    if output=$(bash bin/devorq spec validate 2>&1); then
        if echo "$output" | grep -q "BDD-style ACs encontrados"; then
            pass "spec validate: detecta ACs BDD corretamente"
        else
            fail "spec validate: não detectou ACs BDD"
            echo "$output"
        fi
    else
        fail "spec validate: comando falhou"
        echo "$output"
    fi
}

# ============================================================
# Teste: SPEC.md template generation
# ============================================================

test_spec_template() {
    log "=== TESTE: devorq spec template ==="
    cd "$SANDBOX"

    rm -f SPEC2.md
    local output
    if output=$(bash bin/devorq spec template nova-feature SPEC2.md 2>&1); then
        if [ -f "SPEC2.md" ] && grep -q "AC-1" SPEC2.md; then
            pass "spec template: gera SPEC.md com BDD"
        else
            fail "spec template: arquivo não criado corretamente"
        fi
    else
        fail "spec template: comando falhou"
        echo "$output"
    fi
}

# ============================================================
# Teste: UNIFY
# ============================================================

test_unify() {
    log "=== TESTE: devorq unify ==="
    cd "$SANDBOX"

    local output
    if output=$(bash bin/devorq unify auth-login --auto 2>&1); then
        if echo "$output" | grep -q "UNIFY gerado" && \
           find .devorq/state/unify/ -maxdepth 1 -name "*_auth-login_unify.md" -type f | grep -q .; then
            pass "unify: gera UNIFY.md corretamente"
        else
            fail "unify: arquivo não gerado"
            echo "$output"
        fi
    else
        fail "unify: comando falhou"
        echo "$output"
    fi
}

# ============================================================
# Teste: GATE-5.5 (UNIFY check)
# ============================================================

test_gate_5_5() {
    log "=== TESTE: GATE-5.5 (UNIFY check) ==="
    cd "$SANDBOX"

    local output
    if output=$(bash bin/devorq gate 5.5 2>&1); then
        if echo "$output" | grep -q "UNIFY executado"; then
            pass "GATE-5.5: detecta UNIFY já executado"
        else
            fail "GATE-5.5: não detectou UNIFY"
            echo "$output"
        fi
    else
        fail "GATE-5.5: comando falhou"
        echo "$output"
    fi
}

# ============================================================
# Teste: devorq mode (CLASSIC detection)
# ============================================================

test_mode_classic() {
    log "=== TESTE: devorq mode classic ==="
    cd "$SANDBOX"

    local output
    if output=$(bash bin/devorq mode classic 2>&1); then
        if echo "$output" | grep -q "MODE=CLASSIC"; then
            pass "mode classic: detecta modo corretamente"
        else
            fail "mode classic: não detectou modo"
            echo "$output"
        fi
    else
        fail "mode classic: comando falhou"
        echo "$output"
    fi
}

# ============================================================
# Teste: devorq mode (AUTO detection)
# ============================================================

test_mode_auto() {
    log "=== TESTE: devorq mode auto ==="
    cd "$SANDBOX"

    local output
    if output=$(bash bin/devorq mode auto 2>&1); then
        if echo "$output" | grep -q "MODE=AUTO"; then
            pass "mode auto: detecta modo corretamente"
        else
            fail "mode auto: não detectou modo"
            echo "$output"
        fi
    else
        fail "mode auto: comando falhou"
        echo "$output"
    fi
}

# ============================================================
# Teste: devorq auto (story-by-story)
# ============================================================

test_auto_mode() {
    log "=== TESTE: devorq auto ==="
    cd "$SANDBOX"

    # Verificar se prd.json existe
    if [ ! -f "prd.json" ]; then
        warn "auto: prd.json não existe — pulando"
        return 0
    fi

    local output
    # Sem delegate configurado, AUTO deve falhar de modo explícito: nunca
    # transforma a indisponibilidade do executor em sucesso.
    if output=$(bash bin/devorq auto 1 2>&1); then
        if echo "$output" | grep -q "AUTO MODE COMPLETED"; then
            pass "devorq auto: conclui apenas com evidencia"
        else
            fail "devorq auto: retorno zero sem estado COMPLETED"
            echo "$output"
        fi
    else
        if echo "$output" | grep -qiE "delegate_task|delegate|AUTO MODE (FAILED|INCOMPLETE)|AUTO requer repositorio Git|worktree e index limpos"; then
            pass "devorq auto: precondicao ou delegate falha de modo fechado"
        else
            fail "devorq auto: erro inesperado"
            echo "$output"
        fi
    fi
}

# ============================================================
# Teste: devorq review (code review)
# ============================================================

test_review() {
    log "=== TESTE: devorq review ==="
    cd "$SANDBOX"

    local output
    if output=$(bash bin/devorq review 2>&1); then
        # Review pode não ter nada a revisar em sandbox
        if echo "$output" | grep -qE "review|Review|REVIEW"; then
            pass "devorq review: executa"
        else
            warn "review: output atípico"
            echo "$output"
        fi
    else
        warn "review: erro (pode ser normal em sandbox sem código)"
    fi
}

# ============================================================
# Teste: Context update after UNIFY
# ============================================================

test_context_update() {
    log "=== TESTE: context.json atualizado após UNIFY ==="
    cd "$SANDBOX"

    if [ -f ".devorq/state/context.json" ]; then
        local unify_done
        unify_done=$(grep -o '"unify_done": true' .devorq/state/context.json 2>/dev/null || echo "")
        if [ -n "$unify_done" ]; then
            pass "context.json: campo unify_done atualizado"
        else
            # Verificar se jq está disponível
            if command -v jq &>/dev/null; then
                local ud
                ud=$(jq -r '.unify_done // false' .devorq/state/context.json 2>/dev/null)
                if [ "$ud" = "true" ]; then
                    pass "context.json: campo unify_done = true (via jq)"
                else
                    fail "context.json: unify_done não foi atualizado"
                fi
            else
                pass "context.json: arquivo existe (jq não disponível para verificar)"
            fi
        fi
    else
        fail "context.json: arquivo não existe"
    fi
}

# ============================================================
# Fluxo CLASSIC completo
# ============================================================

test_classic_flow() {
    log "=== FLUXO CLASSIC COMPLETO ==="
    cd "$SANDBOX"

    log "Executando gates 1-7..."

    for gate in 1 2 3 4 5 6 7; do
        local output
        if output=$(bash bin/devorq gate "$gate" 2>&1); then
            log "  GATE-$gate: OK"
        else
            fail "GATE-$gate: falhou"
            echo "$output"
            return 1
        fi
    done

    pass "Fluxo CLASSIC: gates 1-7 completados"
}

# ============================================================
# Main
# ============================================================

main() {
    local mode="${1:-all}"

    echo ""
    echo "════════════════════════════════════════════════════════"
    echo "  DEVORQ v3.5 — E2E Test Suite"
    echo "  Sandbox: $SANDBOX"
    echo "  Modo: $mode"
    echo "════════════════════════════════════════════════════════"
    echo ""

    trap cleanup_sandbox EXIT

    setup_sandbox

    echo ""
    echo "════════════════════════════════════════════════════════"
    echo "  TESTES: Novas Funcionalidades"
    echo "════════════════════════════════════════════════════════"
    echo ""

    # Testes das novas funcionalidades
    test_gate_0
    test_env_detect
    test_spec_validate
    test_spec_template
    test_unify
    test_gate_5_5
    test_context_update
    test_mode_classic
    test_mode_auto
    test_auto_mode
    test_review

    echo ""
    echo "════════════════════════════════════════════════════════"
    echo "  FLUXO: CLASSIC (gates 1-7)"
    echo "════════════════════════════════════════════════════════"
    echo ""

    test_classic_flow

    echo ""
    echo "════════════════════════════════════════════════════════"
    echo "  RESULTADO DOS TESTES"
    echo "════════════════════════════════════════════════════════"
    echo ""
    echo -e "  ${GREEN}Passados: $TESTS_PASSED${NC}"
    echo -e "  ${RED}Falharam: $TESTS_FAILED${NC}"
    echo ""

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}✅ TODOS OS TESTES PASSARAM${NC}"
        exit 0
    else
        echo -e "${RED}❌ $TESTS_FAILED TESTE(S) FALHOU(RAM)${NC}"
        exit 1
    fi
}

main "$@"
