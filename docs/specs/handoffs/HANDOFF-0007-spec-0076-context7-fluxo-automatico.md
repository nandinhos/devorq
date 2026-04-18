# HANDOFF DEVORQ — 20260418_054800

**Destinatário**: MiniMax
**Gerado por**: Claude Code (Sonnet 4.6)
**Projeto**: DEVORQ — Meta-framework de orquestração Multi-LLM
**Gate**: 4 — Transferência para implementação

---

## CONTEXTO

- **Stack**: Shell/Bash puro (4.0+) + Markdown (SKILL.md files)
- **Branch**: `main`
- **Último commit**: `c8f778d feat(workflow): adiciona rastreabilidade de panes, hook pre-commit e integração formal de skills`
- **Versão DEVORQ**: v2.1
- **Status**: SPEC-0076 criada e aprovada no Gate 1. Task list pronta. Aguardando implementação.

### O que foi feito nesta sessão (Claude Code)

1. Análise arquitetural da integração MCP Context7 no projeto
2. Descoberta crítica: as funções Bash de MCP (`lib/mcp-validate.sh` etc.) são stubs simulados na camada errada
3. Identificação do gap real: SKILL.md das skills não instruem o LLM sobre COMO chamar Context7
4. Criação da SPEC-0076: `docs/specs/draft/SPEC-0076-18-04-2026-context7-fluxo-automatico.md`
5. Task list: `.devorq/state/tasklist/spec-0076-context7-fluxo-automatico-tasks.md`

---

## TAREFA

Implementar **4 mudanças** em arquivos de configuração e skill, conforme SPEC-0076. **Todas as mudanças são em JSON e Markdown** — nenhum código Bash envolvido.

### Visão geral das 4 tasks

| Task | Arquivo | O que fazer |
|---|---|---|
| T1 | `.mcp.json` | Adicionar entrada `context7` com servidor npx |
| T2 | `.devorq/skills/pre-flight/SKILL.md` | Adicionar Step 3b com chamadas explícitas a Context7 |
| T3 | `.devorq/skills/constraint-loader/SKILL.md` | Adicionar Step 0b com Context7 para padrões de framework |
| T4 | `.devorq/skills/learned-lesson/SKILL.md` | Substituir instrução vaga do Gate 6 por chamada explícita |

**Ordem**: todas independentes — podem ser feitas em qualquer sequência.

---

## ARTEFATOS DE PLANEJAMENTO

Leia obrigatoriamente antes de implementar:

1. **SPEC completa**: `docs/specs/draft/SPEC-0076-18-04-2026-context7-fluxo-automatico.md`
   - Contém: diagnóstico, código JSON/Markdown exato de cada mudança, critérios de aceite, riscos

2. **Task list detalhada**: `.devorq/state/tasklist/spec-0076-context7-fluxo-automatico-tasks.md`
   - Contém: FAZER/NÃO FAZER/Done Criteria por task + comandos de verificação final

---

## CONSTRAINTS OBRIGATÓRIOS

- **Ferramentas MCP a referenciar nas skills**: `mcp__context7__resolve-library-id` e `mcp__context7__query-docs`
- **Context7 é público**: sem API key, sem `env` no `.mcp.json`
- **Context7 sempre opcional nas skills**: se não disponível, LLM deve pular e registrar NÃO_APLICÁVEL
- **Preservar estrutura existente**: cada skill tem seções que não devem ser tocadas

---

## NUNCA FAZER

- ❌ NÃO modificar `lib/mcp-validate.sh`, `lib/mcp-fallback.sh`, `lib/mcp-json-generator.sh`, `lib/mcp.sh`, `lib/mcp-health-check.sh` — são stubs na camada errada; deixar intactos
- ❌ NÃO criar comando Bash `devorq mcp setup` — LLM não invoca MCP via shell
- ❌ NÃO alterar Gate 5 e Gate 7 da `learned-lesson` — apenas o Gate 6
- ❌ NÃO tornar Context7 bloqueante em nenhuma skill — é validação complementar, não gate obrigatório
- ❌ NÃO adicionar `CONTEXT7_API_KEY` ao `.mcp.json` — servidor é público
- ❌ NÃO remover `serena` nem `basic-memory` do `.mcp.json`
- ❌ NÃO alterar `bin/devorq` nesta SPEC

---

## ARQUIVOS PERMITIDOS (modificar)

```
.mcp.json                                    ← T1
.devorq/skills/pre-flight/SKILL.md           ← T2
.devorq/skills/constraint-loader/SKILL.md    ← T3
.devorq/skills/learned-lesson/SKILL.md       ← T4
docs/specs/draft/SPEC-0076-*.md              ← atualizar status para approved (opcional)
docs/specs/_index.md                         ← atualizar status e contagem
```

## ARQUIVOS PROIBIDOS (não tocar)

