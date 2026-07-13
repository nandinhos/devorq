---
name: devorq-auto
description: DEVORQ-AUTO v1.2.0 — Modo autonomo story-by-story do DEVORQ. Implementacao automatica via delegate_task seguindo o padrao Ralph (loop com contexto limpo por iteracao). Gera prd.json do SPEC.md, executa uma story por vez, verifica, commita. NAO depende do Ralph instalado — usa delegate_task nativo.
version: 1.2.0
author: Fernando Dos Santos (Nando)
license: MIT
metadata:
  hermes:
    tags: [devorq, autonomous, auto-mode, ralph-pattern, story-driven]
    related_skills: [devorq, systematic-debugging, verification-before-completion]
    stack: [bash, jq, python3, delegate_task]
---

# DEVORQ-AUTO v1.1.0

## Visao Geral

Modo autonomo do DEVORQ. Segue o **padrao Ralph**: tarefa grande -> stories pequenas -> loop com contexto limpo -> uma story por iteracao -> delegate -> verify -> commit.

Cada iteracao spawne um sub-agente com **contexto limpo** (so a story atual), evitando context window overflow em features complexas.

## Quando Usar

- Feature grande demais para uma unica iteracao
- Multiplas tasks independentes que podem ser paralelizadas
- Quando o usuario pedir explicitamente "modo auto" ou "executar automaticamente"
- Corrida de code review com multiplos items a corrigir

**Trigger:** `devorq auto`, `modo auto`, `executar automaticamente`, `ralph mode`

## Arquitetura

```
+------------------------------------------------------------+
|                      DEVORQ                             |
|                                                              |
|    +------------+       +----------------------------+     |
|    | prd.json   |------>|    loop-auto.sh             |     |
|    | (stories)   |       |  1. Seleciona story        |     |
|    +------------+       |  2. delegate_task()          |     |
|                         |  3. check-story.sh           |     |
|    +------------+       |  4. git commit                |     |
|    |progress.txt|<------|  5. atualiza passes=true    |     |
|    |(append-only) |      |  6. repeat                  |     |
|    +------------+       +----------------------------+     |
|                                                              |
|    Skills: systematic-debugging (se falha)                   |
|             verification-before-completion (gate)            |
+------------------------------------------------------------+
```

## Fluxo Completo

```
USER: "modo auto"
       |
[1] DETECT project root (SPEC.md ou .git)
[2] CHECK prd.json existente?
    +-- NAO -> prd-from-spec.sh gera stories do SPEC.md
    +-- SIM -> mostra pendentes, pergunta se usa ou regera
[3] CONFIRMACAO:
    "⚡ Modo AUTO: story por story via delegate_task
     Quantas iterations? (1 / 3 / 5 / todas)"
[4] LOOP (n vezes):
    a. Seleciona story priority mais alta com passes=false
    b. delegate_task(goal=story, context=acceptanceCriteria+repo)
    c. check-story.sh (Pint + tests)
    d. PASSOU -> git commit + jq passes=true + append progress.txt
    e. FALHOU -> para e pergunta se quer continuar
[5] SUMMARY -> repo pronto pra PR
```

## Step-by-Step

### STEP 1: Detectar Projeto

Procura `SPEC.md` ou `.git` no diretorio atual. Se nao encontrar, aborta.

```bash
if [ -f "SPEC.md" ]; then
  PROJECT_ROOT=$(pwd)
elif git rev-parse --git-dir > /dev/null 2>&1; then
  PROJECT_ROOT=$(git rev-parse --show-toplevel)
else
  echo "ERROR: SPEC.md ou .git nao encontrado"
  exit 1
fi
```

### STEP 2: Gerar ou Usar prd.json

**Se prd.json nao existe:**
```bash
devorq-auto/scripts/prd-from-spec.sh "$PROJECT_ROOT"
```
-> Leia `SPEC.md`, quebra em stories atomicas, salva `prd.json`

**Se prd.json existe:**
-> Mostra quantas stories pendentes, pergunta se quer usar ou regerar

