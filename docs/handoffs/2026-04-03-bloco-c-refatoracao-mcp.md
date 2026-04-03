# HANDOFF PACKAGE — Bloco C: Refatoração de Consistência MCP (TDD obrigatório)

> **Modelo Híbrido (Opção C)**  
> Seções 1, 4 e 6 geradas com base no estado atual do projeto.  
> Princípio: o executor abre este arquivo e executa. Zero perguntas.

---

## METADADOS

- **Tarefa**: Reverter desvio criado no Bloco B em `lib/stack-detector.sh` e adequar os testes funcionais em `tests/functional.bats`
- **Data**: 2026-04-03
- **Arquiteto**: Nando Dev + Antigravity (Tier 1)
- **Executor recomendado**: Tier 2 (qualquer modelo)
- **Fallback**: qualquer modelo Tier 2 com este mesmo pacote
- **Branch**: main
- **Worktree**: não aplicável — trabalhar direto em main
- **Estimativa**: 2 arquivos modificados, 1 commit

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
[Nova sessão Tier 1 — verificação] → lê este handoff + RETORNO → decide próximo bloco
```

### Para o executor (Tier 2)

- Abra uma **sessão nova** na sua LLM (sem contexto anterior)
- Leia apenas este arquivo — ele contém tudo que precisa
- Ao concluir, preencha o bloco da Seção 7 e entregue ao arquiteto
- **Não é necessário explicar o que fez** além do formato da Seção 7

---

## 1. SNAPSHOT DO PROJETO

- **Stack**: Bash puro + bats (framework de testes)
- **Estado atual**: Bloco B concluído e testado. Um desvio arquitetural foi introduzido no `lib/stack-detector.sh` para contornar um teste conceitualmente falho. O executor do Bloco B incluiu estaticamente MCPs base inexistentes (`nodejs-mcp`, `python-mcp`), o que dessincronizou o detector em relação ao gerador formal de JSON.
- **Branch de trabalho**: main

---

## 2. CONTRATO DE ESCOPO

### FAZER

1. Corrigir o cenário de teste em `tests/functional.bats` garantindo que o retorno deve ser **vazio** para linguagens genéricas caso nenhum subframework (ex: Next.js) seja detectado.
2. Adicionar cenário de teste para garantir que o MCP correto seja retornado de framework for detectado.
3. Voltar atrás na inclusão cega de `nodejs-mcp` e `python-mcp` na sub-rotina de `stack_get_mcps`.

### NÃO FAZER

- Não alterar a funcionalidade da geração incremental do JSON via `jq` implementada no Bloco B.
- Não mexer em arquivos ou suítes de testes fora das especificadas abaixo.

### ARQUIVOS AUTORIZADOS

- `tests/functional.bats` (modificar)
- `lib/stack-detector.sh` (modificar)

### ARQUIVOS PROIBIDOS

- `lib/core.sh`
- `lib/mcp-json-generator.sh`
- `tests/sourcing.bats`
- `tests/paths.bats`

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

### Sub-task C1: Corrigir Bug Arquitetural (TDD — Testes modificados primeiro)

**Arquivo**: `tests/functional.bats`  
**Ação**: modificar  

Vamos refatorar o teste referente ao Bloco B6 para atuar com clareza semântica.
No arquivo local, apague o bloco de testes sob o comentário `# --- Bug B6: stack_get_mcps — deve retornar MCPs para nodejs e python ---` (do `@test "stack_get_mcps com input nodejs retorna resultado não vazio"` até a sua chave de fechamento respectiva).

**Substitua pelas seguintes asserções estruturais**:

```bash
# --- Refatoração Bloco C: stack_get_mcps não deve emitir MCP base se não houver framework específico ---

@test "stack_get_mcps com input nodejs generico (sem nextjs) retorna resultado vazio" {
    source "$DEVORQ_ROOT/lib/stack-detector.sh"

    stack_detect() { echo "nodejs"; }
    export -f stack_detect

    local tmpdir
    tmpdir=$(mktemp -d /tmp/devorq-nodejs-test-XXXXXX)
    # diretório vazio, logo sem next.config.js ou package.json além do detect mock

    run stack_get_mcps "$tmpdir"
    [ "$status" -eq 0 ]
    [ -z "$output" ]

    rm -rf "$tmpdir"
}

@test "stack_get_mcps com input nodejs e next.config.js retorna resultado não vazio com nextjs-mcp" {
    source "$DEVORQ_ROOT/lib/stack-detector.sh"

    stack_detect() { echo "nodejs"; }
    export -f stack_detect

    local tmpdir
    tmpdir=$(mktemp -d /tmp/devorq-nextjs-test-XXXXXX)
    touch "$tmpdir/next.config.js"

    run stack_get_mcps "$tmpdir"
    [ "$status" -eq 0 ]
    [ -n "$output" ]
    [[ "$output" == *"nextjs-mcp"* ]]

    rm -rf "$tmpdir"
}
```

