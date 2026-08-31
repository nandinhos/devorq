# AGENTS.md — DEVORQ (instruções agnósticas)

> Documento estável para qualquer LLM, IDE ou orquestrador (Telegram, Claude, Cursor, Copilot).
> **Fonte canônica:** `rules/` no repo DEVORQ. Adaptadores são gerados sob demanda.

## Regras essenciais

| Regra | Arquivo canônico |
|-------|------------------|
| Disciplina do agente | [`rules/agent-discipline.md`](rules/agent-discipline.md) |
| Convenção de commit | [`rules/commit-convention.md`](rules/commit-convention.md) |
| Commits manuais | [`rules/manual-commit.md`](rules/manual-commit.md) |

Após `devorq init`, cópias ficam em `.devorq/rules/`.

### Formato de commit — o hook `commit-msg` BLOQUEIA (inegociável)

O hook `.git/hooks/commit-msg` valida a 1ª linha com esta regex literal:

```
^[a-z]+\([a-z]+\):
```

Ou seja: **`tipo(escopo): descrição`** com `tipo` e `escopo` **somente minúsculas — sem espaço, sem dígitos, sem hífen** dentro deles.

- ✅ `fix(gates): corrige contagem honesta no self-build (DQ-028)`
- ✅ `feat(agents): contrato DEVORQ_DELEGATE_FN documentado`
- ❌ `fix (gates): ...` (espaço antes do parêntese)
- ❌ `fix(DQ-030): ...` (maiúsculas + dígitos + hífen no escopo)
- ❌ qualquer linha com `Co-Authored-By:` (bloqueada também)

> IDs como `(DQ-030)` vão no **fim da descrição**, nunca no escopo.
> Mensagens em **português do Brasil**. Esta é a fonte da verdade — o `CLAUDE.md`
> global (commit *com* espaço) NÃO se aplica aqui; o hook é quem manda.

## Fluxo recomendado

1. `devorq init` — bootstrap de regras + hook commit-msg
2. Preencher `.devorq/state/context.json` com `intent` e `success_criteria`
3. `devorq scope lite "<intent>"` — contrato mínimo antes de codar
4. Gates (sequência canônica `DEVORQ_GATE_SEQUENCE`: 0, 0.5, 1–7; inclui G-6 Context7) + `devorq verify`
5. `devorq commit` — **sem** `Co-Authored-By`

## Export para ferramentas

```bash
devorq rules export project   # .devorq/rules/
devorq rules export cursor    # .cursor/rules/ (local, gitignored)
devorq rules export claude    # CLAUDE.md
devorq rules export agents    # AGENTS.md no projeto alvo
```

No repo DEVORQ, este arquivo é mantido manualmente. Em projetos consumidores, `export agents` gera uma cópia adaptada.

## Contrato de delegação `DEVORQ_DELEGATE_FN` (modo AUTO)

A camada de **regras** (`rules/`) é agnóstica. A camada de **execução de sub-agentes**
(modo AUTO story-by-story) precisa de um primitivo para delegar a implementação de
uma story — historicamente `delegate_task` do Hermes. Para não acoplar o DEVORQ a um
orquestrador específico, o modo AUTO usa um **contrato de adapter**:

- **`DEVORQ_DELEGATE_FN`** — nome de uma função/comando que o loop AUTO invoca como
  `"$DEVORQ_DELEGATE_FN" "$story_json" "$project_root"`. Deve implementar a story e
  retornar `0` em sucesso. Se **não definido**, o loop é **fail-closed**: não marca a
  story como done (não há sub-agente para implementar) — use `DEVORQ_AUTO_SIMULATE=1`
  só para dry-run.

Adaptadores de referência (defina antes de `devorq auto`):

```bash
# Hermes (nativo)
export DEVORQ_DELEGATE_FN=delegate_task

# opencode CLI (nativo, ships-with-devorq) — DQ-022
export DEVORQ_DELEGATE_FN="$DEVORQ_ROOT/scripts/adapters/opencode-delegate.sh"
# env vars opcionais:
#   OPENCODE_MODEL   (default: minimax/MiniMax-M3)
#   OPENCODE_EFFORT  variant: max|high|medium|minimal (default: max)
#   OPENCODE_AGENT   (default: build)
#   OPENCODE_TIMEOUT segundos (default: 1800)
#   OPENCODE_DRY_RUN se 1, imprime o que faria e retorna 0 sem invocar

# Adapter GENERICO (recomendado) — 1 dispatcher p/ todos os runners:
export DEVORQ_DELEGATE_FN="$DEVORQ_ROOT/scripts/adapters/delegate.sh"
export DEVORQ_RUNNER=claude   # claude|codex|hermes|opencode|agy
#   DEVORQ_MODEL             forca um modelo (default: default do CLI)
#   DEVORQ_DELEGATE_TIMEOUT  segundos (default: 1800)
#   DEVORQ_DELEGATE_DRY_RUN  se 1, imprime o plano e retorna 0 sem invocar o LLM

# Ou um wrapper fino por runner (mesma logica, DEVORQ_RUNNER ja fixado):
export DEVORQ_DELEGATE_FN="$DEVORQ_ROOT/scripts/adapters/claude-delegate.sh"
#   ...codex-delegate.sh, hermes-delegate.sh, agy-delegate.sh, opencode-delegate.sh

# Invocacoes reais por runner (dentro de delegate.sh):
#   claude   claude -p PROMPT --dangerously-skip-permissions --add-dir DIR
#   agy      agy    -p PROMPT --dangerously-skip-permissions --add-dir DIR
#   codex    codex exec --cd DIR -s workspace-write --skip-git-repo-check PROMPT
#   hermes   hermes -z PROMPT --yolo
#   opencode opencode run --dir DIR --auto PROMPT

# Ou envolva manualmente o seu proprio orquestrador:
my_delegate() { # $1=story_json  $2=project_root
    # ... invocar o agente do seu ambiente para implementar a story ...
    : ; }
export DEVORQ_DELEGATE_FN=my_delegate
```

### Teste do adapter opencode

```bash
bash scripts/adapters/test-opencode-delegate.sh
# -> roda loop-auto.sh em /tmp com prd.json de 1 story, OPENCODE_DRY_RUN=1,
#    verifica: fail-closed (dry-run sem mudancas NAO marca done — C4), journal
#    criado, sem efeito colateral.
```

Flags relacionadas: `DEVORQ_AUTO_COMMIT=1` (commit por story), `DEVORQ_AUTO_ALLOW_NO_RUNNER=1`
(projeto sem runner de teste), `DEVORQ_AUTO_SIMULATE=1` (dry-run).

## Proibições

- Sem `Co-Authored-By` em commits (hook bloqueia)
- Sem refatoração fora do escopo pedido
- Sem features especulativas

Ver também: [`docs/ARQUITETURA-AGNOSTICA-LLM.md`](docs/ARQUITETURA-AGNOSTICA-LLM.md)
