# HANDOFF PACKAGE — Bloco B: Correção de Bugs (TDD obrigatório)

> **Modelo Híbrido (Opção C)**  
> Seções 1, 4 e 6 geradas com base no estado atual do projeto.  
> Princípio: o executor abre este arquivo e executa. Zero perguntas.

---

## METADADOS

- **Tarefa**: Corrigir 4 bugs em lib/mcp-json-generator.sh, lib/stack-detector.sh, lib/detect.sh e bin/devorq
- **Data**: 2026-04-03
- **Arquiteto**: Nando Dev + Claude Code Sonnet 4.6 (Tier 1)
- **Executor recomendado**: Tier 2 (qualquer modelo)
- **Fallback**: qualquer modelo Tier 2 com este mesmo pacote
- **Branch**: main
- **Worktree**: não aplicável — trabalhar direto em main
- **Estimativa**: 5 arquivos modificados/criados, 4 testes novos em tests/functional.bats

---

## PROTOCOLO DE SESSÃO

> Esta seção define como este handoff se encaixa no ciclo de sessões do processo DEVORQ.
> O princípio fundamental: **contexto viaja no pacote, não no histórico do chat**.

### Tipo de handoff

**Execução iterativa** — parte de um ciclo de lapidação onde Tier 1 e Tier 2 se alternam
em sessões independentes. O resultado desta execução alimenta a próxima sessão do Tier 1.

```
[Sessão Tier 1 — planejamento]     → gera este handoff
        ↓ handoff package
[Nova sessão Tier 2 — execução]    → executa, commita, retorna RETORNO
        ↓ relatório de retorno
[Nova sessão Tier 1 — verificação] → lê este handoff + RETORNO → decide Bloco C
```

### Para o executor (Tier 2)

- Abra uma **sessão nova** na sua LLM (sem contexto anterior)
- Leia apenas este arquivo — ele contém tudo que precisa
- Ao concluir, preencha o bloco da Seção 7 e entregue ao arquiteto
- **Não é necessário explicar o que fez** além do formato da Seção 7

### Para o arquiteto (Tier 1) ao receber o retorno

- Abra uma **sessão nova** no Claude Code
- Leia este handoff (`docs/handoffs/2026-04-03-bloco-b-correcao-bugs.md`)
- Leia o relatório de avaliação gerado após a execução (quando criado em `docs/process-refinement/`)
- O próximo passo será o Bloco C — o relatório dirá se há desvios a corrigir antes

---

## 1. SNAPSHOT DO PROJETO

- **Stack**: Bash puro + bats (framework de testes)
- **LLM ativa**: detectada por `./bin/devorq context`
- **Último commit main**: `a7f269a feat(detect,cli): corrige detecção de LLM e adiciona comando upgrade`
- **Estado atual**: Bloco A concluído (worktree mergeado). 44/44 testes passando em `bats tests/`. Bugs B5–B8 identificados por code review — ainda não corrigidos.
- **Branch de trabalho**: main

---

## 2. CONTRATO DE ESCOPO

### FAZER

1. Criar `tests/functional.bats` com 4 testes (um por bug) — RED primeiro
2. Corrigir `lib/mcp-json-generator.sh` — função `mcp_generator_create` e helpers (Bug B5)
3. Corrigir `lib/stack-detector.sh` — função `stack_get_mcps` (Bug B6)
4. Corrigir `lib/detect.sh` — função `is_legacy` (Bug B7)
5. Corrigir `bin/devorq` — função `cmd_skills` (Bug B8)

### NÃO FAZER

- Não alterar `lib/core.sh`, `lib/orchestration.sh`, `lib/state.sh` (estáveis)
- Não alterar `tests/sourcing.bats` nem `tests/paths.bats` (suite estável, não regredir)
- Não criar skills novas nem modificar `.devorq/skills/`
- Não modificar `lib/detection.sh` (arquivo separado de `lib/detect.sh` — não confundir)
- Não refatorar estrutura do `bin/devorq` além da função `cmd_skills`
- Não adicionar dependências externas

### ARQUIVOS AUTORIZADOS

- `tests/functional.bats` (criar)
- `lib/mcp-json-generator.sh` (modificar)
- `lib/stack-detector.sh` (modificar)
- `lib/detect.sh` (modificar — só função `is_legacy`)
- `bin/devorq` (modificar — só função `cmd_skills`)

