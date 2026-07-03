#!/usr/bin/env bash
# lib/dispatchers/state.sh -- DEVORQ v4.0.0
#
# Dispatcher: STATE
# Responsabilidade unica: gestao de estado do projeto.
#
# Comandos:
#   lessons     devorq::cmd_lessons    (lib/commands/lessons.sh)
#   context     devorq::cmd_context    (lib/commands/context.sh)
#   compact     devorq::cmd_compact    (lib/commands/context.sh)
#   unify       devorq::cmd_unify      (lib/commands/exploration.sh)
#   debug       devorq::cmd_debug      (lib/commands/debug.sh)

set -euo pipefail

# ============================================================
# HELP
# ============================================================

help_state() {
    cat << "EOF"
STATE DISPATCHER -- gestao de estado do projeto

  lessons <capture|list|search|validate|approve|compile|migrate>
                           Gerenciar licoes aprendidas
  context <get|set|merge|stats|clear>
                           Gerenciar contexto do projeto
  compact                  Gerar handoff para proxima sessao
  unify [args]             Unificar artefatos
  debug [args]             Debug sistematico
EOF
}

# ============================================================
# SOURCE dos modulos
# ============================================================

# shellcheck source=../commands/lessons.sh
source "${DEVORQ_LIB}/commands/lessons.sh"
# shellcheck source=../commands/context.sh
source "${DEVORQ_LIB}/commands/context.sh"
# shellcheck source=../commands/exploration.sh
source "${DEVORQ_LIB}/commands/exploration.sh"
# shellcheck source=../commands/debug.sh
source "${DEVORQ_LIB}/commands/debug.sh"
