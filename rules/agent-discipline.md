# Disciplina do Agente — DEVORQ v4.0.0

**Objetivo:** Reduzir erros comuns de LLM em coding — assumptions silenciosas, over-engineering, diffs inflados, tarefas vagas.

**Inspirado em:** [Karpathy Guidelines](https://github.com/multica-ai/andrej-karpathy-skills) — adaptado ao fluxo DEVORQ.

**Tradeoff:** Cautela > velocidade. Tarefas triviais (typo, fix óbvio, <5min) → usar julgamento, pular formalismos.

---

## 1. Pensar Antes de Codar

**Não assumir. Não esconder confusão. Mostrar trade-offs.**

Antes de implementar:
- Explicitar assumptions. Se incerto → **perguntar**.
- Se houver 2+ interpretações → **apresentar**, não escolher em silêncio.
- Se existir abordagem mais simples → **dizer**. Push back quando fizer sentido.
- Se algo estiver unclear → **parar**, nomear o que confunde, perguntar.

**DEVORQ:** Use `devorq grill` para trade-offs complexos. Use `devorq scope --lite` antes de features novas.

---

## 2. Simplicidade Primeiro

**Mínimo código que resolve o problema. Nada especulativo.**

- Sem features além do pedido.
- Sem abstrações para código de uso único.
- Sem "flexibilidade" ou config extra não solicitada.
- Sem error handling para cenários impossíveis.
- Se escreveu 200 linhas e 50 bastam → reescrever.

**Teste:** Um senior diria "overcomplicated"? Se sim → simplificar.

**DEVORQ:** `scope-guard` (whitelist FAZER/NÃO FAZER) para features. Fixes triviais → isentos.

---

## 3. Mudanças Cirúrgicas

**Tocar só o necessário. Limpar só a própria bagunça.**

Ao editar código existente:
- Não "melhorar" código adjacente, comentários ou formatação.
- Não refatorar o que não está quebrado.
- Seguir estilo existente, mesmo que faria diferente.
- Dead code pré-existente → **mencionar**, não deletar (salvo se pedido).

Quando suas mudanças criam órfãos:
- Remover imports/variáveis/funções que **suas** mudanças tornaram unused.
- Não remover dead code pré-existente sem pedido explícito.

**Teste:** Cada linha alterada rastreia diretamente ao pedido do usuário.

**DEVORQ:** `manual-commit` exige aprovação humana antes de commit/push.

---

## 4. Execução Orientada a Metas

**Definir critérios de sucesso. Loop até verificar.**

Transformar tarefas em metas verificáveis:
- "Adicionar validação" → "Escrever testes para inputs inválidos, depois fazer passar"
- "Corrigir bug" → "Teste que reproduz → fix → teste verde"
- "Refatorar X" → "Testes passam antes e depois"

Para tarefas multi-step, plano breve:
```
1. [Passo] → verificar: [check]
2. [Passo] → verificar: [check]
```

**DEVORQ:** Preencher `success_criteria` em `.devorq/state/context.json`. Gates 1–7 + `devorq verify` fecham o loop.

---

## 5. Commit apenas quando 100% verificado e autorizado

**O hook `commit-msg` é o chão, não o teto. Passar no hook não autoriza commitar.**

Regra canônica do projeto (jun/2026): **NUNCA** executar `git commit` antes de:

1. **Trabalho 100% verificado** — código escrito, testes passando, lint limpo, e2e
   verde. "Quase pronto" ainda é "não pronto". Não commitar WIP, mesmo que pareça
   pequeno. Não commitar porque "o próximo passo é commitar de qualquer jeito".

2. **Autorização explícita do dono** — o usuário pediu o commit diretamente
   ("commit", "manda", "ship") OU confirmou uma proposta sua ("pode commitar
   com essa mensagem?" → sim). Staging + mostrar-diff + perguntar NÃO é autorização;
   é pedido de autorização. Não antecipar.

3. **Escopo mínimo e mensagem clara** — diff rastreia diretamente ao pedido;
   mensagem passa `^[a-z]+\([a-z]+\):`; sem `Co-Authored-By`; português do Brasil;
   ID da issue (`DQ-xxx`) no fim da descrição, nunca no escopo.

**Exceção:** Se o usuário orientar diferentemente em uma conversa específica
(ex.: "commita tudo no final sem perguntar"), essa orientação vale para aquela
conversa apenas e **deve ser repetida literalmente** na resposta do agente —
não inferida nem generalizada.

**Anti-padrões a evitar:**
- Stagear arquivos "para já ter pronto" e esperar o usuário dizer "pode".
- Commitar após o primeiro teste verde, sem rodar o suite completo.
- Commitar mudanças de várias stories não-relacionadas num único commit.
- Commitar com mensagem vaga ("wip", "fixes", "updates") porque "depois eu ajusto".

---

## Quando esta regra está funcionando

- Diffs menores e focados
- Menos rewrites por overcomplication
- Perguntas de clarificação **antes** da implementação, não depois dos erros
- Zero commits sem autorização explícita — diffs revisados antes de virar commit
- Histórico do git reflete unidades lógicas, não empurrões parciais do agente
