#!/usr/bin/env bash
# lib/commands/loop.sh - Entrada experimental para Loop Engineering.

set -euo pipefail

devorq::cmd_loop() {
    local profile="${1:-}"
    shift || true

    case "$profile" in
        implementation)
            bash "$DEVORQ_ROOT/scripts/loop-implementation.sh" "$@"
            ;;
        ""|--help|-h|help)
            cat <<'EOF'
Uso: devorq loop implementation --experimental --story ID --run-id ID [--prd ARQUIVO]

Somente o perfil implementation esta disponivel experimentalmente. Outros
perfis permanecem bloqueados ate terem verificador e gates proprios.
EOF
            ;;
        *)
            devorq::error "Perfil de loop indisponivel: $profile"
            ;;
    esac
}
