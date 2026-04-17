---
id: SPEC-0081
title: Fix E2E — Resolução de DEVORQ_ROOT ignora sandbox de teste
domain: arquitetura
status: implemented
priority: high
owner: team-core
created_at: 2026-04-17
updated_at: 2026-04-17
source: manual
related_tasks: []
related_files:
  - bin/devorq
  - tests/e2e.bats
---

# Spec — Fix E2E: Resolução de DEVORQ_ROOT ignora sandbox de teste

**Data**: 2026-04-17
**Status**: draft
**Autor**: Claude Sonnet 4.6

---

## Objetivo

Corrigir 4 testes E2E em `tests/e2e.bats` que falham porque `bin/devorq` ignora
a variável de ambiente `DEVORQ_ROOT` ao detectar o diretório raiz, priorizando
sempre `$HOME/.devorq` quando esse diretório existe — o que torna impossível
isolar o binário em um sandbox temporário durante os testes.

---

## Diagnóstico — Causa Raiz

### Problema 1 — bin/devorq sobrescreve DEVORQ_ROOT se $HOME/.devorq existe

```bash
# bin/devorq, linhas 10-14 (comportamento atual — ERRADO)
if [ -d "$HOME/.devorq" ]; then
    DEVORQ_ROOT="$HOME/.devorq"   # ← ignora env var, usa HOME sempre
else
    DEVORQ_ROOT="$(dirname "$SCRIPT_DIR")"
fi
```

Como qualquer máquina com DEVORQ instalado tem `$HOME/.devorq`, os testes
nunca conseguem injetar um `DEVORQ_ROOT` alternativo via `export`.

### Problema 2 — DEVORQ_DIR é derivado com .devorq duplicado

```bash
# bin/devorq, linha 16
DEVORQ_DIR="$DEVORQ_ROOT/.devorq"
```

Quando `DEVORQ_ROOT = /home/nandodev/.devorq`, temos:
`DEVORQ_DIR = /home/nandodev/.devorq/.devorq` ← path duplo, diretório inexistente.

Evidência no output de debug do teste 3:
```
✓ Handoff gerado: /home/nandodev/.devorq/.devorq/state/handoffs/handoff_...
```

### Problema 3 — tests/e2e.bats não exporta DEVORQ_ROOT

```bash
# tests/e2e.bats, linha 20 (setup atual — INCOMPLETO)
DEVORQ_ROOT="$TEST_SANDBOX"   # ← atribuição local, não exportada
```

Mesmo se bin/devorq honrasse a env var, o valor não chegaria ao subprocesso.

---

## As 4 Falhas e Sintomas

| # | Teste | Linha | Falha |
|---|-------|-------|-------|
| 1 | `devorq init` cria estrutura básica | 36 | `[ -d ".devorq" ]` — init cria em `$HOME/.devorq` em vez do sandbox |
| 2 | `devorq flow` gera artefatos | 53 | `[ -d ".devorq/state/brainstorms" ]` — mesma causa do teste 1 |
| 3 | `devorq handoff generate` produz arquivo | 76 | handoff salvo em path duplo `.devorq/.devorq/state/handoffs/` |
| 4 | `devorq skills` lista skills do diretório | 92 | skills lidas de `$HOME/.devorq/skills/`, não do sandbox |

---

## Fora do Escopo

- Refatoração da lógica de detecção de stack
- Alteração nos outros 146 testes que já passam
- Mudança no comportamento de instalação global (`devorq install`)
- Migração de `$HOME/.devorq` para outro caminho
- Adição de novos testes além dos 4 existentes

---

## Mudanças Necessárias

### Arquivo 1: `bin/devorq` — linhas 10-16

**FAZER**: Honrar `$DEVORQ_ROOT` se já estiver exportado no ambiente.
Só inferir automaticamente se a env var estiver vazia.

```bash
# Correto
if [[ -z "${DEVORQ_ROOT:-}" ]]; then
    if [ -d "$HOME/.devorq" ]; then
        DEVORQ_ROOT="$HOME/.devorq"
    else
        DEVORQ_ROOT="$(dirname "$SCRIPT_DIR")"
    fi
fi

# DEVORQ_DIR = subdir .devorq/ dentro do projeto-alvo (CWD), não dentro de DEVORQ_ROOT
DEVORQ_DIR="$(pwd)/.devorq"
```

> **Nota**: `DEVORQ_ROOT` contém o framework (bin/, lib/, .devorq/skills/).
> `DEVORQ_DIR` é o diretório de estado do **projeto alvo** (CWD).
> Os dois são conceitos distintos e não devem ser derivados um do outro.

### Arquivo 2: `tests/e2e.bats` — função `setup()`

**FAZER**: Exportar `DEVORQ_ROOT` para que o subprocesso receba o valor correto.

```bash
setup() {
    DEVORQ_REAL_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    TEST_SANDBOX=$(mktemp -d /tmp/devorq-e2e-XXXXXX)

    mkdir -p "$TEST_SANDBOX/bin" "$TEST_SANDBOX/lib"
    cp "$DEVORQ_REAL_ROOT/bin/devorq" "$TEST_SANDBOX/bin/"
    cp -r "$DEVORQ_REAL_ROOT/lib/"* "$TEST_SANDBOX/lib/"
    chmod +x "$TEST_SANDBOX/bin/devorq"

    export DEVORQ_ROOT="$TEST_SANDBOX"   # ← EXPORTAR

    cd "$TEST_SANDBOX" || exit 1
}
```

---

## Regras de Negócio

1. `DEVORQ_ROOT` env var exportada deve sempre sobrepor a detecção automática.
2. `DEVORQ_DIR` (estado do projeto) é sempre relativo ao CWD, nunca a `DEVORQ_ROOT`.
3. Nenhum dos 146 testes existentes que passam pode regredir.
4. O comportamento em produção (sem `DEVORQ_ROOT` exportado) deve permanecer idêntico.

---

## DONE CRITERIA

- [ ] `bats tests/e2e.bats` retorna 0 falhas (150/150 passando)
- [ ] `bats tests/` completo sem regressão nos 146 testes atuais
- [ ] `devorq init` sem `DEVORQ_ROOT` exportado ainda usa `$HOME/.devorq` (comportamento de produção preservado)
- [ ] `bash -n bin/devorq` e `bash -n lib/*.sh` sem erros de sintaxe

---

## Estimativa de Esforço

- **Arquivos modificados**: 2 (`bin/devorq`, `tests/e2e.bats`)
- **Linhas alteradas**: ~10 linhas no total
- **Risco**: Baixo — mudança cirúrgica, sem impacto em lógica de negócio