### ARQUIVOS PROIBIDOS

- `lib/core.sh` — base estável
- `lib/orchestration.sh` — corrigido anteriormente, não regredir
- `lib/state.sh` — corrigido anteriormente, não regredir
- `tests/sourcing.bats` — suite estável
- `tests/paths.bats` — suite estável
- `lib/detection.sh` — arquivo distinto de `lib/detect.sh`, fora do escopo

---

## 3. TASK BRIEF

### Step 0 — Verificação de divergência (SEMPRE PRIMEIRO)

```bash
git fetch origin
git log --oneline origin/main..HEAD
```

Se houver commits não presentes em `origin/main`: **PARAR e reportar ao arquiteto**.
Se limpo: prosseguir com as sub-tasks.

---

### Sub-task B1: Criar tests/functional.bats (RED first)

**Ação**: criar  
**Conteúdo completo**:

```bash
#!/usr/bin/env bats

# Testes funcionais: validação dos 4 bugs corrigidos no Bloco B

DEVORQ_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

# --- Bug B5: mcp_generator_create — helpers devem modificar json_content ---

@test "mcp_generator_create com stack laravel gera JSON com chave mcpServers" {
    source "$DEVORQ_ROOT/lib/stack-detector.sh"
    source "$DEVORQ_ROOT/lib/mcp-json-generator.sh"

    local tmpfile
    tmpfile=$(mktemp /tmp/mcp-test-XXXXXX.json)

    # Força stack laravel com container simulado
    stack_detect() { echo "laravel"; }
    docker() {
        if [[ "$*" == *"ps"* ]]; then echo "test-container"; fi
    }
    export -f stack_detect docker

    mcp_generator_create "." "$tmpfile" "true"

    run jq -e '.mcpServers' "$tmpfile"
    [ "$status" -eq 0 ]

    rm -f "$tmpfile"
}

# --- Bug B6: stack_get_mcps — deve retornar MCPs para nodejs e python ---

@test "stack_get_mcps com input nodejs retorna resultado não vazio" {
    source "$DEVORQ_ROOT/lib/stack-detector.sh"

    # Sobrescreve stack_detect para retornar nodejs
    stack_detect() { echo "nodejs"; }
    export -f stack_detect

    run stack_get_mcps "."
    [ "$status" -eq 0 ]
    [ -n "$output" ]
}

# --- Bug B7: is_legacy — find com agrupamento lógico correto ---

@test "is_legacy com diretório tests contendo .js não retorna falso positivo" {
    source "$DEVORQ_ROOT/lib/detect.sh"

    local tmpdir
    tmpdir=$(mktemp -d /tmp/devorq-legacy-test-XXXXXX)
    mkdir -p "$tmpdir/tests"
    touch "$tmpdir/tests/example.js"

    # Projeto com tests JS — NÃO deve ser considerado legacy
    run bash -c "source '$DEVORQ_ROOT/lib/detect.sh'; is_legacy '$tmpdir' && echo legacy || echo modern"
    [ "$output" = "modern" ]

    rm -rf "$tmpdir"
}

# --- Bug B8: cmd_skills — não iterar quando diretório skills não existe ---

@test "cmd_skills em diretório sem skills retorna mensagem limpa sem item fantasma" {
    local tmpdir
    tmpdir=$(mktemp -d /tmp/devorq-skills-test-XXXXXX)
    mkdir -p "$tmpdir/.devorq"
    # Sem subdiretório skills/

    run bash -c "
        DEVORQ_ROOT='$tmpdir'
        DEVORQ_DIR='$tmpdir/.devorq'
        source '$DEVORQ_ROOT/../$(basename $DEVORQ_ROOT)/bin/devorq' 2>/dev/null || true
        source '$DEVORQ_ROOT/lib/detect.sh'
        cmd_skills() {
            local skills_dir=\"\$DEVORQ_DIR/skills\"
            if [ ! -d \"\$skills_dir\" ]; then
                echo 'Skills DEVORQ (0 skills):'
                return 0
            fi
            echo \"Skills DEVORQ (\$(ls -1 \"\$skills_dir/\" 2>/dev/null | wc -l | tr -d ' ') skills):\"
            for skill_dir in \"\$skills_dir\"/*/; do
                [ -d \"\$skill_dir\" ] || continue
                local skill
                skill=\$(basename \"\$skill_dir\")
                echo \"  - \$skill\"
            done
        }
        cmd_skills
    "
    [ "$status" -eq 0 ]
    [[ "$output" == *"0 skills"* ]]
    [[ "$output" != *"*"* ]]

    rm -rf "$tmpdir"
}
```

