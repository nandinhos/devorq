---
id: SPEC-2026-04-07-001
title: Suíte de Testes E2E DEVORQ
domain: arquitetura | operacao
status: draft
priority: high
owner: team-core
created_at: 2026-04-07
updated_at: 2026-04-07
source: manual
related_tasks: []
related_files: ["bin/devorq", "lib/orchestration/flow.sh", "tests/e2e.bats"]
---

# Spec — Suíte de Testes E2E DEVORQ

**Data**: 2026-04-07
**Status**: draft
**Autor**: Antigravity

## Objetivo

Implementar uma suíte de testes "End-to-End" (E2E) robusta para o orquestrador DEVORQ, garantindo que o fluxo completo de inicialização e orquestração de tarefas funcione conforme o esperado em diversos contextos de projeto.

## Fora do Escopo

- Testes de integração com LLMs reais (serão simulados/mocked para evitar custos e latência).
- Testes de UI (o projeto é puramente CLI).

## Cenários de Teste

| Cenário | Descrição | Comportamentos principais |
|--------|-----------|--------------------------|
| **Init** | Inicialização do Zero | Executar `devorq init` e validar criação de `.devorq/`, `rules/`, `state/`, e `session.json`. |
| **Flow (E2E)** | Orquestração Completa | Executar `devorq flow "test"`. Validar geração de brainstorm, contrato e spec com timestamps coerentes. |
| **Handoff** | Geração de Handoff | Validar que `handoff generate` produz um arquivo Markdown válido com o estado atual. |
| **Upgrade** | Atualização de Plugins | Simular o comando `upgrade` em uma pasta paralela e validar cópia de binários e libs. |

## Regras de Negócio

1. **Sandbox Isolation**: Nenhum teste deve modificar o diretório raiz do projeto real; todo teste deve ocorrer em diretórios `/tmp/` controlados pelo BATS.
2. **JQ Consistency**: Todas as saídas JSON geradas pelo `devorq` devem ser válidas e parseáveis via `jq`.
3. **Exit Codes**: Sucesso deve sempre retornar `0`. Falhas críticas (como falta do `jq`) devem retornar `1`.

## Estimativa de Artefatos

- `tests/e2e.bats` — Arquivo principal de testes.
- `tests/mocks/` — (Se necessário) scripts simuladores de ambiente.
