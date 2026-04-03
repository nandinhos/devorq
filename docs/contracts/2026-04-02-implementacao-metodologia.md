# CONTRATO DE ESCOPO — Implementação da Metodologia DEVORQ v2.1

**Data**: 2026-04-02
**Arquiteto**: Nando Dev + Claude Code Sonnet 4.6 (Tier 1)
**Executor**: Tier 2 — Gemini | Antigravity | OpenCode (qualquer disponível)
**Tipo**: feature + bugfix
**Complexidade**: média
**Branch de destino**: `main`
**Worktree de trabalho**: `.worktrees/feat-metodologia-spec-break-thin-client`

---

## CONTEXTO

Este contrato consolida o trabalho planejado em sessão de arquitetura de
2026-04-02. O DEVORQ está passando por refinamento da versão v2.0 para v2.1,
incorporando a metodologia de desenvolvimento LLM-agnostic com:
- Skills `/spec` e `/break` (decomposição de trabalho)
- Regra Thin Client, Fat Server (segurança)
- Step 0 de reuso no `constraint-loader`
- Correções de bugs identificados em code review (Codex)
- Documentação da arquitetura multi-LLM

O worktree `feat/metodologia-spec-break-thin-client` já contém parte do
trabalho implementado e testado. Este contrato cobre a finalização.

---

## FAZER

### Bloco A — Fechar worktree atual (em `.worktrees/feat-metodologia`)

1. Rodar suite completa de testes (44 testes esperados: 26 + 18)
2. Smoke test: `./bin/devorq skills` → 17 skills na lista
3. Commit das mudanças do worktree com mensagem convencional
4. Merge do branch `feat/metodologia-spec-break-thin-client` em `main`

### Bloco B — Correções de bugs (TDD obrigatório, novo arquivo tests/functional.bats)

5. Corrigir `lib/mcp-json-generator.sh` — função `mcp_generator_create`
   - Refatorar para jq incremental (não concatenação de string JSON)
   - `_mcp_generator_add_laravel`, `_mcp_generator_add_nodejs`,
     `_mcp_generator_add_python` devem modificar `json_content`, não só `echo`

6. Corrigir `lib/stack-detector.sh` — função `stack_get_mcps`
   - Alinhar `case` com retornos reais de `stack_detect` (`nodejs`, `python`)
   - Mapear subframeworks explicitamente: `nextjs` → MCPs Node,
     `django` → MCPs Python

7. Corrigir `lib/detection.sh` — função `is_legacy`
   - Adicionar agrupamento lógico no `find`:
     `\( -name "*.php" -o -name "*.js" \)`

8. Corrigir `bin/devorq` — função `cmd_skills`
   - Adicionar `[ -d "$DEVORQ_DIR/skills" ]` antes do loop
   - Habilitar nullglob localmente ou validar existência antes de iterar

### Bloco C — Documentação e prompts

9. Criar `prompts/activation.md` — ativação universal LLM-agnostic
   - Não mencionar nenhuma LLM específica
   - Conter: como ativar, fluxo padrão, fluxo para projetos grandes,
     referência ao handoff package

10. Refatorar `prompts/gemini.md`, `prompts/opencode.md`,
    `prompts/antigravity.md` para adaptadores finos
    - Máximo 30 linhas cada
    - Conter apenas o que é específico da interface daquela LLM
    - Referenciar `prompts/activation.md` para o processo

11. Atualizar `CLAUDE.md` (seção de skills)
    - Adicionar `/spec` e `/break` na lista de 15 skills → 17 skills
    - Atualizar fluxo obrigatório v2.0 com `/spec` e `/break` no início

12. Criar ou atualizar `SLASH_COMMANDS.md`
    - Registrar `/spec` e `/break` com descrição e quando usar

13. Atualizar `.devorq/skills/handoff/SKILL.md`
    - Adicionar suporte ao formato de handoff package de 7 seções
    - Documentar o modelo híbrido (CLI gera seções automáticas,
      arquiteto preenche decisões)

---

## NÃO FAZER