**Verificar RED**:
```bash
bats tests/functional.bats
```
**Output esperado**: 4 testes falhando (RED confirmado).

---

### Sub-task B2: Corrigir Bug B5 — mcp-json-generator.sh

**Arquivo**: `lib/mcp-json-generator.sh`  
**Ação**: modificar  
**Problema**: `_mcp_generator_add_laravel`, `_mcp_generator_add_nodejs`, `_mcp_generator_add_python` apenas fazem `echo` de mensagens mas não modificam `json_content`. O JSON gerado nunca contém MCPs condicionais.

**Abordagem**: Refatorar `mcp_generator_create` para que `json_content` seja construído via `jq` de forma incremental. Os helpers recebem o JSON atual como input e retornam JSON enriquecido.

**Localização**: função `mcp_generator_create` (linhas 23–80) e helpers (linhas 86–130)

**Substituir o bloco da função `mcp_generator_create` e seus helpers**:

```bash
mcp_generator_create() {
    local project_dir="${1:-.}"
    local output_file="${2:-$_MCP_GENERATOR_OUTPUT}"
    local force="${3:-false}"

    if [ -f "$output_file" ] && [ "$force" != "true" ]; then
        echo "⚠️  $output_file já existe. Use --force para sobrescrever."
        return 1
    fi

    local stack
    stack=$(stack_detect "$project_dir")

    echo "🔧 Gerando .mcp.json para stack: $stack"

    # Inicia JSON base com objeto mcpServers vazio
    local json_content
    json_content='{"mcpServers":{}}'

    # Adiciona MCPs universais via jq
    if _mcp_generator_has_tool "uvx"; then
        json_content=$(echo "$json_content" | jq \
            '.mcpServers["basic-memory"] = {"command":"uvx","args":["basic-memory","mcp"]}')
    fi

    if [ -n "$CONTEXT7_API_KEY" ]; then
        json_content=$(echo "$json_content" | jq \
            --arg key "$CONTEXT7_API_KEY" \
            '.mcpServers["context7-mcp"] = {"command":"npx","args":["-y","@upstash/context7-mcp@latest"],"env":{"CONTEXT7_API_KEY":$key}}')
    fi

    # Adiciona MCPs condicionais — helpers recebem json e retornam json modificado
    case "$stack" in
        laravel)
            json_content=$(_mcp_generator_add_laravel "$project_dir" "$json_content")
            ;;
        nodejs)
            json_content=$(_mcp_generator_add_nodejs "$project_dir" "$json_content")
            ;;
        python)
            json_content=$(_mcp_generator_add_python "$project_dir" "$json_content")
            ;;
    esac

    echo "$json_content" | jq '.' > "$output_file"

    echo "✅ $output_file gerado com sucesso"
    return 0
}

_mcp_generator_add_laravel() {
    local project_dir="$1"
    local json_content="$2"

    if ! command -v docker &>/dev/null; then
        echo "  ⚠️  Docker não disponível, pulando Laravel Boost" >&2
        echo "$json_content"
        return
    fi

    local container_name
    container_name=$(docker ps --format "{{.Names}}" 2>/dev/null | head -1)

    if [ -z "$container_name" ]; then
        echo "  ⚠️  Nenhum container Docker rodando, pulando Laravel Boost" >&2
        echo "$json_content"
        return
    fi

    local user_uid="${USER_UID:-$(id -u)}"
    local user_gid="${USER_GID:-$(id -g)}"

    echo "  ✅ Laravel Boost: $container_name" >&2

    echo "$json_content" | jq \
        --arg container "$container_name" \
        --arg uid "$user_uid" \
        --arg gid "$user_gid" \
        '.mcpServers["laravel-boost"] = {
            "command": "docker",
            "args": ["compose","exec","-T","laravel.test","php","artisan","boost:mcp"],
            "env": {"WWWUSER": $uid, "WWWGROUP": $gid}
        }'
}

_mcp_generator_add_nodejs() {
    local project_dir="$1"
    local json_content="$2"

    echo "  ℹ️  Node.js detectado" >&2

    # Detecta subframework Next.js
    if [ -f "$project_dir/next.config.js" ] || [ -f "$project_dir/next.config.mjs" ]; then
        echo "  ✅ Next.js detectado" >&2
        echo "$json_content" | jq \
            '.mcpServers["nextjs-mcp"] = {"command":"npx","args":["-y","@modelcontextprotocol/server-filesystem","./"]}'
        return
    fi

    echo "$json_content"
}

_mcp_generator_add_python() {
    local project_dir="$1"
    local json_content="$2"

    echo "  ℹ️  Python detectado" >&2

    # Detecta subframework Django
    if grep -q "django" "$project_dir/requirements.txt" 2>/dev/null || \
       grep -q "django" "$project_dir/pyproject.toml" 2>/dev/null; then
        echo "  ✅ Django detectado" >&2
        echo "$json_content" | jq \
            '.mcpServers["django-mcp"] = {"command":"uvx","args":["django-mcp"]}'
        return
    fi

    echo "$json_content"
}
```

