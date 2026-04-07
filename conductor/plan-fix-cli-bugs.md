# Plano de Correção: Bugs de Sintaxe no CLI DEVORQ

## Objetivo
Corrigir os erros de "integer expression expected" nos subcomandos `spec status` e `spec update` do CLI `bin/devorq`.

## Background & Motivação
A implementação atual utiliza `related_files=$(grep -c ... || echo "0")`. Como o `grep -c` retorna 0 acompanhado de um código de saída 1 quando não encontra correspondências, o operador `|| echo "0"` é acionado, resultando em uma string "0\n0", o que quebra as comparações numéricas `[ "$related_files" -gt 0 ]`.

## Key Files & Context
- `bin/devorq`: Contém as funções `spec_status()` e `spec_update()`.

## Implementation Plan

### 1. Refatorar Contagens em `spec_status()`
Substituir as atribuições de `related_files` e `related_tasks` para usar `wc -l`.

**Mudanças em `bin/devorq`:**
- Alterar linha 302:
  ```bash
  related_files=$(awk '/^related_files:/,/^---/' "$spec_file" 2>/dev/null | grep "^  - " | wc -l | xargs)
  ```
- Alterar linha 306:
  ```bash
  related_tasks=$(grep "^  - TASK-" "$spec_file" 2>/dev/null | wc -l | xargs)
  ```

### 2. Refatorar Contagens em `spec_update()`
Aplicar a mesma correção na função de atualização automática.

**Mudanças em `bin/devorq`:**
- Alterar linha 361:
  ```bash
  related_files=$(awk '/^related_files:/,/^---/' "$spec_file" 2>/dev/null | grep "^  - " | wc -l | xargs)
  ```

## Verification & Testing
1. Executar `./bin/devorq spec status` e verificar se os erros de sintaxe desapareceram e os números estão corretos.
2. Executar `./bin/devorq spec update` e verificar se a atualização de status (`approved` -> `implemented`) funciona sem erros.
3. Validar se o resumo final exibe os números corretamente (ex: `Resumo: 0 approved, 6 implemented`).
