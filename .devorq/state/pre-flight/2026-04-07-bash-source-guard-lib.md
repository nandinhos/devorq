# Pre-flight Report: Bash Source Guard Implementation

## Informações Gerais
- **Data**: 2026-04-07
- **Contexto**: Aplicação da lição aprendida "Bash Dual-Use Source Guard"
- **Objetivo**: Garantir que as bibliotecas em `lib/*.sh` não executem lógica global quando executadas diretamente.

## Verificação de Dependências
- **Bash**: 4.0+ (Necessário para BASH_SOURCE) - [OK]
- **Permissões de Escrita**: [OK]

## Scan de Vulnerabilidades
Foram identificados 21 scripts em `lib/` sem o guard de source:
- `lib/cli.sh`
- `lib/core.sh`
- `lib/detect.sh`
- `lib/detection.sh`
- `lib/error-recovery.sh`
- `lib/feature-lifecycle.sh`
- `lib/file-ops.sh`
- `lib/handoff.sh`
- `lib/lessons.sh`
- `lib/loader.sh`
- `lib/mcp-fallback.sh`
- `lib/mcp-health-check.sh`
- `lib/mcp-json-generator.sh`
- `lib/mcp-validate.sh`
- `lib/mcp.sh`
- `lib/orchestration.sh`
- `lib/stack-detector.sh`
- `lib/state.sh`
- `lib/workflow-commit.sh`
- `lib/workflow-release.sh`
- `lib/workflow-sync.sh`

## Estratégia de Implementação
A inserção será feita de forma manual via edição de arquivo por arquivo (ou chunked) para garantir que o posicionamento não quebre definições essenciais.

Padrão:
```bash
[[ "${BASH_SOURCE[0]}" != "$0" ]] && return 0
```

## Pontos de Risco
O maior risco é inserir o guard em scripts que **deveriam** ser executáveis por conta própria, como `bin/devorq` (que não está em `lib/`). Em `lib/`, todos devem ser bibliotecas.

## Veredito Pre-flight
**PRONTO PARA IMPLEMENTAÇÃO**. Os arquivos são bibliotecas puras ou bibliotecas com lógica de CLI acoplada que precisa de isolamento.