**Verificar GREEN** (após correção):
```bash
bats tests/functional.bats --filter "mcp_generator_create"
```
**Output esperado**: `ok 1 mcp_generator_create com stack laravel gera JSON com chave mcpServers`

**Commit após B5**:
```
fix(mcp-json-generator): refatorar helpers para modificar json_content via jq

Corrige bug onde _mcp_generator_add_laravel, _mcp_generator_add_nodejs e
_mcp_generator_add_python apenas faziam echo de mensagens sem modificar
o JSON gerado. Refatora para:
- json_content construído via jq incremental (não concatenação de string)
- Helpers recebem json atual como parâmetro e retornam json enriquecido
- Saídas de progresso redirecionadas para stderr (não poluem o JSON)
```

---

### Sub-task B3: Corrigir Bug B6 — stack-detector.sh

**Arquivo**: `lib/stack-detector.sh`  
**Ação**: modificar  
**Problema**: `stack_get_mcps` usa `case "$stack"` com valores `django` e `nextjs`, mas `stack_detect` retorna `nodejs` e `python`. O `case` nunca corresponde, retornando sempre vazio.

**Localização**: função `stack_get_mcps` (linhas 129–153)

**Substituir a função `stack_get_mcps` por**:

```bash
stack_get_mcps() {
    local project_dir="${1:-.}"
    local stack
    stack=$(stack_detect "$project_dir")
    local mcps=()

    case "$stack" in
        laravel)
            mcps+=("laravel-boost")
            ;;
        nodejs)
            # Verifica subframework Next.js
            if [ -f "$project_dir/next.config.js" ] || [ -f "$project_dir/next.config.mjs" ]; then
                mcps+=("nextjs-mcp")
            fi
            ;;
        python)
            # Verifica subframework Django
            if grep -q "django" "$project_dir/requirements.txt" 2>/dev/null || \
               grep -q "django" "$project_dir/pyproject.toml" 2>/dev/null; then
                mcps+=("django-mcp")
            fi
            ;;
    esac

    if [ ${#mcps[@]} -eq 0 ]; then
        echo ""
    else
        echo "${mcps[*]}"
    fi
}
```

**Verificar GREEN**:
```bash
bats tests/functional.bats --filter "stack_get_mcps"
```
**Output esperado**: `ok 2 stack_get_mcps com input nodejs retorna resultado não vazio`

**Commit após B6**:
```
fix(stack-detector): alinhar stack_get_mcps com valores reais de stack_detect

Corrige bug onde o case verificava "django" e "nextjs" mas stack_detect
retorna "nodejs" e "python". Atualiza para:
- nodejs: verifica next.config.js/mjs para detectar subframework Next.js
- python: verifica requirements.txt e pyproject.toml para Django
```

---

### Sub-task B4: Corrigir Bug B7 — detect.sh

