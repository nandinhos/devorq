# Adapters de Delegação — Modo AUTO do DEVORQ

> Como o modo AUTO delega a implementação de cada story a um LLM real, e como
> acionar cada runner. Invocações **validadas end-to-end** (2026-07-02) contra o
> `--help` real de cada CLI — todos os 5 implementaram uma story de verdade.

---

## 1. Como funciona (o contrato)

No modo AUTO, o loop (`skills/devorq-auto/scripts/loop-auto.sh`) processa uma story
por iteração: **seleciona → delega a implementação a um LLM → verifica → commita →
marca `done`**. A ponte com o LLM é a variável de ambiente **`DEVORQ_DELEGATE_FN`**:

```
"$DEVORQ_DELEGATE_FN"  "$story_json"  "$project_root"
                          ↑ $1            ↑ $2
```

- `$1` = JSON da story (`.id`, `.title`, `.description`, `.acceptanceCriteria`)
- `$2` = caminho absoluto do projeto
- Retorna **0** em sucesso, **≠0** em falha.

O `delegate.sh` é um **dispatcher único** que implementa esse contrato e chama o CLI
escolhido em `DEVORQ_RUNNER`. Não há acoplamento a um harness específico.

---

## 2. Os runners e como acioná-los

Cada runner roda **não-interativo**, com **auto-aprovação de edição de arquivos**, no
**diretório do projeto**. Flags confirmadas no `--help` real:

| Runner | Binário | Não-interativo | Auto-edição de arquivos | Working dir | Flag de modelo | Modelo testado | Tempo |
|--------|---------|----------------|-------------------------|-------------|----------------|----------------|-------|
| **claude** | `claude` | `-p` / `--print` | `--dangerously-skip-permissions` | `cwd` (+`--add-dir`) | `--model` | default (Sonnet) | ~16s |
| **codex** | `codex` | `codex exec` | `-s workspace-write` (approval `never`) | `-C/--cd DIR` | `-m/--model` | gpt-5.5 | ~52s |
| **hermes** | `hermes` | `-z` / `--oneshot` | `--yolo` (+ `-z` já bypassa approvals) | `cwd` | `-m` | MiniMax-M3 | ~13s |
| **opencode** | `opencode` | `opencode run` | `--auto` | `--dir DIR` | `--model` | minimax/MiniMax-M3 | ~25s |
| **agy** (Antigravity) | `agy` | `-p` / `--print` | `--dangerously-skip-permissions` | `cwd` (+`--add-dir`) | `--model` | default | ~11s |

**Linha de comando exata (o que o `delegate.sh` monta):**

```bash
# claude
claude -p "$PROMPT" --dangerously-skip-permissions --add-dir "$DIR" [--model X]

# agy (Antigravity)
agy    -p "$PROMPT" --dangerously-skip-permissions --add-dir "$DIR" [--model X]

# codex
codex exec --cd "$DIR" -s workspace-write --skip-git-repo-check [--model X] "$PROMPT"

# hermes
hermes -z "$PROMPT" --yolo [-m X]

# opencode
opencode run --model "${MODEL:-minimax/MiniMax-M3}" --variant max --agent build \
             --dir "$DIR" --title "devorq story <id>" --auto "$PROMPT"
```

> ⚠️ **`--dangerously-skip-permissions` é real só para claude e agy.** No opencode a
> flag de auto-aprovação é **`--auto`** (a outra é silenciosamente ignorada). Cada CLI
> tem a sua — o dispatcher usa a certa por runner.

---

## 3. Manual do `delegate.sh`

Arquivo: `scripts/adapters/delegate.sh` (dispatcher). Wrappers finos por runner:
`claude-delegate.sh`, `codex-delegate.sh`, `hermes-delegate.sh`, `agy-delegate.sh`,
`opencode-delegate.sh` — cada um só fixa `DEVORQ_RUNNER` e chama o dispatcher.

### Variáveis de ambiente

| Variável | Obrigatória? | Default | O que faz |
|----------|:------------:|---------|-----------|
| `DEVORQ_RUNNER` | **sim** (se usar `delegate.sh` direto) | — | `claude` \| `codex` \| `hermes` \| `opencode` \| `agy` |
| `DEVORQ_MODEL` | não | default do CLI (opencode: `minimax/MiniMax-M3`) | força um modelo específico |
| `DEVORQ_DELEGATE_TIMEOUT` | não | `1800` (30 min) | segundos até matar o runner |
| `DEVORQ_DELEGATE_DRY_RUN` | não | `0` | `1` = imprime o plano e retorna 0 **sem** invocar o LLM |

### Duas formas de acionar

```bash
# (A) Dispatcher genérico — escolhe o runner por env var:
export DEVORQ_DELEGATE_FN="$DEVORQ_ROOT/scripts/adapters/delegate.sh"
export DEVORQ_RUNNER=claude

# (B) Wrapper fino — DEVORQ_RUNNER já embutido:
export DEVORQ_DELEGATE_FN="$DEVORQ_ROOT/scripts/adapters/codex-delegate.sh"
```

### O que o adapter faz internamente

1. Valida o contrato (`story_json`, `project_root`, `jq` presente).
2. Extrai `id`/`title`/`description`/`acceptanceCriteria` da story.
3. Monta um **prompt focado** (estilo Ralph: contexto limpo, mudança mínima, não
   commitar, não mexer no `prd.json`, responder em pt-BR).
