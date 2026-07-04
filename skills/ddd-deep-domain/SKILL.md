---
name: ddd-deep-domain
description: >
  DEVORQ-DDD v1.0.0 — Skill de exploração de domínio para devorq_v3.
  Guia descoberta do modelo mental ANTES de escrever SPEC.md.
  Gera domain-model.json com entidades, contextos delimitados e invariantes.
  Use quando: novo projeto, feature complexa, ou intent contém
  "domínio", "DDD", "modelagem", "entidades", "contexto delimitado".
version: 1.0.0
author: Fernando Dos Santos (Nando)
license: MIT
metadata:
  hermes:
    tags: [devorq, ddd, domain-driven, exploration, modelagem, context]
    related_skills: [devorq, devorq-mode, systematic-debugging]
    devorq:
      gate: 0
      type: exploration
      mode: [auto, classic]
  stack: [bash, jq]
---

# DEVORQ-DDD v1.0.0

## Visão Geral

**Princípio:** "O sistema vai ser robusto porque o modelo mental está correto, não porque as pastas estão no lugar certo."

**Problema resolvido:** A maioria começa a modelar olhando para frameworks e estruturas de pasta. O devorq_v3 inverte isso — primeiro entenda o domínio com quem conhece a regra, depois a arquitetura vira consequência natural.

## Quando Usar

**Trigger (keywords no intent):**
- `domínio`, `DDD`, `modelagem`, `entidade`, `entidades`
- `contexto delimitado`, `bounded context`, `contexto`
- `invariante`, `regras do negócio`, `domain model`

**Situações:**
- Novo projeto ou feature nova
- Sistema que está crescendo sem modelo claro
- Quando a pergunta "me explica o sistema" não tem resposta fácil
- Após perceber que "as pastas estão certas mas ninguém sabe explicar o código"

**Gate:** GATE-0 (pré-GATE-1, opt-in via keywords)

## Arquitetura

```
[NOVA FEATURE/PROJETO]
         │
         ▼
   ┌─────────────────┐
   │ ddd-deep-domain  │  ← GATE-0 (pré-GATE-1)
   │                  │    Carrega via keywords no intent
   │  6 Etapas        │
   │  1. Regra        │
   │  2. Entidades    │
   │  3. Contextos    │
   │  4. Língua       │
   │  5. Alertas      │
   │  6. Validação    │
   └────────┬────────┘
            │
            ▼
   domain-model.json
   context.json (domain_model)
            │
            ▼
   SPEC.md com alma
            │
            ▼
   GATE-1 (Spec Exists) ← PASS
```

## Fluxo Completo

```
USER: "vamos implementar o domínio de pedidos"
         │
[1] DETECT keywords  → domínio, pedidos
[2] LOAD skill        → ddd-deep-domain
[3] WORKSHOP          → 6 etapas com user/expert
[4] GENERATE          → domain-model.json
[5] UPDATE            → context.json (domain_model)
[6] VALIDATE SPEC     → ddd-validate-spec.sh
[7] PROCEED           → GATE-1 +
```

---

## Etapas Detalhadas

### ETAPA 1: Sentar com Quem Conhece a Regra

**Objetivo:** Identificar o especialista do domínio e fazer as perguntas certas.

**Ação:** Carregar `references/domain-questions.md` e usar como guia de workshop.

**Perguntas-chave:**

| Pergunta | O que Revela |
|----------|-------------|
| "Me dá um exemplo real de [entidade] — passo a passo?" | Comportamento real, não teórico |
| "Quando isso dá errado? Qual o pior cenário?" | Invariantes e edge cases |
| "Tem algo que parece igual mas é diferente dependendo do contexto?" | Contextos delimitados |
| "Que palavra você usa pra isso?" | Linguagem ubíqua |
| "O que não pode mudar nunca nessa entidade?" | Invariantes hard |

**Output:** Notas do workshop (pode ser em `NOTES.md` ou direto no `domain-model.json`)

---

### ETAPA 2: Mapear Entidades Reais

**Objetivo:** Identificar o que no negócio tem identidade própria e persiste.

**Conceitos:**

- **Entidade**: algo com identidade única que persiste no tempo
  - Ex: `Pedido`, `Cliente`, `Produto`
  - Tem ID próprio, pode ser buscada por esse ID

- **Value Object**: algo que só importa pelos atributos, não por identidade
  - Ex: `Endereco`, `CPF`, `Dinheiro`
  - Imutável, validado como um todo

- **Agregado**: grupo de entidades governadas por uma raiz (Aggregate Root)
  - Ex: `Pedido` + `ItemPedido` → raiz é `Pedido`
  - Tudo que muda passa pela raiz

**Regra:** Se não consegue explicar a diferença entre duas "entidades" aparentes, provavelmente é um único conceito com dois nomes em contextos diferentes.

---

### ETAPA 3: Descobrir Contextos Delimitados (Bounded Contexts)

**Objetivo:** Identificar onde um conceito muda de significado dependendo de quem olha.

**Exemplo clássico:**

```
Pedido-de-Vendas    ≠    Pedido-de-Logística
     ↓                      ↓
  O que foi comprado     Quando foi despachado
  Quem comprou           Qual transportadora
  Status do pagamento    Rastreio gerado
```

**Sinais de contextos diferentes:**
- O mesmo termo ("Pedido") significa coisas diferentes
- Times diferentes mexem em partes diferentes do sistema
- Regras que valem em um contexto não se aplicam em outro
- É necessário "traduzir" entre contextos (anti-corruption layer)

**Output:** Lista de contextos delimitados com:
- Nome do contexto
- Entidades que pertencem a ele
- Regras que só valem ali
- Forma de tradução para outros contextos

---

