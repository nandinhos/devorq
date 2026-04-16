# Lição — Scripts Bash dual-use precisam de guard contra execução ao ser sourced

## Contexto
- Quando: 2026-04-07
- Onde: `lib/orchestration/flow.sh` — bloco `case "${1:-}"` no final do arquivo
- Tipo: bug | melhoria-processo
- Classificação: **Reusable knowledge / Cross-project concern / Bug class conhecida**

## Problema
Scripts Bash que funcionam como biblioteca (sourced por testes e módulos) **e** como executável direto executam o bloco `case` em ambos os casos quando não há guard. Ao fazer `source flow.sh` nos testes, o CLI imprimia o help inteiro no stdout — contaminando todos os testes que dependiam de funções internas (ex: `phase1_detection`).

## Causa Raiz
Ausência do guard padrão Bash para diferenciar execução direta de source. Padrão conhecido mas não estava como regra explícita nem verificado no pre-flight ou quality-gate do projeto.

## Solução
```bash
# Adicionar ANTES do bloco case/main de qualquer script dual-use:
[[ "${BASH_SOURCE[0]}" != "$0" ]] && return 0
```
- Quando **sourced**: `BASH_SOURCE[0]` ≠ `$0` → retorna imediatamente
- Quando **executado diretamente**: `BASH_SOURCE[0]` = `$0` → continua normalmente

## Prevenção — Duas Camadas

### Camada 1: Pre-flight (prevenção rápida — dev experience)
Verificar automaticamente antes de implementar:
- Arquivos em `lib/**/*.sh` que contenham `case`, blocos `if [ "$0"` ou chamadas diretas de função no escopo global
- Ausência do guard `[[ "${BASH_SOURCE[0]}" != "$0" ]]`
- Emitir aviso (não bloqueio) para corrigir antes do quality-gate

### Camada 2: Quality Gate (enforcement obrigatório)
Regra formal a ser adicionada:

> **Scripts Bash dual-use** (library + executable) DEVEM conter o guard:
> `[[ "${BASH_SOURCE[0]}" != "$0" ]] && return 0`
> antes de qualquer bloco `case` ou lógica de execução direta.

## TODO para próxima sessão
- [ ] Criar spec para incorporar regra no `quality-gate/SKILL.md`
- [ ] Criar spec para adicionar verificação automática no `pre-flight/SKILL.md`
- [ ] Verificar outros scripts em `lib/` que possam ter o padrão ausente
- [ ] Considerar como cross-project concern (aplicável a todo projeto que usa DEVORQ)

## Status
- [x] Gate 5 aprovado pelo usuário
- [x] Gate 6 — lessons validate (concluído)
- [x] Gate 7 — lessons apply quality-gate + pre-flight (concluído)
