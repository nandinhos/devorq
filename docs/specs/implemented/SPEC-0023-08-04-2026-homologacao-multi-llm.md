---
id: SPEC-0023-08-04-2026
title: Homologação Multi-LLM v2.1
domain: operacao
status: implemented
priority: medium
owner: team-core
created_at: 2026-04-08
updated_at: 2026-04-08
source: manual
related_tasks: []
related_files: []
---

# Homologação Multi-LLM v2.1

## Objetivo

Padronizar a presença, configuração e o comportamento determinístico dos Slash Commands do DEVORQ em quatro plataformas distintas (Claude Code, Gemini CLI, Copilot e Antigravity), garantindo uma experiência de desenvolvedor agnóstica e consistente.

## Matriz de Conformidade

- **Claude Code CLI**: Validação via `CLAUDE.md` e execução `./bin/devorq`.
- **Gemini CLI**: Validação via `.mcp.json` e comandos `boost`.
- **Github Copilot**: Validação via percepção de contexto e chat determinístico.
- **Antigravity Editor**: Validação via workflows nativos `.agents/`.

## Regras de Protocolo (Canonizadas)

1. **Fluxo Estruturado**: Ativação obrigatória de Brainstorm -> Spec -> Break.
2. **Determinismo**: Resposta uniforme para comandos de infraestrutura.
3. **Check de Versão**: Comparação obrigatória entre versão local e remota (`origin/main`).

## Entidades

- `LLM_Platform`: O ambiente de execução.
- `Handoff_Spec`: O contrato de transferência entre ambientes.
- `Checklist`: A régua de qualidade técnica.
