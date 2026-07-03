#!/usr/bin/env bash
# lib/dispatchers/init.sh — DEVORQ v4.0.0
#
# Dispatcher: INIT
# Responsabilidade unica: bootstrap e configuracao do projeto.
#
# Comandos:
#   init          devorq::cmd_init        (lib/commands/workflow.sh)
#   foundation    devorq::cmd_foundation  (lib/commands/foundation.sh)
#   mode          devorq::cmd_mode        (lib/commands/mode.sh)
#   test          devorq::cmd_test        (lib/commands/test.sh)
#
# Carrega os modulos de comando via source. As funcoes sao expostas
# ao router (bin/devorq) atraves do dynamic source loop.

set -euo pipefail

# ============================================================
# HELP
# ============================================================

help_init() {
    cat << "EOF"
INIT DISPATCHER \xe2\x80\x94 bootstrap e configuracao do projeto

  init                       Inicializar .devorq/ no projeto
  foundation                 Criar 5W2H, Premissas, Riscos, Requisitos, Restricoes
  mode <AUTO|CLASSIC>        Selecionar modo de execucao
  test                       Executar suite de testes
EOF
}

# ============================================================
# SOURCE dos modulos (idempotente: bash redefine funcoes)
# ============================================================

# shellcheck source=../commands/workflow.sh
source "${DEVORQ_LIB}/commands/workflow.sh"
# shellcheck source=../commands/foundation.sh
source "${DEVORQ_LIB}/commands/foundation.sh"
# shellcheck source=../commands/mode.sh
source "${DEVORQ_LIB}/commands/mode.sh"
# shellcheck source=../commands/test.sh
source "${DEVORQ_LIB}/commands/test.sh"