**Arquivo**: `lib/detect.sh`  
**Ação**: modificar  
**Problema**: `find "$root/tests" -name "*.php" -o -name "*.js"` sem agrupamento explícito. Sem parênteses, o `-o` tem precedência mais baixa que o AND implícito — ao combinar com outros predicados (como `-maxdepth`), a condição `-name "*.js"` fica desacoplada do path constraint. Além disso, sem agrupamento a expressão pode dar resultado incorreto em algumas implementações de `find`.

**Localização**: função `is_legacy` (linhas 236–256 em `lib/detect.sh`)

**Modificar apenas a linha do `find`**:

Linha atual:
```bash
local test_count=$(find "$root/tests" -name "*.php" -o -name "*.js" 2>/dev/null | wc -l)
```

Linha corrigida:
```bash
local test_count=$(find "$root/tests" \( -name "*.php" -o -name "*.js" \) 2>/dev/null | wc -l)
```

**Verificar GREEN**:
```bash
bats tests/functional.bats --filter "is_legacy"
```
**Output esperado**: `ok 3 is_legacy com diretório tests contendo .js não retorna falso positivo`

**Commit após B7**:
```
fix(detect): adicionar agrupamento lógico no find da função is_legacy

Corrige find sem parênteses explícitos no operador -o. Sem agrupamento,
combinações com outros predicados desacoplam o -name "*.js" do path
constraint. Aplicado: \( -name "*.php" -o -name "*.js" \)
```

---

### Sub-task B5: Corrigir Bug B8 — bin/devorq

**Arquivo**: `bin/devorq`  
**Ação**: modificar  
**Problema**: `cmd_skills` itera com `for skill_dir in "$DEVORQ_DIR/skills"/*/` sem verificar se o diretório `skills/` existe. Quando vazio ou ausente, o glob expande para o padrão literal (com `*`), causando iteração com path inválido e possível item fantasma na saída.

**Localização**: função `cmd_skills` (linhas 220–231 em `bin/devorq`)

**Substituir a função `cmd_skills` por**:

```bash
cmd_skills() {
    local skills_dir="$DEVORQ_DIR/skills"

    if [ ! -d "$skills_dir" ]; then
        echo "Skills DEVORQ (0 skills):"
        return 0
    fi

    echo "Skills DEVORQ ($(ls -1 "$skills_dir/" 2>/dev/null | wc -l | tr -d ' ') skills):"

    local found_any=false
    for skill_dir in "$skills_dir"/*/; do
        [ -d "$skill_dir" ] || continue
        found_any=true
        local skill
        skill=$(basename "$skill_dir")
        local version=""
        if [ -f "$skill_dir/CHANGELOG.md" ]; then
            version=$(grep -o 'v[0-9]\+\.[0-9]\+\.[0-9]\+' "$skill_dir/CHANGELOG.md" 2>/dev/null | head -1)
        fi
        echo "  - $skill ${version:-v?}"
    done
}
```

**Verificar GREEN**:
```bash
bats tests/functional.bats --filter "cmd_skills"
```
**Output esperado**: `ok 4 cmd_skills em diretório sem skills retorna mensagem limpa sem item fantasma`

**Commit após B8**:
```
fix(cli): validar existência do diretório skills antes de iterar em cmd_skills

Corrige iteração com glob sem verificação de existência do diretório.
Quando .devorq/skills/ não existe, o glob expandia para padrão literal
causando item fantasma na saída. Adiciona:
- Verificação [ -d "$skills_dir" ] antes do loop
- Guard [ -d "$skill_dir" ] || continue dentro do loop
```

---

## 4. VERIFICAÇÃO

### Após cada bug (verificação individual)

```bash
bats tests/functional.bats
```
**Output esperado após todos os 4 bugs corrigidos**:
```
ok 1 mcp_generator_create com stack laravel gera JSON com chave mcpServers
ok 2 stack_get_mcps com input nodejs retorna resultado não vazio
ok 3 is_legacy com diretório tests contendo .js não retorna falso positivo
ok 4 cmd_skills em diretório sem skills retorna mensagem limpa sem item fantasma

4 tests, 0 failures
```

### Verificação final de regressão

```bash
bats tests/
```
**Output esperado**:
```
44 tests, 0 failures  (suite completa, sem regressões)
```
> Nota: com `tests/functional.bats` adicionado, o total passa para **48/48**.

### Smoke test CLI

