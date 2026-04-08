# Checklist de Conformidade DEVORQ v2.1

Este documento define o comportamento determinístico esperado para cada ponto de contato do framework.

## 1. Fluxo de Inicialização e Diagnóstico
- [ ] `/devorq-info`: Deve exibir a versão local (`VERSION`) e comparar com `origin/main`.
- [ ] `/devorq-skills`: Deve listar pelo menos `handoff`, `spec` e `break`.
- [ ] `/devorq-upgrade`: Deve ser interativo (perguntar antes de agir).

## 2. Ciclo de Desenvolvimento (Protocolo Obrigatório)
- [ ] `/brainstorming`: Deve oferecer alternativas de design ANTES de qualquer código.
- [ ] `/spec`: Deve realizar as 6 perguntas canônicas de escopo.
- [ ] `/break`: Deve gerar `implementation_plan.md` e `task.md`.
- [ ] `/tdd`: Deve exigir a criação de um teste unitário ANTES da implementação.

## 3. Qualidade e Segurança
- [ ] `/quality-gate`: Deve bloquear o fluxo se houver falha de lint ou testes.
- [ ] `/devorq-audit`: Deve gerar um relatório quantitativo e qualitativo.
- [ ] `/handoff`: Deve atualizar os arquivos em `.devorq/state/handoffs/`.

## 4. Critérios Técnicos de Interface
- [ ] Os comandos devem ser resilientes a erros de permissão de arquivo.
- [ ] O orquestrador não deve executar comandos destrutivos sem `SafeToAutoRun: false` (exceto em modo turbo).
- [ ] Todas as comunicações devem estar em Português do Brasil (pt-BR).

---
**Nota**: Em caso de falha em um destes pontos em determinada LLM, marque como EXCEÇÃO no relatório final.