### STEP 3: Confirmacao com Usuario

```
📋 prd.json — 8 stories, 3 pendentes
  [1] "Adicionar validacao de CPF no model User"     [🔴 pending]
  [2] "Criar migration para coluna cpf"              [🔴 pending]
  [3] "Adicionar endpoint GET /users/{id}/cpf"       [🔴 pending]

⚡ Modo AUTO: delegate_task por story -> verify -> commit
Quantas iterations? (1 / 3 / 5 / todas)
```

### STEP 4: Loop de Execucao

Para cada iteracao:

```bash
# 4a. Seleciona proxima story
STORY=$(jq -r '.stories | sort_by(.priority) | .[] | select(.passes==false) | @json' prd.json | head -1)

# 4b. Delegate
delegate_task(
  goal=STORY.description,
  context="acceptanceCriteria: STORY.acceptanceCriteria
repo: $PROJECT_ROOT
commit msg: feat(STORY.id): STORY.title"
)

# 4c. Verificar (gate)
devorq-auto/scripts/check-story.sh "$PROJECT_ROOT"
if [ $? -ne 0 ]; then
  echo "❌ Verification failed — abortar?"
  exit 3
fi

# 4d. Commit
git -C "$PROJECT_ROOT" add -A
git -C "$PROJECT_ROOT" commit -m "feat(${STORY_ID}): ${STORY_TITLE}"

# 4e. Atualizar prd.json
jq "(.stories[] | select(.id==\"$STORY_ID\")) |= .passes=true" prd.json > prd.json.tmp
mv prd.json.tmp prd.json

# 4f. Append progress
echo "[$(date +%H:%M)] ✅ ${STORY_TITLE} — PASSED" >> progress.txt
```

### STEP 5: Completion

```
═══════════════════════════════════════
AUTO MODE COMPLETED
═══════════════════════════════════════
3 stories done, 0 pending, 0 failed, 0 skipped

📝 Commits:
  feat(model): adicionar validacao CPF em User
  feat(migration): adicionar coluna cpf users
  feat(api): GET /users/{id}/cpf endpoint

📊 progress: $PROJECT_ROOT/progress.txt
📋 status:  $PROJECT_ROOT/prd.json
⚠️  Lembre de: E2E antes do PR
═══════════════════════════════════════
```

O texto `AUTO MODE COMPLETED` e o exit code `0` só são emitidos quando todas as
stories foram verificadas. `AUTO MODE FAILED` retorna `1`; `AUTO MODE INCOMPLETE`
retorna `2`. Ausência de delegate, no-diff, worktree sujo ou falha de commit nunca
podem ser convertidos em conclusão da story.

## Formato prd.json

```json
{
  "project": "nome-do-projeto",
  "created": "2026-04-23T02:30:00Z",
  "stories": [
    {
      "id": "feat-001",
      "title": "Adicionar validacao de CPF",
      "description": "Adicionar rule de validacao de CPF no model User usando Laravel Validator",
      "acceptanceCriteria": [
        "CPF valido passa",
        "CPF invalido retorna erro 422",
        "Testes cobrem caso valido e invalido"
      ],
      "priority": 1,
      "passes": false
    }
  ]
}
```

## Formato progress.txt

```
# devorq-auto progress — nome-do-projeto
# Formato: [HH:MM] ✅|❌ Story Title — PASSED|FAILED

[14:23] ✅ feat-001: Adicionar validacao de CPF — PASSED
[14:31] ✅ feat-002: Criar migration para coluna cpf — PASSED
[14:40] ✅ feat-003: Adicionar endpoint GET /users/{id}/cpf — PASSED
```

## Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Todas iterations completadas com sucesso |
| 1 | Erro de deteccao (sem SPEC.md, sem .git) |
| 2 | Abortado pelo usuario |
| 3 | Verification failed — usuario escolheu abortar |
| 4 | Delegate failed — erro no sub-agente |
| 5 | prd.json nao encontrado e geracao falhou |

## Arquivos de Saida

