#!/usr/bin/env bash
# lib/dispatchers/workflow.sh -- DEVORQ v4.1.0
#
# Dispatcher: WORKFLOW
# Responsabilidade unica: execucao de workflow, gates, AUTO e DDD.
#
# Comandos:
#   flow          devorq::cmd_flow          (lib/commands/workflow.sh)
#   gate [N]      devorq::cmd_gate          (lib/commands/workflow.sh)
#   auto          devorq::cmd_auto          (lib/commands/auto.sh)
#   ddd           devorq::cmd_ddd_validate  (lib/commands/ddd.sh)
#                 devorq::cmd_ddd           (lib/commands/exploration.sh)
#   scope         devorq::cmd_scope         (lib/commands/exploration.sh)
#   env           devorq::cmd_env           (lib/commands/exploration.sh)
#   spec          devorq::cmd_spec          (lib/commands/exploration.sh)
#   grill         devorq::cmd_grill         (lib/commands/grill.sh)
#   brainstorm    devorq::cmd_brainstorm    (lib/commands/brainstorm.sh)

set -euo pipefail

# ============================================================
# HELP
# ============================================================

help_workflow() {
    cat << "EOF"
WORKFLOW DISPATCHER -- execucao de workflow, gates e DDD

  flow "<intent>"           Workflow completo (gates 0->7)
  gate [0-7]                Executar gate especifico
  auto [args]               Executar modo AUTO (story-by-story)
  ddd <validate|explore>    Domain-Driven Design
  scope [args]              Verificar escopo do projeto
  env [args]                Detectar ambiente
  spec [args]               Spec utilities
  grill [args]              Workshop tecnico
  brainstorm [args]         Brainstorm de ideias
EOF
}

# ============================================================
# SOURCE dos modulos
# ============================================================

# shellcheck source=../commands/workflow.sh
source "${DEVORQ_LIB}/commands/workflow.sh"
# shellcheck source=../commands/auto.sh
source "${DEVORQ_LIB}/commands/auto.sh"
# shellcheck source=../commands/loop.sh
source "${DEVORQ_LIB}/commands/loop.sh"
# shellcheck source=../commands/ddd.sh
source "${DEVORQ_LIB}/commands/ddd.sh"
# shellcheck source=../commands/exploration.sh
source "${DEVORQ_LIB}/commands/exploration.sh"
# shellcheck source=../commands/grill.sh
source "${DEVORQ_LIB}/commands/grill.sh"
# shellcheck source=../commands/brainstorm.sh
source "${DEVORQ_LIB}/commands/brainstorm.sh"
