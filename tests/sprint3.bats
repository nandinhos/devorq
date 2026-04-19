#!/usr/bin/env bats

# Sprint 3 — Portabilidade e Manutenibilidade
# Cobre: mcp-fallback duplicação (3.1), sed_inplace helper (3.2),
#        word-splitting (3.3), sed_inplace aplicado (3.4/3.5), versão (3.6), shellcheck (3.7)

DEVORQ_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

# ────────────────────────────────────────────
# 3.1: remover duplicação mcp-fallback
# ────────────────────────────────────────────

@test "3.1: mcp-fallback nao contem funcao _mcp_fallback_log (privada duplicada)" {
    run grep -n "^_mcp_fallback_log()" "$DEVORQ_ROOT/lib/mcp-fallback.sh"
    [ "$status" -ne 0 ]
}

@test "3.1: mcp-fallback nao contem funcao _mcp_fallback_update_status (privada duplicada)" {
    run grep -n "^_mcp_fallback_update_status()" "$DEVORQ_ROOT/lib/mcp-fallback.sh"
    [ "$status" -ne 0 ]
}

@test "3.1: mcp-fallback ainda contem funcao publica mcp_fallback_log" {
    run grep -n "^mcp_fallback_log()" "$DEVORQ_ROOT/lib/mcp-fallback.sh"
    [ "$status" -eq 0 ]
}

@test "3.1: mcp-fallback ainda contem funcao publica mcp_fallback_update_status" {
    run grep -n "^mcp_fallback_update_status()" "$DEVORQ_ROOT/lib/mcp-fallback.sh"
    [ "$status" -eq 0 ]
}

# ────────────────────────────────────────────
# 3.2: helper sed_inplace
# ────────────────────────────────────────────

@test "3.2: lib/core.sh exporta funcao sed_inplace" {
    source "$DEVORQ_ROOT/lib/core.sh"
    run declare -f sed_inplace
    [ "$status" -eq 0 ]
}

@test "3.2: sed_inplace modifica arquivo no place corretamente" {
    source "$DEVORQ_ROOT/lib/core.sh"

    local tmpfile
    tmpfile=$(mktemp /tmp/devorq-sed-XXXXXX)
    echo "status: pendente" > "$tmpfile"

    sed_inplace "s/status: pendente/status: concluido/" "$tmpfile"

    grep -q "status: concluido" "$tmpfile"
    rm -f "$tmpfile"
}

# ────────────────────────────────────────────
# 3.3: word-splitting em loops
# ────────────────────────────────────────────

@test "3.3: handoff.sh nao usa 'for f in \$(ls' (word-splitting)" {
    run grep -n 'for .* in \$(ls' "$DEVORQ_ROOT/lib/handoff.sh"
    [ "$status" -ne 0 ]
}

@test "3.3: bin/devorq nao usa 'for f in \$file_list' sem aspas" {
    # A forma insegura é: for f in $file_list (sem aspas em torno da variável)
    run grep -nP 'for \w+ in \$(?!{)[a-z_]+\b' "$DEVORQ_ROOT/bin/devorq"
    [ "$status" -ne 0 ]
}

# ────────────────────────────────────────────
# 3.4/3.5: sed_inplace aplicado nos arquivos
# ────────────────────────────────────────────

@test "3.4: bin/devorq nao contem 'sed -i' direto (usa sed_inplace)" {
    run grep -n 'sed -i ' "$DEVORQ_ROOT/bin/devorq"
    [ "$status" -ne 0 ]
}

@test "3.4: lib/handoff.sh nao contem 'sed -i' direto (usa sed_inplace)" {
    run grep -n 'sed -i ' "$DEVORQ_ROOT/lib/handoff.sh"
    [ "$status" -ne 0 ]
}

@test "3.5: lib/feature-lifecycle.sh nao contem 'sed -i' direto (usa sed_inplace)" {
    run grep -n 'sed -i ' "$DEVORQ_ROOT/lib/feature-lifecycle.sh"
    [ "$status" -ne 0 ]
}

# ────────────────────────────────────────────
# 3.6: versão canônica 2.1
# ────────────────────────────────────────────

@test "3.6: arquivo VERSION contem 2.1" {
    run cat "$DEVORQ_ROOT/VERSION"
    [ "$status" -eq 0 ]
    [[ "$output" == 2.1* ]]
}

@test "3.6: bin/devorq --version exibe 2.1" {
    run bash "$DEVORQ_ROOT/bin/devorq" --version
    [ "$status" -eq 0 ]
    [[ "$output" == *"2.1"* ]]
}

@test "3.6: bin/devorq nao contem string hardcoded v2.0 ou 1.3.1" {
    run grep -E '"v2\.0"|v2\.0\b|1\.3\.1' "$DEVORQ_ROOT/bin/devorq"
    [ "$status" -ne 0 ]
}

# ────────────────────────────────────────────
# 3.7: shellcheck nos god files (sem errors)
# ────────────────────────────────────────────

@test "3.7: shellcheck lib/feature-lifecycle.sh sem erros de severity error" {
    run shellcheck --severity=error "$DEVORQ_ROOT/lib/feature-lifecycle.sh"
    [ "$status" -eq 0 ]
}

@test "3.7: shellcheck lib/orchestration.sh sem erros de severity error" {
    run shellcheck --severity=error "$DEVORQ_ROOT/lib/orchestration.sh"
    [ "$status" -eq 0 ]
}
