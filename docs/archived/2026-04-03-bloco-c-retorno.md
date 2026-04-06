# RETORNO — Bloco C: Refatoração MCP

- **SHA commit C1 (testes & refatoração MCP)**: `7e8f284`
- **Testes functional.bats**: todos passando (2/2)
- **Suite completa bats tests/**: 49 testes / 49 passando
- **Desvios do plano**: nenhum
- **Erros encontrados**: nenhum

---

## Execução Realizada

### Step 0 — Verificação de divergência
- Commits locais do Bloco B identificados e autorizados pelo arquiteto
- Prosseguido com execução normal

### Sub-task C1: Testes modificados (TDD)
- **Arquivo**: `tests/functional.bats`
- **Ação**: Substituído teste falho por dois novos cenários:
  1. Node.js genérico (sem Next.js) → retorna vazio
  2. Node.js com next.config.js → retorna `nextjs-mcp`
- **Verificação RED**: Confirmado que o teste original falhou com output não-vazio
- **Verificação GREEN**: Ambos os novos testes passaram

### Sub-task C2: Reverter injeção falsa
- **Arquivo**: `lib/stack-detector.sh`
- **Ação**: Removidas linhas `mcps+=("nodejs-mcp")` e `mcps+=("python-mcp")` da função `stack_get_mcps`
- **Resultado**: Apenas frameworks específicos (Next.js, Django) disparam MCPs condicionais

### Verificação de regressão
- Executado `bats tests/` → 49/49 passando
- Nenhum arquivo proibido modificado

### Commit
- Criado commit `7e8f284` com mensagem seguindo padrão DEVORQ

---

## Done Criteria Checklist

- [x] Arquivo `tests/functional.bats` atualizado para conter separação entre framework específico vs ambiente cru.
- [x] O teste validou corretamente que no branch genérico de NodeJS, o `stack_get_mcps` retorna string vazia.
- [x] Alteração de `lib/stack-detector.sh` aplicada sem falhas e confirmando o GREEN generalizado.
- [x] Arquivos de outras bibliotecas do devorq permaneceram intactos.