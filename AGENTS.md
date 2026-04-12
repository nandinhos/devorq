# AGENTES DEVORQ

Este documento define os papéis (Tiers) e as responsabilidades dos agentes LLM que operam neste repositório. O DEVORQ é um framework **LLM-agnóstico**: qualquer modelo pode assumir qualquer papel, desde que adira rigorosamente aos contratos e workflows definidos.

## Tiers de Operação (Referencial)

| Tier | Papel | Responsabilidades | Modelos de Referência (Sugestão) |
|------|-------|-------------------|----------------------------------|
| **1** | Arquiteto | Define specs, ADRs, contratos de escopo e decompõe tarefas. **Não implementa código.** | Claude Opus, Sonnet, Gemini 3.1 Pro |
| **2** | Implementador | Consome handoffs, executa TDD, e implementa soluções baseadas no contrato. | Claude Sonnet, MiniMax, GPT-4o, Gemini Flash |
| **3** | Revisor | Realiza auditoria de integridade e code review contra os contratos originais. | Claude Code, Gemini CLI, Codeium |

## Skills Obrigatórias por Agente

- **Todos:** `/env-context`, `/learned-lesson`, `/session-audit`.
- **Arquiteto (Tier 1):** `/spec`, `/break`, `/scope-guard`.
- **Implementador (Tier 2):** `/pre-flight`, `/quality-gate`, `TDD`.

## Natureza Agnóstica e Governança (v2.1)
O sucesso da orquestração reside na **adesão aos contratos**, não no modelo específico. 
1. Nenhuma implementação é iniciada sem uma SPEC aprovada em `docs/specs/` (Gate 1).
2. Se o contrato estiver ambíguo, o Implementador deve parar e pedir clarificação ao Arquiteto.
3. O "Handoff Adaptativo" garante que o contexto seja transferido de forma estruturada entre diferentes LLMs.

## Superpowers Spec Path Override
O Superpowers Framework salva specs em `docs/superpowers/specs/` por padrão, mas **preferências do projeto sobrescrevem este padrão**. Este projeto usa `docs/specs/` como localização canônica de specs (conforme definido acima em Gate 1).
