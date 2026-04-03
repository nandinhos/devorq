# Regras — Orquestração Multi-LLM

> Ver decisão formal em `docs/adr/ADR-001-llm-agnostic-architecture.md`

## Princípio Central

Arquitetura LLM-agnostic: o processo é o produto, não o modelo.
LLMs são executoras dentro de um pipeline bem definido.
O foco está em como o processo está estruturado e garantido.

---

## Papéis e Responsabilidades

### Tier 1 — Arquiteto
- Define specs (`/spec`), ADRs, contratos de escopo (`/scope-guard`)
- Decompõe trabalho em tasks (`/break`)
- Gera e aprova handoff packages antes de cada implementação
- Revisa retornos dos implementadores
- Faz code review final (`/code-review`)
- **NUNCA implementa código de produção diretamente**
- Modelos de referência: Claude Opus, Sonnet, Minimax, Mimo V2 Pro, GPT-5.x

### Tier 2 — Implementador
- Consome handoff packages sem perguntas adicionais
- Executa `/env-context` → `/pre-flight` → TDD → `/quality-gate`
- Faz commits com mensagens convencionais em pt-BR
- Devolve retorno padronizado ao Tier 1
- **Não toma decisões de arquitetura** — se precisar, para e escala para Tier 1
- Modelos: qualquer modelo com contexto bem estruturado

### Tier 3 — Revisor
- Analisa diffs de código gerados pelo Tier 2
- Valida conformidade com contratos do Tier 1
- Aprova ou gera lista objetiva de correções
- Modelos de referência: Claude Code, Codex

---

## Regras Operacionais

1. **Handoff completo antes de implementar**
   O Tier 2 não inicia trabalho sem handoff package aprovado ([Gate 4]).
   Handoff incompleto = implementação incorreta.

2. **Retorno padronizado obrigatório**
   O Tier 2 sempre retorna: SHA do commit + output de testes + lista de
   arquivos + desvios do plano.

3. **Fallback sem retrabalho**
   Troca de modelo Tier 2 = mesmo handoff package, sem reconfiguração.
   O contexto viaja no pacote, não no histórico do chat.

4. **Tier 1 não implementa**
   Se o arquiteto percebe que precisa escrever código diretamente, é sinal
   que o handoff está incompleto. Corrigir o handoff primeiro.

5. **Gate 4 obrigatório**
   O handoff package sempre passa por aprovação do usuário antes de ser
   enviado ao Tier 2. Nunca enviar rascunho como handoff final.

6. **Escalada explícita**
   Se o Tier 2 encontrar ambiguidade não coberta pelo handoff, PARA e
   escala para o Tier 1. Não infere, não improvisa.

7. **Lições pertencem ao processo**
   `/learned-lesson` é executado ao final de cada ciclo completo.
   As lições são incorporadas ao DEVORQ via pipeline de aprendizado,
   independente de qual LLM as gerou.

8. **Formato de commit obrigatório**
   Todos os commits DEVORQ seguem:
   - Tipo(em pt-BR): feat, fix, docs, refactor, test, chore
   - Especialização em parênteses (ex: skills, lib, docs)
   - Descrição detalhada no corpo, cada item em linha própria
   - Sem emojis, sem Co-Authorship
   - Exemplo: `feat(skills): adicionar /spec para projetos grandes`

---

## Geração do Handoff Package (Modelo Híbrido)

```bash
# 1. CLI gera estrutura com seções automáticas
./bin/devorq handoff generate

# 2. Arquiteto (Tier 1) preenche manualmente:
#    - Seção 2: contrato de escopo (decisões)
#    - Seção 3: task brief arquivo por arquivo (intenção)
#    - Seção 5: padrões relevantes para esta task
#    - Seção 7: formato de retorno esperado

# 3. Usuário revisa e aprova [Gate 4]
./bin/devorq handoff status

# 4. Pacote enviado ao Tier 2
```

Template completo: `docs/templates/handoff-package.md`

---

## Anti-Patterns

| Errado | Certo |
|--------|-------|
| Enviar chat log como handoff | Gerar handoff package estruturado |
| Tier 1 implementa "rapidinho" | Criar handoff para Tier 2 |
| Trocar LLM sem atualizar handoff | Mesmo pacote funciona para qualquer Tier 2 |
| Handoff com "ver arquivo X para detalhes" | Conteúdo relevante inline no pacote |
| Tier 2 toma decisão arquitetural | Para e escala para Tier 1 |
