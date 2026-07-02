#!/usr/bin/env bash
# scripts/adapters/hermes-delegate.sh
# Wrapper fino: adapter DEVORQ_DELEGATE_FN para o runner 'hermes'.
# Toda a logica vive em delegate.sh; aqui so fixamos DEVORQ_RUNNER=hermes.
#   export DEVORQ_DELEGATE_FN="$PWD/scripts/adapters/hermes-delegate.sh"
#   bash skills/devorq-auto/scripts/loop-auto.sh "$PWD" --all
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export DEVORQ_RUNNER=hermes
exec "$DIR/delegate.sh" "$@"