| Arquivo | Descricao |
|---------|-----------|
| `prd.json` | Stories com status (passes: true/false) |
| `progress.txt` | Log append-only de cada iteracao |
| `.devorq-auto/` | Diretorio de trabalho (branch, estado) |

## Regras de Ouro

1. **Stories pequenas** — se uma story demora mais de 10 min, esta grande demais. Quebre-a antes.
2. **Verify sempre** — nunca commita sem check-story.sh passar.
3. **Contexto limpo** — sub-agente recebe SOMENTE: id, title, acceptanceCriteria, repo path. Nada de outras stories.
4. **Progress append-only** — nunca sobrescreva. Only append.
5. **Abort facil** — usuario pode Ctrl+C. O que foi verificado e commitado fica.

## Sinergia com DEVORQ

- **systematic-debugging**: se check-story.sh detecta falha, carregar skill automaticamente
- **verification-before-completion**: graftada dentro de check-story.sh como gate final
- **devorq (v3)**: devorq-auto e modo acelerado do DEVORQ — nao substitui. GATE-1 a GATE-7 continuam valendo para o fluxo geral.

## armadilhas Descobertas (após uso real em WSL/Docker)

### 1. delegate_task nao acessa /projects/ corretamente
Sub-agentes spawneados via `delegate_task` podem Nao conseguir acessar paths como `/home/nandodev/projects/` ou `/projects/` — Timeout ou exit -1.
**Sintoma:** sub-agente da timeout (600s) mesmo com task simples.
**Solucao:** usar `execute_code` (Python) para implementacao direta quando delegate_task falha. O agente principal TEM acesso ao filesystem.
```python
# Padrao de fallback quando delegate_task falha
import subprocess
result = subprocess.run(['git', 'add', '-A'], capture_output=True, cwd=project_root)
```
**Regra:** se delegate_task falha 2x na mesma story, implementar diretamente via `execute_code`.

### 2. Fallback automatico execute_code (v1.1.0)
Se `delegate_task` falhar 1x, o loop agora faz retry automatico com `execute_code` em vez de parar imediatamente.
```bash
# MAX_DELEGATE_RETRIES=1 (default)
# Se falhar, tenta novamente com contexto simplificado
```
Se falhar 2x, cria `.devorq-auto/pending_story.json` com a story pendente.

### 3. force-continue para batch (v1.1.0)
Flag `--force-continue` pula stories com erro e continua o batch:
```bash
./loop-auto.sh . --all --force-continue
```
Falhas sao logadas em `lessons.json` mas nao param o loop.

### 4. Stories "by design" vs "SKIPPED"
- **By design** = codigo JA esta correto, comentarios indicam intencao deliberada. Marcar `passes: true`.
- **SKIPPED** = tecnicamente possivel mas requer analise manual profunda (ex: ARCH-01 Enums com dois conjuntos). Marcar `passes: false, notes: "SKIPPED: reason"`.
```python
# Exemplo: SEC-03 hierarquia — comentarios JA indicam design intencional
story['passes'] = True  # JA implementado corretamente

# Exemplo: ARCH-01 — dois conjuntos de Enums, analisar manualmente
story['passes'] = False
story['notes'] = 'SKIPPED: dois conjuntos de Enums (root app/*.php vs app/Enums/*.php)'
```

### 5. Complex stories = implementar diretamente
Stories como DB-01 (migration + update em todo PHP code), ARCH-02 (base class com logicas diferentes), ARCH-06 (Value Objects) saofaceis de entender mas tediosas de implementar. Faca diretamente via `execute_code` em vez de delegar:
```python
# Padrao para implementacao direta limpa
base = '/home/nandodev/projects/eventos-control'
# 1. Ler arquivos relevantes
# 2. Gerar codigo novo
# 3. write_file() ou patch()
# 4. git add + commit
```


## Licoes Aprendidas (v1.1.0+)

Arquivo: `.devorq-auto/lessons.json` — persiste entre sessoes por projeto.

