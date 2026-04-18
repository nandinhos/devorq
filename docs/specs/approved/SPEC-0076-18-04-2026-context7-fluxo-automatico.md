---
id: SPEC-0076-18-04-2026-context7-fluxo-automatico
title: Context7 no Fluxo Automático — Integração nas Skills
domain: arquitetura
status: draft
priority: high
owner: nando-dev
source: code-review-hermes + analise-arquitetural
created_at: 2026-04-18
updated_at: 2026-04-18
related_tasks: []
related_files:
  - .mcp.json
  - .devorq/skills/pre-flight/SKILL.md
  - .devorq/skills/constraint-loader/SKILL.md
  - .devorq/skills/learned-lesson/SKILL.md
  - docs/proposals/code-review/code-review-hermes.md
---

# SPEC-0076 — Context7 no Fluxo Automático

**Data**: 2026-04-18
**Status**: draft
**Autor**: Nando Dev / Claude Code

---

## 1. Objetivo

Integrar o servidor MCP Context7 de forma efetiva ao fluxo DEVORQ, atuando na **camada correta**: as skills (SKILL.md) que instruem o LLM, não o Bash CLI. O Context7 deve ser chamado em três pontos do fluxo onde validação contra documentação oficial agrega valor real.

---

## 2. Diagnóstico — Por que o Context7 "não está no fluxo"

O Hermes marcou este item como CRÍTICO. A análise revelou que o problema tem duas faces:

### 2.1 Camada Bash — stubs simulados (não é aqui que agir)

Os arquivos `lib/mcp-validate.sh`, `lib/mcp-fallback.sh`, `lib/mcp-json-generator.sh` existem mas são **stubs de simulação**. Comentários como `# Em produção usar: npx @context7/mcp-server query "..."` confirmam que nunca foram integrados de verdade. Isso ocorre porque **MCP tools são ferramentas do LLM, não do Bash CLI** — o shell não tem como invocar um servidor MCP.

**Decisão**: Não alterar esses arquivos nesta SPEC. São legado arquitetural; corrigi-los seria refatoração de camada errada.

### 2.2 Camada Skills — gap real (aqui agir)

Os SKILL.md das skills que deveriam usar Context7 não instruem o LLM sobre **como** fazê-lo:

| Skill | Menção Context7 | Instrução de como chamar |
|---|---|---|
| `pre-flight` | Não menciona | Ausente |
| `constraint-loader` | Não menciona | Ausente |
| `learned-lesson` (Gate 6) | "consulta automaticamente" (vago) | Ausente |

### 2.3 Configuração — Context7 ausente do `.mcp.json`

O projeto tem `serena` e `basic-memory` configurados, mas **Context7 não está no `.mcp.json`**. Outros LLMs (MiniMax, Gemini) que trabalham no projeto não conseguem usar Context7 sem essa configuração.

---

## 3. Escopo

### 3.1 Escopo Positivo

- [ ] Adicionar Context7 ao `.mcp.json` do projeto
- [ ] Instruir explicitamente o LLM a chamar Context7 no Step 3 do `pre-flight`
- [ ] Instruir explicitamente o LLM a chamar Context7 no Step 0 do `constraint-loader`
- [ ] Substituir instrução vaga do Gate 6 em `learned-lesson` por chamada explícita com ferramentas e parâmetros

### 3.2 Escopo Negativo

- Não alterar `lib/mcp-validate.sh`, `lib/mcp-fallback.sh`, `lib/mcp-json-generator.sh`
- Não criar comando Bash `devorq mcp setup` (LLM não chama MCP via Bash)
- Não alterar `lib/mcp.sh`, `lib/mcp-health-check.sh`
- Não alterar o Gate 7 da `learned-lesson`
- Não criar nova skill ou novo comando CLI

---

## 4. Mudanças Técnicas Detalhadas

### T1 — Adicionar Context7 ao `.mcp.json`

**Arquivo**: `.mcp.json`

Adicionar entrada `context7` preservando `serena` e `basic-memory`:

```json
{
  "mcpServers": {
    "serena": {
      "command": "uvx",
      "args": ["serena", "--project=."]
    },
    "basic-memory": {
      "command": "uvx",
      "args": ["basic-memory", "mcp"]
    },
    "context7": {
      "command": "npx",
      "args": ["-y", "@upstash/context7-mcp@latest"]
    }
  }
}
```

**Impacto**: Qualquer LLM que carrega o projeto (Claude, MiniMax, Gemini, OpenCode) terá o servidor Context7 disponível. Sem autenticação necessária — Context7 é público.

---

### T2 — Context7 no `pre-flight` (Step 3)

**Arquivo**: `.devorq/skills/pre-flight/SKILL.md`

Adicionar sub-etapa ao final do **Step 3: Validar Cada Tipo**:

