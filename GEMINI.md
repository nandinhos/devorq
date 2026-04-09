# GEMINI CLI - DIRETRIZES DE PROJETO

Este arquivo contém instruções específicas para o Gemini CLI operar com segurança e eficiência sob a governança DEVORQ.

## Restrições Críticas (Bypass Guard)
- **Front Matter:** Proibido o uso de qualquer campo YAML fora dos 11 campos canônicos definidos em `SPEC-2026-04-05-001`.
- **Enums:** Use exclusivamente os valores definidos para `status` (ex: `draft`, `approved`) e `domain` (ex: `arquitetura`, `operacao`).
- **Indexação:** Toda criação ou alteração de spec EXIGE a execução de `./bin/spec-index`.

## Comandos Permitidos (Shell)
- Sempre use `chmod +x` antes de executar binários do `./bin/`.
- Priorize `shellcheck` para validar scripts shell.

## Verificação de Sucesso
Um trabalho só é considerado concluído se o índice `_index.md` apresentar zero "N/A".
