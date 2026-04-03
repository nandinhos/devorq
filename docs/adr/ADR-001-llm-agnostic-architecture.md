# ADR-001 — Arquitetura LLM-Agnostic

**Data**: 2026-04-02
**Status**: Aceito
**Autor**: Nando Dev (arquitetado com Claude Code Sonnet 4.6)

---

## Contexto

O DEVORQ foi concebido para orquestrar desenvolvimento assistido por LLM.
A versão inicial acoplava o processo a LLMs específicas via arquivos
`prompts/claude.md`, `prompts/gemini.md` etc., criando dependência de provider
e fragmentando o processo por modelo.

À medida que o ecossistema de LLMs evolui rapidamente, a vinculação a um
modelo específico torna o framework frágil: troca de provider = reescrita
de prompts, perda de contexto, inconsistência de processo.

---

## Decisão

Adotamos arquitetura LLM-agnostic: o processo, os contratos e as definições
arquiteturais são independentes do modelo utilizado. As LLMs atuam como
executoras dentro de um pipeline bem definido, permitindo fallback,
substituição e orquestração sem acoplamento a um provider específico.

> "A prioridade deixa de ser qual modelo usar e passa a ser como o processo
> está estruturado e garantido."

---

## Tiers de Execução

| Tier | Responsabilidade | Modelos de Referência | Critério de Seleção |
|------|-----------------|----------------------|---------------------|
| **1 — Arquitetura** | System design, specs, ADRs, contratos, code review final | Claude Opus, Sonnet, Minimax, Mimo V2 Pro, GPT-5.x | Raciocínio profundo, consistência conceitual |
| **2 — Implementação** | Código, testes, commits, documentação técnica | Qualquer modelo com handoff bem estruturado | Operacional — contexto já resolvido pelo Tier 1 |
| **3 — Code Review** | Validação técnica, segurança, qualidade semântica | Claude Code, Codex | Especialização em análise de código |

### Regra de Fallback

Se o modelo do tier desejado estiver indisponível, qualquer modelo do mesmo
tier com o mesmo handoff package produz resultado equivalente.
**O contexto não muda — muda apenas o executor.**

---

## Consequências

### Positivas
- Portabilidade total do processo entre providers
- Fallback sem perda de contexto
- Foco no processo, não na ferramenta
- Evolução independente de cada tier
- Redução de custo: tarefas operacionais usam modelos menores

### Negativas / Trade-offs
- O handoff package exige disciplina do arquiteto (Tier 1)
- Handoff incompleto = implementação incorreta
- Overhead inicial de estruturação maior que vibe coding
- O Tier 1 não pode improvisar — cada decisão precisa estar no contrato

---

## Alternativas Rejeitadas

**Prompt por LLM** (abordagem anterior): cada modelo tinha seu próprio
arquivo de ativação com o processo completo. Rejeitado por criar
fragmentação, duplicação e acoplamento a providers específicos.

**Modelo único fixo**: usar apenas Claude Code para tudo. Rejeitado por
custo, disponibilidade e pelo princípio de usar o modelo certo para cada
nível de complexidade.

**Automação total de dispatch**: orquestrador automático seleciona LLM por
tarefa. Rejeitado por complexidade prematura — o processo manual controlado
pelo usuário é mais confiável na fase atual.

---

## Implementação

Ver DOC-001 (fluxo multi-LLM), DOC-003 (template de handoff) e
`.devorq/rules/multi-llm.md` (regras operacionais).
