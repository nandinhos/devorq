# Regras do Projeto - DEVORQ Framework

## Contexto
- **Stack:** Bash Puro (4.0+) / Shell Scripting
- **Padrão:** Orquestração Multi-LLM baseada em Gates de Aprovação.

## Arquitetura Primeiro
1. **Especificação:** Toda feature ou bugfix deve ser documentada em `docs/specs/` antes de qualquer código ser escrito.
2. **Handoff:** Trocas de contexto entre chats devem usar o comando `handoff generate`.

## Padrões de Código
- **Shell:** `set -eEo pipefail`, trap para erros em `lib/error-recovery.sh`.
- **Mensagens de Commit:** Convencionais em pt-BR (ex: `feat(lib): descrição`).
- **Documentação:** Markdown com Front Matter YAML canônico.
