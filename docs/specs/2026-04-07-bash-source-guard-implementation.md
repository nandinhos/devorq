# Spec: Bash Dual-Use Source Guard Implementation

## Contexto
Muitos scripts na pasta `lib/` do projeto DEVORQ são projetados para serem carregados via `source` (bibliotecas), mas alguns podem conter lógica de execução ou cases que não devem ser disparados acidentalmente se o arquivo for executado diretamente ou se o ambiente de execução for ambíguo.

A lição aprendida `2026-04-07-bash-dual-use-source-guard` estabelece o uso do guard canônico para prevenir execuções indesejadas.

## Objetivo
Implementar o guard `[[ "${BASH_SOURCE[0]}" != "$0" ]] && return 0` em todos os scripts identificados em `lib/`.

## Arquivos Alvo
1. `lib/cli.sh`
2. `lib/detection.sh`
3. `lib/error-recovery.sh`
4. `lib/lessons.sh`
5. `lib/mcp-fallback.sh`
6. `lib/mcp-validate.sh`
7. `lib/orchestration.sh`
8. `lib/stack-detector.sh`

## Padrão de Implementação
O guard deve ser inserido logo após o shebang (`#!/bin/bash`) e comentários iniciais de cabeçalho, mas ANTES de qualquer comando executável ou definições de funções (embora o foco principal seja antes de lógica de nível superior).

Exemplo:
```bash
#!/bin/bash

# [Cabeçalho]
[[ "${BASH_SOURCE[0]}" != "$0" ]] && return 0

# [Lógica do script]
```

## Requisitos de Qualidade (Quality Gate)
- O script deve continuar funcionando normalmente quando carregado via `source`.
- O script deve encerrar silenciosamente com `exit 0` (via return 0 no contexto de source/script) se executado diretamente, a menos que o script tenha uma função CLI explícita (nesse caso, o guard deve envolver apenas a lógica de execução da CLI).
- **Nota**: No caso do DEVORQ, esses arquivos em `lib/` são prioritariamente bibliotecas.

## Plano de Reversão
Remoção da linha adicionada.