### ETAPA 4: Codificar a Língua, Não o Esqueleto

**Objetivo:** Quando o modelo mental está consolidado, a estrutura de pastas é uma decisão trivial.

**Princípio:** Não comece pela pasta. Comece pela língua. Se a língua está certa, qualquer estrutura funciona.

**Exemplo — três estruturas para o mesmo modelo:**

```bash
# Opção A — MVC do Laravel (sem medo)
app/Http/Controllers/PedidoController.php
app/Models/Pedido.php
app/Services/PedidoService.php

# Opção B — Camadas (Clean Architecture)
src/Domain/Entities/Pedido.php
src/Domain/ValueObjects/Endereco.php
src/Application/UseCases/CriarPedido.php
src/Infrastructure/Repositories/PedidoRepository.php

# Opção C — Qualquer outra estrutura
```

**Todas estão certas se o modelo mental estiver certo.**

**Regra:** Se você não consegue explicar o domínio sem mencionar código, o modelo ainda não está pronto.

---

### ETAPA 5: Os Sinais de Alerta (DDD de Teatro)

**Objetivo:** Identificar quando a estrutura parece certa mas o entendimento está ausente.

| Sinal | O que indica |
|-------|-------------|
| "Criei um Repository pra tudo" | Sem análise real de agregados — pattern por pattern, não por necessidade |
| "Tenho ValueObjects que só encapsulam um `string`" | Value Objects sem comportamento — decorador sem razão |
| "Minhas pastas seguem DDD mas não sei explicar o domínio" | Teatro de DDD — esqueleto sem alma |
| "O expert do domínio não reconheceria esse código" | Modelo desconectado da realidade |
| "Cada vez que o negócio muda, preciso refazer tudo" | Domínio não está separado do aplicação |
| "Tenho 47 entidades e nenhuma regra de negócio" | Modelo anêmico — dados sem comportamento |

---

### ETAPA 6: Validar o Modelo

**Objetivo:** Garantir que o SPEC.md tem alma, não só esqueleto.

**Perguntas para validar:**

1. **O expert do domínio entenderia o SPEC.md?** (ou precisaria de tradução?)
2. **Você consegue explicar o sistema inteiro sem mencionar código?**
3. **As entidades refletem como o negócio realmente funciona?**
4. **As invariantes estão explicitadas?**
5. **Os contextos delimitados estão identificados?**

**Ferramenta:** `scripts/ddd-validate-spec.sh`

```bash
# Se SPEC.md existe:
skills/ddd-deep-domain/scripts/ddd-validate-spec.sh "$PROJECT_ROOT/SPEC.md"

# Exit 0 = SPEC.md tem alma
# Exit 1 = SPEC.md é só esqueleto
# Exit 2 = SPEC.md não existe
```

---

## Output: domain-model.json

```json
{
  "project": "nome-do-projeto",
  "generated_at": "2026-04-23T14:00:00Z",
  "entities": [
    {
      "name": "Pedido",
      "type": "entity",
      "description": "Requisição feita por um cliente",
      "invariants": [
        "Pedido sem itens não existe",
        "Status só avança: novo → pago → enviado → entregue"
      ],
      "contexts": ["vendas", "logistica"]
    }
  ],
  "bounded_contexts": [
    {
      "name": "Vendas",
      "entities": ["Pedido", "Cliente", "Pagamento"],
      "language": "termos de vendas",
      "rules": ["Cliente precisa estar ativo para comprar"]
    },
    {
      "name": "Logística",
      "entities": ["Pedido", "Estoque", "Transportadora"],
      "language": "termos de logística",
      "rules": ["Pedido só pode ser enviado se pago"]
    }
  ],
  "invariants": [
    "Estoque nunca pode ser negativo",
    "Pedido cancelado volta ao estoque"
  ],
  "validated_with": "nome-do-expert",
  "confidence": "high|medium|low"
}
```

---

## Comandos

```bash
devorq ddd explore     # Abre workshop interativo (6 etapas)
devorq ddd validate    # Roda GATE-0 (ddd-validate-spec.sh)
devorq ddd context    # Adiciona domain_model ao context.json
devorq ddd init       # Gera domain-model.json do zero
```

---

## Integração devorq_v3

### GATE-0 em lib/gates.sh

```bash
gate_0_ddd() {
  # Só executa se DDD keywords detectadas no intent
  INTENT=$(cat "$STATE_DIR/context.json" | jq -r '.intent // ""')
  if ! echo "$INTENT" | grep -qiE "domínio|ddd|modelagem|entidade|contexto|bounded|invariante"; then
    return 0  # Skip — não é DDD
  fi

  # Valida SPEC.md
  if skills/ddd-deep-domain/scripts/ddd-validate-spec.sh "$PROJECT_ROOT/SPEC.md"; then
    return 0  # Passou
  else
    echo "❌ GATE-0 FAILED: SPEC.md não tem modelo de domínio"
    echo "   Use: devorq ddd explore"
    return 1
  fi
}
```

### devorq-mode integration

```bash
# Se intent contém DDD keywords + modo AUTO:
# → Sugerir: "DDD detectado. Explorar domínio primeiro?"
# → Opções: [1] CONTINUAR MESMO | [2] EXPLORAR DOMÍNIO PRIMEIRO
```

---

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Domínio explorado, SPEC.md com alma |
| 1 | SPEC.md sem modelo mental válido |
| 2 | SPEC.md não existe |
| 3 | domain-model.json não pôde ser gerado |

---

## Dependências

```bash
bash 5+      # Execução principal
jq 1.7+      # Parsing de JSON
git          # Repo detection
```

---

**Versão:** 1.0.0
**Criado em:** 2026-04-23
**Padrão:** DEVORQ — GATE-0 (pré-gate para SPEC)
