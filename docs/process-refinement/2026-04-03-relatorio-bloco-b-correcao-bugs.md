# RELATÓRIO TÉCNICO — Bloco B: Correção de Bugs

**Data**: 2026-04-03  
**Executor**: Claude Code (Tier 2)  
**Tarefa**: Corrigir 4 bugs em lib/mcp-json-generator.sh, lib/stack-detector.sh, lib/detect.sh e bin/devorq

---

## RESUMO EXECUTIVO

| Métrica | Resultado |
|---------|-----------|
| Bugs corrigidos | 4/4 |
| Testes funcionales | 4/4 passando |
| Suite completa | 48/48 passando |
| Commits | 5 (4 bugs + 1 testes) |

---

## COMMITS REALIZADOS

| Bug | Commit SHA | Mensagem |
|-----|------------|----------|
| B5 | `84b3266` | fix(mcp-json-generator): refatorar helpers para modificar json_content via jq |
| B6 | `e97dc9d` | fix(stack-detector): alinhar stack_get_mcps com valores reais de stack_detect |
| B7 | `c86d0e3` | fix(detect): adicionar agrupamento lógico no find da função is_legacy |
| B8 | `3ea86a0` | fix(cli): validar existência do diretório skills antes de iterar em cmd_skills |
| Testes | `aed1d7a` | test(functional): adicionar testes para correções de bugs do Bloco B |

---

## CORREÇÕES APLICADAS

### B5: lib/mcp-json-generator.sh
- **Problema**: Helpers apenas faziam `echo` de mensagens, não modificavam `json_content`
- **Solução**: Refatorado para usar `jq` incremental. Helpers recebem JSON atual via parâmetro `$2` e retornam JSON enriquecido. Mensagens de progresso redirecionadas para `>&2`

### B6: lib/stack-detector.sh
- **Problema**: `stack_get_mcps` verificava `django` e `nextjs`, mas `stack_detect` retorna `nodejs` e `python`
- **Solução**: Case atualizado para valores reais. Adicionado `nodejs-mcp` e `python-mcp` como MCPs base, com verificação de subframeworks (Next.js, Django) dentro de cada case

### B7: lib/detect.sh
- **Problema**: `find "$root/tests" -name "*.php" -o -name "*.js"` sem agrupamento lógico
- **Solução**: Adicionado agrupamento com parênteses: `\( -name "*.php" -o -name "*.js" \)`

### B8: bin/devorq (cmd_skills)
- **Problema**: Iteração com glob sem verificação de existência do diretório causava item fantasma `*`
- **Solução**: Adicionado guard `[ ! -d "$skills_dir" ]` antes do loop, e `[ -d "$skill_dir" ] || continue` dentro do loop

---

## VERIFICAÇÕES REALIZADAS

### Testes Funcionais
```
$ bats tests/functional.bats
1..4
ok 1 mcp_generator_create com stack laravel gera JSON com chave mcpServers
ok 2 stack_get_mcps com input nodejs retorna resultado não vazio
ok 3 is_legacy com diretório tests contendo .js não retorna falso positivo
ok 4 cmd_skills em diretório sem skills retorna mensagem limpa sem item fantasma

4 tests, 0 failures
```

### Suite Completa
```
$ bats tests/
48 tests, 0 failures
```

### Smoke Test CLI
```
$ ./bin/devorq skills
Skills DEVORQ (17 skills):
  - brainstorming v1.0.0
  - break v1.0.0
  - code-review v1.0.0
  - constraint-loader v1.0.0
  - env-context v1.0.0
  - handoff v1.0.0
  - integrity-guardian v1.0.0
  - learned-lesson v1.0.0
  - pre-flight v1.0.0
  - quality-gate v1.0.0
  - schema-validate v1.0.0
  - scope-guard v1.0.0
  - session-audit v1.1.0
  - spec-export v1.0.0
  - spec v1.0.0
  - systematic-debugging v1.0.0
  - tdd v1.0.0
```

---

## DESVIOS DO PLANO

| Item | Desvio | Justificativa |
|------|--------|----------------|
| B6 (stack_get_mcps) | Adicionado MCP base para nodejs/python | O teste original esperava resultado não vazio para nodejs sem next.config.js. O plano verificava apenas subframeworks, mas o bug original era que NUNCA retornava nada. Adicionado MCP base para garantir que a função retorne algo para stacks genéricas |

**Nota**: O desvio foi necessário para que o teste B6 passasse. O comportamento esperado é que `stack_get_mcps` retorne MCPs base (nodejs-mcp, python-mcp) além dos MCPs de subframework.

---

## ARQUIVOS MODIFICADOS

| Arquivo | Ação | Linhas alteradas |
|---------|------|------------------|
| lib/mcp-json-generator.sh | Modificado | ~70 linhas refatoradas |
| lib/stack-detector.sh | Modificado | 13 linhas inseridas, 7 removidas |
| lib/detect.sh | Modificado | 1 linha |
| bin/devorq | Modificado | 13 linhas inseridas, 2 removidas |
| tests/functional.bats | Criado | 94 linhas |

---

## CHECKLIST DONE CRITERIA

- [x] `tests/functional.bats` criado com 4 testes
- [x] Cada teste falhou no RED (confirmado antes de implementar)
- [x] `mcp_generator_create` com stack laravel gera JSON com chave `mcpServers`
- [x] `stack_get_mcps` com input `nodejs` retorna valor não vazio
- [x] `is_legacy` com diretório `tests/` contendo `.js` retorna "modern" (não legacy)
- [x] `cmd_skills` em dir sem `skills/` retorna "0 skills" sem item fantasma
- [x] `bats tests/functional.bats` → 4/4 ok
- [x] `bats tests/` → 48/48 ok (44 anteriores + 4 novos, sem regressões)
- [x] 5 commits individuais com mensagens convencionais em pt-BR
- [x] Nenhum arquivo fora da lista autorizada modificado

---

## PRÓXIMO PASSO

Este relatório deve ser lido pelo arquiteto (Tier 1) junto com o handoff original para decisão sobre Bloco C.

**Para abrir em nova sessão LLM**:
1. Abrir nova janela/sessão
2. Ler `docs/handoffs/2026-04-03-bloco-b-correcao-bugs.md`
3. Ler `docs/process-refinement/2026-04-03-relatorio-bloco-b-correcao-bugs.md`
4. Decidir se há desvios a corrigir antes do Bloco C
