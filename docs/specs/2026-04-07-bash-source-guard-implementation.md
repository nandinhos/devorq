---
id: SPEC-2026-04-07-002
title: Implementação do Bash Dual-Use Source Guard
domain: arquitetura
status: implemented
priority: high
owner: team-core
created_at: 2026-04-07
updated_at: 2026-04-07
source: manual
related_tasks: []
related_files: ["lib/core.sh", "lib/workflow-commit.sh", "lib/activation-snapshot.sh"]
---

# Spec: Bash Dual-Use Source Guard Implementation

## Contexto
Muitos scripts na pasta `lib/` do projeto DEVORQ são projetados para serem carregados via `source` (bibliotecas), mas alguns podem conter lógica de execução ou cases que não devem ser disparados acidentalmente se o arquivo for executado diretamente ou se o ambiente de execução for ambíguo.

A lição aprendida `2026-04-07-bash-dual-use-source-guard` estabelece o uso do guard canônico para prevenir execuções indesejadas.

## Objetivo
Implementar o guard `if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then echo "ERRO: Este módulo deve ser carregado via 'source', não executado." >&2; exit 1; fi` em todos os scripts identificados em `lib/`.

## Arquivos Alvo
1. `lib/cli.sh`
2. `lib/detection.sh`
3. `lib/error-recovery.sh`
4. `lib/lessons.sh`
5. `lib/mcp-fallback.sh`
6. `lib/mcp-validate.sh`
7. `lib/orchestration.sh`
8. `lib/stack-detector.sh`