```markdown
### Step 3b: Validar contra Documentação Oficial (Context7)

Se a stack usa framework externo (Laravel, Livewire, React, etc.):

1. Resolver o ID da biblioteca:
   - `mcp__context7__resolve-library-id` com query = nome do framework (ex: "laravel", "livewire", "react")
   - Usar o `libraryId` retornado no próximo passo

2. Consultar documentação para cada enum/método/classe usada:
   - `mcp__context7__query-docs` com `libraryId` + `topic` = enum ou método
   - Confirmar: existe na versão usada? Valores são os corretos?

3. Registrar no PRE-FLIGHT REPORT:
   ```
   Context7 — [Enum/Método]: confirmado em [Framework] docs ✅
   Context7 — [Enum/Método]: não encontrado — verificar manualmente ⚠️
   ```

Se stack = Bash/Shell puro: Context7 não aplicável — pular esta etapa.
```

---

### T3 — Context7 no `constraint-loader` (Step 0)

**Arquivo**: `.devorq/skills/constraint-loader/SKILL.md`

Adicionar sub-etapa ao **Step 0: Buscar Código Reutilizável**, após a busca local:

```markdown
#### Step 0b: Buscar Padrão Oficial (Context7)

Se a task envolve um framework externo (Laravel, Livewire, Next.js, etc.):

1. `mcp__context7__resolve-library-id` → obter `libraryId` do framework
2. `mcp__context7__query-docs` com `topic` = padrão de implementação da task
   - Ex: "Livewire form component", "Laravel Eloquent query builder", "React useEffect"
3. Apresentar no output `=== CONSTRAINT LOADER ===`:
   ```
   Context7: [padrão X] validado em [Framework] docs — usar abordagem Y
   ```

Objetivo: garantir que a implementação segue o padrão oficial atual, não código legado ou memória de treinamento desatualizada.
```

---

### T4 — Context7 no Gate 6 da `learned-lesson`

**Arquivo**: `.devorq/skills/learned-lesson/SKILL.md`

Substituir o texto vago no Gate 6:

**Antes** (linha atual):
```
1. Context7 consulta automaticamente quando aplicável
```

**Depois** (instrução explícita):
```markdown
1. **Validação Context7** (quando a lição envolve framework/biblioteca):
   - `mcp__context7__resolve-library-id` → identificar a biblioteca relevante
   - `mcp__context7__query-docs` com `topic` = conceito central da lição
   - Classificar conforme resultado:
     - **CONFIRMADO** — documentação confirma a lição
     - **PARCIAL** — documentação confirma parte, diverge em outra
     - **INCORRETO** — documentação contradiz a lição (revisar antes de aplicar)
     - **NÃO_APLICÁVEL** — lição é sobre processo/negócio, não framework
   - Registrar parecer no front matter: `context7_result: CONFIRMADO`

2. Se Context7 não disponível: classificar como NÃO_APLICÁVEL e prosseguir.
```

---

## 5. Critérios de Aceite

- [ ] `.mcp.json` contém entrada `context7` com `command: npx` e args corretos
- [ ] `python3 -c "import json; d=json.load(open('.mcp.json')); assert 'context7' in d['mcpServers']"` passa
- [ ] `pre-flight/SKILL.md` contém `mcp__context7__resolve-library-id` e `mcp__context7__query-docs`
- [ ] `constraint-loader/SKILL.md` contém `mcp__context7__resolve-library-id`
- [ ] `learned-lesson/SKILL.md` contém instrução explícita com os 4 resultados possíveis e `context7_result`
- [ ] Nenhum dos arquivos `lib/mcp-*.sh` foi modificado

---

## 6. Dependências

- Servidor Context7: `@upstash/context7-mcp@latest` via npx (sem API key, público)
- `npx` disponível no ambiente (Node.js instalado)
- Ferramentas MCP disponíveis ao LLM: `mcp__context7__resolve-library-id`, `mcp__context7__query-docs`

---

## 7. Riscos

| Risco | Probabilidade | Mitigação |
|---|---|---|
| npx não disponível em algum ambiente | Baixa | Instrução nas skills: "se Context7 não disponível, pular e registrar NÃO_APLICÁVEL" |
| Context7 retorna resultados desatualizados | Baixa | A skill é guia, não oráculo — LLM avalia o resultado |
| Skills ficam verbosas demais | Média | As adições são sub-etapas condicionais — só executadas quando framework externo presente |

---

## 8. RESOLUÇÕES DE PANES

*(Nenhuma pane registrada durante análise e criação da SPEC.)*

---

## 9. Estimativa de Esforço

| Task | Arquivos | Esforço |
|---|---|---|
| T1 — `.mcp.json` | 1 | 5 min |
| T2 — `pre-flight/SKILL.md` | 1 | 15 min |
| T3 — `constraint-loader/SKILL.md` | 1 | 15 min |
| T4 — `learned-lesson/SKILL.md` | 1 | 20 min |
| **Total** | **4 arquivos** | **~55 min** |

---

## 10. Encerramento

- **Aprovação necessária**: Gate 1 — revisar e confirmar escopo antes de implementar
- **Próximo passo após aprovação**: task list + handoff para MiniMax
- **SPEC seguinte**: SPEC-0077 (Grafo de Dependências das Skills)