```
lib/mcp-validate.sh
lib/mcp-fallback.sh
lib/mcp-json-generator.sh
lib/mcp.sh
lib/mcp-health-check.sh
bin/devorq
.devorq/skills/quality-gate/SKILL.md
.devorq/skills/spec/SKILL.md
tests/
```

---

## CÓDIGO EXATO A INSERIR

### T1 — `.mcp.json` (estado final completo)

```json
{
  "mcpServers": {
    "serena": {
      "command": "uvx",
      "args": [
        "serena",
        "--project=."
      ]
    },
    "basic-memory": {
      "command": "uvx",
      "args": [
        "basic-memory",
        "mcp"
      ]
    },
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp@latest"]
    }
  }
}
```

### T2 — Bloco a inserir em `pre-flight/SKILL.md` (após Step 3)

```markdown
### Step 3b: Validar contra Documentação Oficial (Context7)

Se a stack usa framework externo (Laravel, Livewire, React, Next.js, etc.):

1. Resolver o ID da biblioteca:
   - `mcp__context7__resolve-library-id` com query = nome do framework (ex: "laravel", "livewire", "react")
   - Usar o `libraryId` retornado no próximo passo

2. Consultar documentação para cada enum/método/classe usada:
   - `mcp__context7__query-docs` com `libraryId` + `topic` = enum ou método em análise
   - Confirmar: existe na versão usada? Valores são os corretos?

3. Registrar no PRE-FLIGHT REPORT:
   ```
   Context7 — [Enum/Método]: confirmado em [Framework] docs ✅
   Context7 — [Enum/Método]: não encontrado — verificar manualmente ⚠️
   ```

Se stack = Bash/Shell puro ou Context7 não disponível: pular esta etapa silenciosamente.
```

### T3 — Bloco a inserir em `constraint-loader/SKILL.md` (após =REUSE SCAN=)

```markdown
#### Step 0b: Buscar Padrão Oficial (Context7)

Se a task envolve um framework externo (Laravel, Livewire, Next.js, React, etc.):

1. `mcp__context7__resolve-library-id` → obter `libraryId` do framework
2. `mcp__context7__query-docs` com `topic` = padrão de implementação da task
   - Ex: "Livewire form component", "Laravel Eloquent query builder", "React useEffect"
3. Adicionar ao output `=== CONSTRAINT LOADER ===`:
   ```
   Context7: [padrão X] validado em [Framework] docs — usar abordagem Y
   ```

Objetivo: garantir que a implementação segue o padrão oficial atual, não código legado ou memória de treinamento desatualizada.

Se Context7 não disponível: pular e registrar "Context7: não disponível".
```

### T4 — Substituição no Gate 6 da `learned-lesson/SKILL.md`

**Localizar e substituir** a linha:
```
1. Context7 consulta automaticamente quando aplicável
```

**Por**:
```markdown
1. **Validação Context7** (quando a lição envolve framework/biblioteca):
   - `mcp__context7__resolve-library-id` → identificar a biblioteca relevante para a lição
   - `mcp__context7__query-docs` com `topic` = conceito central da lição
   - Classificar conforme resultado da consulta:
     - **CONFIRMADO** — documentação confirma a lição como correta e atual
     - **PARCIAL** — documentação confirma parte; diverge em algum ponto
     - **INCORRETO** — documentação contradiz a lição (revisar antes de aplicar)
     - **NÃO_APLICÁVEL** — lição é sobre processo/negócio, não framework externo
   - Registrar no front matter da lição: `context7_result: CONFIRMADO`
   - Se Context7 não disponível: classificar como `NÃO_APLICÁVEL` e prosseguir
```

---

## DONE CRITERIA (verificação final)

```bash
# T1
python3 -c "import json; d=json.load(open('.mcp.json')); assert 'context7' in d['mcpServers']; print('T1: OK')"

# T2
grep -c "mcp__context7__resolve-library-id" .devorq/skills/pre-flight/SKILL.md && echo "T2: OK"

# T3
grep -c "mcp__context7" .devorq/skills/constraint-loader/SKILL.md && echo "T3: OK"

# T4
grep -c "mcp__context7__resolve-library-id" .devorq/skills/learned-lesson/SKILL.md && echo "T4a: OK"
grep -c "CONFIRMADO\|PARCIAL\|INCORRETO" .devorq/skills/learned-lesson/SKILL.md && echo "T4b: OK"

# Verificar que lib/mcp-*.sh NÃO foram tocados
git diff lib/mcp-validate.sh lib/mcp-fallback.sh lib/mcp-json-generator.sh 2>/dev/null | wc -l
# Esperado: 0 (zero linhas de diff)
```

---

## COMMIT ESPERADO

```
feat(skills): integra Context7 explicitamente em pre-flight, constraint-loader e learned-lesson
```

---

## PRÓXIMA SPEC APÓS ESTA

**SPEC-0077** — Grafo de Dependências das Skills: adicionar `depends_on:` ao frontmatter de 8 skills + subcomando `./bin/devorq skills graph`.