4. Grava um **journal por story** em `<projeto>/.devorq-auto/runs/<runner>-<id>-<pid>.log`
   (invocação, stdout do LLM, `rc`).
5. Invoca o CLI com `timeout`. `rc=124` → timeout; `rc≠0` → falha da story.

### Garantias do loop em volta do adapter (não do adapter)

- **no-diff guard**: se o delegate não produzir mudança real no projeto (comparação de
  assinatura git antes/depois, excluindo `.devorq*`), a story **não** é marcada `done`.
- **stop-criteria**: após `DEVORQ_AUTO_MAX_STORY_FAILURES` (default 2) tentativas, a
  story vira `failed` e sai da seleção — sem loop infinito.
- **commit por story**: com `DEVORQ_AUTO_COMMIT=1`, commita `feat(escopo): título (id)`
  (scan de segredos antes do `git add -A`).
- **headless-safe**: sem TTY os prompts assumem default seguro (`DEVORQ_AUTO_YES=1`).

> ⚠️ **Limite atual honesto:** o gate `check-story.sh` roda a suite de testes do
> projeto, mas **não valida os `acceptanceCriteria`** da story. Quem garante que houve
> trabalho real é o **no-diff guard**. Validação por AC executável está no roadmap.

---

## 4. Casos de uso

### 4.1 — Dev experiente: spec pronta, rodar overnight
Você já tem `SPEC.md` e/ou `prd.json`. Deixa o AUTO implementar em lote.

```bash
export DEVORQ_DELEGATE_FN="$DEVORQ_ROOT/scripts/adapters/codex-delegate.sh"
export DEVORQ_AUTO_COMMIT=1              # commita cada story
export DEVORQ_DELEGATE_TIMEOUT=1200      # 20 min por story
cd /meu/projeto
devorq auto --all                        # ou: bash loop-auto.sh "$PWD" --all
```

### 4.2 — Testar a mecânica sem gastar tokens (dry-run)
Valida contrato, dispatch e prompt **sem** chamar o LLM.

```bash
export DEVORQ_DELEGATE_FN="$DEVORQ_ROOT/scripts/adapters/delegate.sh"
export DEVORQ_RUNNER=hermes
export DEVORQ_DELEGATE_DRY_RUN=1
devorq auto                              # imprime o plano, retorna 0
```

### 4.3 — Forçar um modelo específico
```bash
export DEVORQ_DELEGATE_FN="$DEVORQ_ROOT/scripts/adapters/delegate.sh"
export DEVORQ_RUNNER=claude
export DEVORQ_MODEL=opus                 # claude: opus|sonnet|fable
# codex: -m gpt-5.5 · hermes/opencode: id do provider (ex: minimax/MiniMax-M3)
```

### 4.4 — CI / cron (100% headless)
```bash
export DEVORQ_DELEGATE_FN="$DEVORQ_ROOT/scripts/adapters/opencode-delegate.sh"
export DEVORQ_AUTO_YES=1                 # nenhum prompt interativo
export DEVORQ_AUTO_ALLOW_NO_RUNNER=1     # não bloqueia se o projeto não tem test runner
export DEVORQ_AUTO_COMMIT=1
bash loop-auto.sh "$PWD" --all </dev/null
```

### 4.5 — Rodar uma story só (debug de um adapter)
```bash
export DEVORQ_RUNNER=agy DEVORQ_DELEGATE_FN=".../delegate.sh"
bash loop-auto.sh "$PWD" 1               # 1 iteração
tail -f "$PWD/.devorq-auto/runs/"*.log   # acompanhar o journal
```

### 4.6 — Runner não suportado / orquestrador próprio
Envolva a chamada do seu agente numa função que respeite o contrato:

```bash
my_delegate() {           # $1=story_json  $2=project_root
    local title; title=$(jq -r '.title' <<<"$1")
    ( cd "$2" && meu-agente-cli --headless --yes "Implemente: $title" )
}
export DEVORQ_DELEGATE_FN=my_delegate
```

---

## 5. Troubleshooting

| Sintoma | Causa provável | Ação |
|---------|----------------|------|
| `'<runner>' nao encontrado no PATH` | binário não instalado | instale o CLI ou corrija o PATH |
| story fica `pending`/`failed`, journal com `rc=0` | delegate **não** editou nada (no-diff) | veja o journal; o LLM pode ter só "respondido" sem usar tools |
| `rc=124` | timeout | aumente `DEVORQ_DELEGATE_TIMEOUT` |
| loop trava esperando input | rodou sem TTY e sem `DEVORQ_AUTO_YES=1` | exporte `DEVORQ_AUTO_YES=1` |
| commit rejeitado pelo hook | formato ≠ `tipo(escopo):` | o AUTO usa `feat(escopo)`; veja `rules/commit-convention.md` |
| auth ausente | CLI não logado | `claude`: OAuth · `codex`: `~/.codex/auth.json` · `hermes`/`opencode`: API key |

---

*Adapters validados end-to-end com LLM real em 2026-07-02 (claude, codex, hermes,
opencode/MiniMax-M3, agy). Detalhes do teste: `docs/REFACTOR-ELITE-PLAN.md`.*