**Verificar RED no bats**:
```bash
bats tests/functional.bats
```
**Output esperado**: Como ainda estamos no ambiente defasado do último Bloco, o teste `stack_get_mcps com input nodejs generico...` falhará, já que o código reportará a existência falsa da string `nodejs-mcp`.

---

### Sub-task C2: Reverter a Injeção Falsa (`lib/stack-detector.sh`)

**Arquivo**: `lib/stack-detector.sh`  
**Ação**: modificar  

Refatorar a estrutura do `case` em `stack_get_mcps` (linhas ~132 até ~152), para que se limite apenas a repassar as condicionais reais de framework que o gerador de fato dispõe na infraestrutura do DEVORQ:

```bash
    case "$stack" in
        laravel)
            mcps+=("laravel-boost")
            ;;
        nodejs)
            if [ -f "$project_dir/next.config.js" ] || [ -f "$project_dir/next.config.mjs" ]; then
                mcps+=("nextjs-mcp")
            fi
            ;;
        python)
            if grep -q "django" "$project_dir/requirements.txt" 2>/dev/null || \
               grep -q "django" "$project_dir/pyproject.toml" 2>/dev/null; then
                mcps+=("django-mcp")
            fi
            ;;
    esac
```

**Verificar GREEN**:
```bash
bats tests/functional.bats --filter "stack_get_mcps"
```

**Commit após a verificação (Sub-tasks 1 & 2)**:
```text
refactor(mcp): remover MCPs genéricos estáticos de stack_get_mcps

Remove as flags de `nodejs-mcp` e `python-mcp` inseridas anteriormente. 
A documentação padrão de dependências dessas linguagens é tratada 
diretamente pelo escopo global do Context7. A inclusão genérica apenas
gerava assimetria com lib/mcp-json-generator.sh, que nunca criava servers
com esses nomes. Atualiza as asserções em tests/functional.bats testando a 
ausência explícita e o condicional de subframework isoladamente.
```

---

## 4. VERIFICAÇÃO

### Verificação final de regressão

```bash
bats tests/
```
**Output esperado**: Todas as suítes rodando OK e sem regressões (incluindo paths, sourcing, e todos os blocos antigos). Note que será um teste extra no montante com as mudanças do arquivo funcional.

---

## 5. PADRÕES OBRIGATÓRIOS PARA ESTA TASK

- **TDD obrigatório**: modificar os blocos de teste, confirmar que os falsos-positivos são barrados primeiro (RED logic gate default), somente depois aplicar do fix de sistema.
- **Commit único**: Diferente do bloco anterior, para essas 2 micro mudanças apenas usar o commit template ofertado.

---

## 6. DONE CRITERIA

- [ ] Arquivo `tests/functional.bats` atualizado para conter separação entre framework específico vs ambiente cru.
- [ ] O teste validou corretamente que no branch genérico de NodeJS, o `stack_get_mcps` retorna string vazia.
- [ ] Alteração de `lib/stack-detector.sh` aplicada sem falhas e confirmando o GREEN generalizado.
- [ ] Arquivos de outras bibliotecas do devorq permaneceram intactos.

---

## 7. RETORNO ESPERADO

Ao concluir, retornar ao arquiteto:

```markdown
# RETORNO — Bloco C: Refatoração MCP

- **SHA commit C1 (testes & refatoração MCP)**: [hash]
- **Testes functional.bats**: [todos passando]
- **Suite completa bats tests/**: [total de testes/passando]
- **Desvios do plano**: [nenhum | descrição objetiva]
- **Erros encontrados**: [nenhum | descrição]
```

---

## NOTAS DO ARQUITETO

Lembrete global a todos os LLMs sobre o DEVORQ e o contexto do sistema MCP: as bibliotecas universais e de linguagens mainstream como JS/Python não precisam de pacotes locais (nodes) caso não precisem rodar execuções em máquinas interativas para tal (como o DB access do Django e do Laravel Boost); o contexto do repositório sendo lido pelo server do filesystem acoplado à documentação viva do `Context7` mitiga todas essas questões. Sempre que possível, deixe o sistema se apoiar na simplicidade.

### REGRA GLOBAL DE COMMITS
Todos os handoffs DEVORQ devem seguir esta estrutura de commit:
- **Formato**: tipo(especialização): descrição detalhada
- **Idioma**: português do Brasil
- **Sem emojis**: usar texto puro
- **Sem Co-Authorship**: remover linhas de co-authored-by
- **Corpo detalhado**: cada item em linha própria