```bash
./bin/devorq skills
```
**Output esperado**: lista com 15 skills, todas com versão, sem erros ou itens fantasma.

---

## 5. PADRÕES OBRIGATÓRIOS PARA ESTA TASK

- **TDD obrigatório**: escrever teste RED antes de qualquer correção. Verificar falha antes de implementar.
- **Um commit por bug**: B5, B6, B7, B8 — cada um com commit individual antes de avançar.
- **Não modificar testes existentes**: `sourcing.bats` e `paths.bats` devem continuar passando 100%.
- **Saídas de progresso via stderr**: em funções que retornam dados via stdout (como os helpers do mcp-generator), usar `>&2` para mensagens de log.
- **Bash puro**: sem dependências novas além de `jq` (já existente).

Regras globais em: `.devorq/rules/` e `CLAUDE.md`

---

## 6. DONE CRITERIA

- [ ] `tests/functional.bats` criado com 4 testes
- [ ] Cada teste falhou no RED (confirmado antes de implementar)
- [ ] `mcp_generator_create` com stack laravel gera JSON com chave `mcpServers`
- [ ] `stack_get_mcps` com input `nodejs` retorna valor não vazio
- [ ] `is_legacy` com diretório `tests/` contendo `.js` retorna "modern" (não legacy)
- [ ] `cmd_skills` em dir sem `skills/` retorna "0 skills" sem item fantasma
- [ ] `bats tests/functional.bats` → 4/4 ok
- [ ] `bats tests/` → 48/48 ok (44 anteriores + 4 novos, sem regressões)
- [ ] 4 commits individuais com mensagens convencionais em pt-BR
- [ ] Nenhum arquivo fora da lista autorizada modificado

---

## 7. RETORNO ESPERADO

Ao concluir, retornar ao arquiteto:

```markdown
# RETORNO — Bloco B: Correção de Bugs

- **SHA commit B5 (mcp-json-generator)**: [hash]
- **SHA commit B6 (stack-detector)**: [hash]
- **SHA commit B7 (detect — is_legacy)**: [hash]
- **SHA commit B8 (cli — cmd_skills)**: [hash]
- **Testes functional.bats**: [4/4 passando]
- **Suite completa bats tests/**: [48/48 passando]
- **Smoke test skills**: [N skills listadas, sem erros]
- **Desvios do plano**: [nenhum | descrição objetiva]
- **Erros encontrados**: [nenhum | descrição]
```

---

## NOTAS DO ARQUITETO

**Sobre Bug B5 (mcp-json-generator)**: O bug é estrutural — os helpers foram implementados apenas como funções de diagnóstico (echo para stdout), sem integração com o JSON em construção. A refatoração usa `jq` incremental, onde cada helper recebe o JSON atual via argumento `$2` e imprime o JSON modificado no stdout. Mensagens de progresso devem ir para `>&2` para não corromper o JSON.

**Sobre Bug B6 (stack-detector)**: O `stack_detect` retorna `nodejs` e `python` (valores genéricos), mas `stack_get_mcps` verificava `nextjs` e `django` (subframeworks). O correto é verificar o valor genérico e, dentro do case, fazer detecção do subframework nos arquivos do projeto.

**Sobre Bug B7 (detect)**: O arquivo correto é `lib/detect.sh` (não `lib/detection.sh` — são arquivos distintos). A função `is_legacy` está em `lib/detect.sh` linha 236.

**Sobre Bug B8 (cmd_skills)**: Sem o guard `[ -d "$skill_dir" ] || continue`, quando o diretório está vazio o glob pode expandir para o padrão literal `"$DEVORQ_DIR/skills/*/"` que não existe, mas o `basename` ainda executa e imprime `*` como skill name.

### REGRA GLOBAL DE COMMITS

Todos os handoffs DEVORQ devem seguir esta estrutura de commit:

- **Formato**: tipo(especialização): descrição detalhada
- **Idioma**: português do Brasil
- **Sem emojis**: usar texto puro
- **Sem Co-Authorship**: remover linhas de co-authored-by
- **Corpo detalhado**: cada item em linha própria
- **Exemplo**:
  ```
  fix(detect): adicionar agrupamento lógico no find da função is_legacy

  Corrige find sem parênteses explícitos no operador -o.
  ```