- Não alterar `lib/*.sh` além dos bugs 5, 6, 7, 8
- Não criar skills além de `/spec` e `/break` (já criadas no worktree)
- Não modificar estrutura de `.devorq/agents/`
- Não alterar os gates 1-5 existentes
- Não implementar automação de dispatch de LLMs
- Não alterar `tests/sourcing.bats` nem `tests/paths.bats` (já validados)
- Não modificar `.devorq/skills/*/SKILL.md` além de `handoff/SKILL.md`

---

## ARQUIVOS AUTORIZADOS

**Bloco A:**
- `.worktrees/feat-metodologia/` (commitar e mergear)

**Bloco B:**
- `lib/mcp-json-generator.sh` (modificar)
- `lib/stack-detector.sh` (modificar)
- `lib/detection.sh` (modificar)
- `bin/devorq` (modificar — só função `cmd_skills`)
- `tests/functional.bats` (criar)

**Bloco C:**
- `prompts/activation.md` (criar)
- `prompts/gemini.md` (refatorar)
- `prompts/opencode.md` (refatorar)
- `prompts/antigravity.md` (refatorar)
- `CLAUDE.md` (modificar — só seção de skills e fluxo)
- `SLASH_COMMANDS.md` (criar ou modificar)
- `.devorq/skills/handoff/SKILL.md` (modificar)

---

## ARQUIVOS PROIBIDOS

- `lib/core.sh` — base estável, não tocar
- `lib/orchestration.sh` — corrigido na sessão anterior, não regredir
- `lib/state.sh` — corrigido, não regredir
- `.devorq/agents/*/SKILL.md` — fora do escopo
- `bin/devorq` (exceto função `cmd_skills`)
- `tests/sourcing.bats`, `tests/paths.bats` — suite estável

---

## DONE CRITERIA

### Bloco A
- [ ] `bats tests/` → 44/44 ok (suite completa)
- [ ] `./bin/devorq skills` → lista 17 skills (inclui spec e break)
- [ ] Branch `feat/metodologia-spec-break-thin-client` mergeado em `main`

### Bloco B
- [ ] `tests/functional.bats` criado com 4 testes (um por bug)
- [ ] `mcp_generator_create` com stack Laravel gera JSON com MCP Laravel
- [ ] `stack_get_mcps` com input `nodejs` retorna MCPs de Node (não vazio)
- [ ] `is_legacy` com projeto misto não gera falso positivo/negativo
- [ ] `cmd_skills` executado em dir sem skills retorna mensagem limpa (não item fantasma)
- [ ] `bats tests/functional.bats` → 4/4 ok

### Bloco C
- [ ] `prompts/activation.md` existe e não menciona nenhuma LLM por nome
- [ ] `prompts/gemini.md` tem menos de 30 linhas
- [ ] `prompts/opencode.md` tem menos de 30 linhas
- [ ] `prompts/antigravity.md` tem menos de 30 linhas
- [ ] `CLAUDE.md` menciona `/spec` e `/break` na lista de skills
- [ ] `SLASH_COMMANDS.md` registra `/spec` e `/break`
- [ ] `.devorq/skills/handoff/SKILL.md` menciona "handoff package" e "7 seções"

### Geral
- [ ] Nenhuma referência `.aidev/` em arquivos novos ou modificados
- [ ] `bats tests/` final → todas as suites passando
- [ ] Commits com mensagens convencionais em pt-BR

---

## RISCO IDENTIFICADO

**`mcp-json-generator.sh`**: refatorar para jq incremental é uma mudança
significativa na lógica de geração. Verificar que o formato do `.mcp.json`
gerado continua válido após a correção.

**`handoff/SKILL.md`**: mudança de comportamento da skill existente.
Verificar que Gate 4 continua funcionando no fluxo atual.

**Prompts refatorados**: os adaptadores finos devem preservar compatibilidade
com o que cada LLM espera para iniciar uma sessão. Testar manualmente antes
de commitar.

---

## REFERÊNCIAS

- ADR-001: `docs/adr/ADR-001-llm-agnostic-architecture.md`
- Fluxo multi-LLM: `docs/spec/2026-04-02-fluxo-multi-llm.md`
- Template de handoff: `docs/templates/handoff-package.md`
- Regras operacionais: `.devorq/rules/multi-llm.md`
- Plano de implementação (skills spec/break): `docs/superpowers/plans/2026-04-02-metodologia-spec-break-thin-client.md`
