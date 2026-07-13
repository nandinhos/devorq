# AUTO Mode — Documentação Oficial

**Versão:** 1.0.0 | **Atualizado:** 2026-05-15

---

## Visão Geral

O **AUTO Mode** é um loop automatizado story-by-story que:
1. Seleciona a story de maior prioridade
2. Delega para sub-agente implementar
3. Verifica a implementação
4. Registra evidência e só marca a story como concluída após verificação
5. Commita apenas quando `DEVORQ_AUTO_COMMIT=1`

O loop é fail-closed: worktree ou index já sujo bloqueiam a execução; ausência,
falha ou no-diff do delegate não conclui a story; e o processo retorna sucesso
somente com o estado terminal `COMPLETED`.

---

## Arquitetura

```
devorq auto N → bin/devorq::cmd_auto → skills/devorq-auto/scripts/loop-auto.sh → lib/auto.sh
```

### libs/auto.sh

Biblioteca de funções **core** compartilhadas:

| Função | Descrição |
|--------|-----------|
| `devorq::auto::next_story()` | Seleciona próxima story pendente |
| `devorq::auto::pending_count()` | Conta stories pendentes |
| `devorq::auto::completed_count()` | Conta stories completadas |
| `devorq::auto::mark_pass()` | Marca story como done |
| `devorq::auto::ensure_branch()` | Cria/muda para branch devorq-auto/* |
| `devorq::auto::git_commit()` | Commit com padrão devorq |

### loop-auto.sh

Script principal com funcionalidades **avançadas**:

| Função | Descrição |
|--------|-----------|
| `devorq_auto::delegate_with_retry()` | Delega para sub-agente com retry |
| `devorq_auto::lessons_capture()` | Captura lições aprendidas |
| `devorq_auto::failures_generate()` | Gera failures.md |
| `devorq_auto::detect_complexity()` | Detecta stories complexas |
| `devorq_auto::propose_break()` | Propõe quebra de story |

---

## Comandos

```bash
# Executar N stories
devorq auto 1

# Executar todas
devorq auto all

# Continuar de onde parou
devorq auto --force-continue

# Ver help
devorq auto --help
```

---

## Arquivos Gerados

| Arquivo | Descrição |
|---------|-----------|
| `.devorq-auto/lessons.json` | Lições aprendidas (machine-readable) |
| `.devorq-auto/failures.md` | Sumário de falhas (human-readable) |
| `.devorq-auto/runs/*.log` | Logs de cada execução |
| `.devorq-auto/pending/*.json` | Contexto de stories que falharam |
| `.devorq-auto/.last-branch` | Branch usado no último run |
| `.devorq-auto/attempts.json` | Contagem persistida de tentativas por story |
| `progress.txt` | Log de progresso append-only |

---

## prd.json Schema

O AUTO mode aceita prd.json com **schema híbrido**:

```json
{
  "stories": [
    {
      "id": "sec-001",
      "title": "Título da story",
      "priority": 10,
      "status": "pending",        // ou "done", "complete"
      "passes": false,            // ou true
      "acceptance_criteria": [],   // ou acceptanceCriteria
      "files_to_check": []
    }
  ]
}
```

**Predicados:**
- **Incompleta:** `passes != true AND status NOT IN (done, complete, failed, skipped)`
- **Completa:** `passes == true OR status IN (done, complete)`
- **Falha terminal:** `status=failed` e `passes=false`; não é contada como concluída.

---

## Variáveis de Ambiente

| Variável | Padrão | Descrição |
|----------|---------|-----------|
| `DEVORQ_DELEGATE_FN` | - | Função de delegação (opcional) |
| `CAPTURE_LESSONS` | `true` | Capturar lições aprendidas |
| `MAX_DELEGATE_RETRIES` | `1` | Número de retries |
| `DEVORQ_AUTO_MAX_STORY_FAILURES` | `3` | Máximo persistido de tentativas antes de marcar `failed` |
| `DEVORQ_AUTO_COMMIT` | `0` | Habilita commit atômico limitado aos arquivos da story |

## Estados terminais e exit codes

| Estado | Exit code | Significado |
|--------|-----------|-------------|
| `COMPLETED` | `0` | Todas as stories foram verificadas; não há falhas nem skips. |
| `FAILED` | `1` | Ao menos uma story falhou ou foi marcada `failed`/`skipped`. |
| `INCOMPLETE` | `2` | Há stories pendentes após o limite solicitado. |

`SIGINT` e `SIGTERM` interrompem o loop com código `130`; o estado persistido
permanece disponível para inspeção e retomada explícita.

---

## Fluxo Detalhado

```
1. devorq_auto::setup_dirs()     → Cria .devorq-auto/
2. devorq_auto::lessons_init()   → Inicializa lessons.json
3. devorq_auto::ensure_branch()   → Garante branch devorq-auto/*
4. devorq_auto::next_story()      → Seleciona story
5. devorq_auto::detect_complexity() → Detecta complexidade
6. devorq_auto::delegate_with_retry() → Delega ou simula
7. check-story.sh                  → Verifica implementação
8. devorq_auto::mark_pass()       → Marca como done
9. devorq_auto::git_commit()      → Commita
10. devorq_auto::lessons_capture() → Registra lição
11. devorq_auto::failures_generate() → Atualiza failures.md
```

---

## Relacionamento com CLASSIC Mode

| Aspecto | AUTO | CLASSIC |
|---------|------|---------|
| Delegação | Automática | Manual |
| Commit | Automático | Manual |
| Lições | Capturadas | Opcional |
| Verificação | check-story.sh | devorq build |
| Iteração | story-by-story | gate-by-gate |

---

## See Also

- [SPEC.md](SPEC.md) — Especificação completa
- [README.md](../README.md) — Guia de uso
- `lib/auto.sh` — Código fonte das funções core
- `skills/devorq-auto/scripts/loop-auto.sh` — Script principal
