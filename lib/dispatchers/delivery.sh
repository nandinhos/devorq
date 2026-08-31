#!/usr/bin/env bash
# lib/dispatchers/delivery.sh -- DEVORQ v4.1.0
#
# Dispatcher: DELIVERY
# Responsabilidade unica: entrega (commit, sync, rules, review, version).
#
# Comandos:
#   commit       devorq::cmd_commit_dispatch  (lib/commands/commit.sh)
#   vps          devorq::cmd_vps             (lib/commands/integration.sh)
#   sync         devorq::cmd_sync            (lib/commands/integration.sh)
#   context7     devorq::cmd_context7        (lib/commands/integration.sh)
#   rules        devorq::cmd_rules_dispatch  (lib/commands/rules.sh)
#   review       devorq::cmd_review          (lib/commands/review.sh)
#   version      devorq::cmd_version         (lib/commands/utils.sh)
#   upgrade      devorq::cmd_upgrade         (lib/commands/utils.sh)
#   build        devorq::cmd_build           (lib/commands/utils.sh)
#   uninstall    devorq::cmd_uninstall       (lib/commands/utils.sh)
#   stats        devorq::cmd_stats           (lib/commands/utils.sh)

set -euo pipefail

# ============================================================
# HELP
# ============================================================

help_delivery() {
    cat << "EOF"
DELIVERY DISPATCHER -- entrega (commit, sync, rules, review)

  commit [args]             Commit manual com convencao tipo(escopo):
  vps [args]                Gerenciar conexao VPS
  sync [args]               Sincronizar com HUB/VPS
  context7 [args]           Context7 integration
  rules <list|check|apply|bootstrap>
                            Regras enforced
  review [args]             Code review
  version                   Versao do DEVORQ
  upgrade                   Atualizar DEVORQ
  build                     Self-build (test + gates)
  uninstall                 Desinstalar DEVORQ
  stats                     Estatisticas de uso
EOF
}

# ============================================================
# SOURCE dos modulos
# ============================================================

# shellcheck source=../commands/commit.sh
source "${DEVORQ_LIB}/commands/commit.sh"
# shellcheck source=../commands/integration.sh
source "${DEVORQ_LIB}/commands/integration.sh"
# shellcheck source=../commands/rules.sh
source "${DEVORQ_LIB}/commands/rules.sh"
# shellcheck source=../commands/review.sh
source "${DEVORQ_LIB}/commands/review.sh"
# shellcheck source=../commands/utils.sh
source "${DEVORQ_LIB}/commands/utils.sh"
