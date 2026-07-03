#!/usr/bin/env bash
# lib/dispatchers/discovery.sh -- DEVORQ v4.0.0
#
# Dispatcher: DISCOVERY
# Responsabilidade unica: descoberta de capacidades (skills, info).
#
# Comandos:
#   skills      devorq::cmd_skills     (lib/commands/skills.sh)
#   info        devorq::cmd_info       (lib/commands/info.sh)

set -euo pipefail

# ============================================================
# HELP
# ============================================================

help_discovery() {
    cat << "EOF"
DISCOVERY DISPATCHER -- descoberta de capacidades

  skills [list|load]        Listar/carregar skills
  info                      Informacoes do sistema
EOF
}

# ============================================================
# SOURCE dos modulos
# ============================================================

# shellcheck source=../commands/skills.sh
source "${DEVORQ_LIB}/commands/skills.sh"
# shellcheck source=../commands/info.sh
source "${DEVORQ_LIB}/commands/info.sh"