```json
{
  "project": "nome-do-projeto",
  "created": "2026-04-23T02:30:00Z",
  "lessons": [
    {
      "story_id": "feat-001",
      "story_title": "Adicionar validacao de CPF",
      "type": "delegate",
      "details": "failed_after_1_retries",
      "timestamp": "2026-04-23T14:30:00Z"
    }
  ],
  "stats": {
    "total": 5,
    "delegate_failed": 1,
    "verification_failed": 0,
    "complex_detected": 2
  }
}
```

### O que e salvo automaticamente

| Type | Quando | Para que serve |
|------|--------|---------------|
| `delegate` | delegate_task falhou apos retries | Suggest implementacao direta na proxima |
| `verification` | check-story.sh falhou | Recordar que precisa de mais testes |
| `complex` | Heuristica detectou keywords complexas | Propor quebra de story antes de tentar |
| `success` | Story passou limpa | Confianca em patterns similares |

### Heuristicas de Complexidade

Stories sao marcadas como "complex" se conterem keywords como:
- `migration`, `enum`, `policy`, `relation`, `many-to-many`
- `factory`, `seeder`, `job`, `queue`, `event`, `listener`
- `middleware`, `service provider`, `config`, `schema`
- Descricao muito longa (>500 chars)

### Sugestoes Automaticas

Antes de cada story, o loop verifica se ha licao similar anterior e exibe:
```
📚 Licao anterior relevante:
  -> feat-001: delegate falhou com keywords migration
```



## Output Files (v1.2.0+)

Estrutura de logs criada em `.devorq-auto/` dentro do projeto:

```
projeto/
├── progress.txt                    # Log append-only de cada iteracao
└── .devorq-auto/
    ├── failures.md                 # SUMARIO das falhas (human-readable) ✨
    ├── lessons.json                # Falhas estruturadas (máquina)
    ├── runs/
    │   ├── 2026-04-27_14-30.log    # Log completo do batch
    │   └── 2026-04-27_15-45.log
    └── pending/
        ├── feat-002.json           # Contexto da story que falhou
        └── feat-005.json
```

### failures.md (human-readable)
```markdown
# DEVORQ-AUTO Failures — eventos-control
Generated: 2026-04-27 15:45

## 3 Stories Pendentes de Correção

### ❌ feat-002: Criar migration para coluna cpf
- **Tipo:** delegate (failed_after_1_retries)
- **Data:** 2026-04-27 14:31
- **Action:** delegate_task falhou apos retries
- **Contexto:** `.devorq-auto/pending/feat-002.json`
```

### lessons.json (machine-readable)
```json
{
  "project": "eventos-control",
  "lessons": [
    {"story_id": "feat-002", "type": "delegate", "details": "failed_after_1_retries", ...}
  ],
  "stats": { "delegate_failed": 1, "verification_failed": 1, "complex_detected": 1 }
}
```

### pending/*.json (contexto para debug)
```json
{
  "story_id": "feat-002",
  "title": "Criar migration para coluna cpf",
  "acceptanceCriteria": [...],
  "failure": { "type": "delegate", "details": "failed_after_1_retries", "timestamp": "..." }
}
```


## Limitacoes

- Nao substitui o DEVORQ manual — e acelerador para fases de implementacao pura
- Nao faz decisoes arquiteturais — story ambigua = PARA e pergunta
- Nao gera codigo de alta complexidade sozinho — stories complexas podem precisar de intervencao
- **delegate_task pode falhar em ambientes container/WSL** — ter fallback `execute_code` sempre disponivel
- **Stories que requerem analise de dois conjuntos de arquivos diferentes** (ex: Enums duplicados) = SKIPPED para analise manual
- Funciona melhor com PHP/Laravel (base DEVORQ) mas e agnostico de stack

## Dependencias

```bash
jq         # Ler/escrever prd.json
git        # branches, commits
python3    # prd-from-spec.sh (opcional, pode ser bash puro)
delegate_task  # Sub-agentes (nativo Hermes)
```

---

**Versao:** 1.0.0
**Criado em:** 2026-04-23
**Padrao:** DEVORQ (Ralph-inspired, contexto limpo por iteracao)
