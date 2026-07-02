#!/usr/bin/env bash
# scripts/adapters/claude-delegate.sh
# Wrapper fino: adapter DEVORQ_DELEGATE_FN para o runner 'claude'.
# Toda a logica vive em delegate.sh; aqui so fixamos DEVORQ_RUNNER=claude.
#   export DEVORQ_DELEGATE_FN="$PWD/scripts/adapters/claude-delegate.sh"
#   bash skills/devorq-auto/scripts/loop-auto.sh "$PWD" --all
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DEVORQ_RUNNER=claude
exec "$DIR/delegate.sh" "$@"
