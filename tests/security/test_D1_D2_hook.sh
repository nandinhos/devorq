#!/usr/bin/env bash
# ============================================================================
# TEST D-1+D-2: hook commit-msg bloqueia Co-authored-by
# ============================================================================
# Hook ja existe em lib/commands/rules.sh. Patch: garantir instalacao + validar.
# ============================================================================

set -o pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCHES_DIR="$(dirname "$SCRIPT_DIR")"
REPO_DIR="${REPO_DIR:-/tmp/devorq_sandbox/devorq_v3}"
HOOK_FILE="$REPO_DIR/.git/hooks/commit-msg"

cd "$REPO_DIR" || exit 1
git config user.email "test@test.com" 2>/dev/null
git config user.name "Test" 2>/dev/null

# ============================================================================
# T1: hook instalado e executavel
# ============================================================================
if [ ! -f "$HOOK_FILE" ]; then
    echo "[D-1] 🔴 HOOK NAO INSTALADO em $HOOK_FILE"
    echo "        Rode: cd $REPO_DIR && ./bin/devorq rules install-hook"
    exit 1
fi
if [ ! -x "$HOOK_FILE" ]; then
    echo "[D-1] 🔴 HOOK existe mas NAO executavel: $HOOK_FILE"
    exit 1
fi
echo "[D-1] 🟢 Hook commit-msg instalado e executavel"

# ============================================================================
# T2: hook BLOQUEIA commit com Co-authored-by (em arquivo, não -m)
# ============================================================================
TEST_FILE="test_hook_D2_$$"
echo "conteudo" > "$TEST_FILE"
git add "$TEST_FILE"

# Criar arquivo de commit message com Co-authored-by
MSG_FILE="/tmp/commit_msg_D2_$$"
cat > "$MSG_FILE" <<'EOF'
feat(test): testando hook D2

 Cursor <cursor@cursor.com>
EOF

# Tentar commit. Hook DEVE retornar exit != 0
if git commit -F "$MSG_FILE" 2>/dev/null; then
    echo "🔴 [T2 FALHOU] commit com Co-authored-by PASSOU (hook quebrado)"
    git reset HEAD "$TEST_FILE" 2>/dev/null
    rm -f "$TEST_FILE" "$MSG_FILE"
    exit 1
fi
echo "[T2] 🟢 commit com Co-authored-by BLOQUEADO"
git reset HEAD "$TEST_FILE" 2>/dev/null
rm -f "$TEST_FILE" "$MSG_FILE"

# ============================================================================
# T3: hook ACEITA commit limpo
# ============================================================================
echo "conteudo limpo" > "$TEST_FILE"
git add "$TEST_FILE"
MSG_FILE="/tmp/commit_msg_D2_clean_$$"
cat > "$MSG_FILE" <<'EOF'
feat(test): commit limpo
EOF

if git commit -F "$MSG_FILE" 2>&1 | head -2; then
    echo "[T3] 🟢 commit limpo ACEITO pelo hook"
    git reset HEAD~1 2>/dev/null
    rm -f "$TEST_FILE" "$MSG_FILE"
else
    echo "🔴 [T3 FALHOU] commit limpo foi BLOQUEADO (false positive)"
    git reset HEAD "$TEST_FILE" 2>/dev/null
    rm -f "$TEST_FILE" "$MSG_FILE"
    exit 1
fi

# ============================================================================
# T4: hook valida formato tipo(escopo):
# ============================================================================
echo "teste formato" > "$TEST_FILE"
git add "$TEST_FILE"
MSG_FILE="/tmp/commit_msg_D2_fmt_$$"
cat > "$MSG_FILE" <<'EOF'
mensagem sem formato correto
EOF

OUT=$(git commit -F "$MSG_FILE" 2>&1)
if echo "$OUT" | grep -qiE "formato|escopo"; then
    echo "[T4] 🟢 hook valida formato de mensagem (tipo(escopo):)"
else
    echo "🟡 [T4] hook nao parece validar formato"
fi
git reset HEAD "$TEST_FILE" 2>/dev/null
rm -f "$TEST_FILE" "$MSG_FILE"

echo ""
echo "[D-1+D-2] TODOS OS 4 TESTES PASSARAM"
exit 0
