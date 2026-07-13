# CONTRATO DE ESCOPO — Loop Engineering do DEVORQ

## IDENTIFICAÇÃO

- **Task:** implementar o plano aprovado em `docs/DEVORQ-LOOP-ENGINEERING-EXECUTION-PLAN.md`.
- **Tipo:** evolução arquitetural incremental.
- **Complexidade:** alta.
- **Base:** `main` em `54d602ad2b30470fc4f3ff9a3b5131dd08475568`.

## FAZER

1. Corrigir primeiro os falsos sucessos, guards de árvore/commit e gates fail-closed do modo AUTO.
2. Criar contratos versionados, validação e migração de PRD antes do novo loop experimental.
3. Implementar somente `devorq loop implementation --experimental` antes de qualquer perfil especializado.
4. Separar executor, verificador e juiz; registrar evidências, limites, recuperação e motivo de parada.
5. Adicionar testes comportamentais e documentação vinculados a cada gate de promoção.
6. Manter compatibilidade de `devorq auto`, `devorq flow` e `devorq review` durante a janela definida no plano.

## NÃO FAZER

1. Não reescrever o framework, introduzir serviços externos, banco, broker, plugin loader ou DAG genérico.
2. Não fazer push, release, bump de versão, reset destrutivo ou commit de alterações preexistentes.
3. Não publicar `migration`, `import-audit`, `release` ou `custom` sem os critérios específicos do WS-12.
4. Não tornar a declaração do executor uma prova de conclusão.
5. Não ampliar uma task além do respectivo `TaskPacket` e de seu mutation set exato.

## ARQUIVOS

- `docs/DEVORQ-LOOP-ENGINEERING-*.md`, `docs/architecture/`, `docs/adr/`, `docs/roadmap.md`, `docs/open-questions.md`
- `bin/devorq`, `lib/commands/`, `lib/dispatchers/`, `lib/*.sh`
- `skills/devorq-auto/`, `skills/devorq-code-review/`, `scripts/adapters/`, `scripts/ci-test.sh`
- `schemas/v1/`, `profiles/`, `tests/`, `e2e-tests/`, `.github/workflows/`
- `.devorq/state/` apenas para contexto, runs e evidências locais do programa.

## DONE_CRITERIA

- [ ] G-F0 a G-F6 aprovados com evidências reproduzíveis e sem falso sucesso terminal.
- [ ] Todo estado terminal, retry, cancelamento, lock, rollback e recovery tem teste de comportamento correspondente.
- [ ] A CLI experimental mantém paridade comprovada com AUTO e não reduz os controles existentes.
- [ ] Perfis especializados só são promovidos com verificador específico e proveniência.
- [ ] A documentação descreve o comportamento do código e a suíte relevante passa no hash final.
- [ ] Não há commit, push ou release sem autorização específica.

## RISCOS IDENTIFICADOS

- Alterações em loop, estado e Git podem contaminar a árvore do usuário ou produzir sucesso falso.
- A extensão prematura para perfis genéricos pode duplicar motores e quebrar compatibilidade.
- Evidências ou logs podem expor segredos se não forem redigidos e limitados.
