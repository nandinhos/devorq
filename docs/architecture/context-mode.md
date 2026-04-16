# Arquitetura — Context Mode (Modo Monstro)

## 1. Visão Geral

O **Modo Monstro** é um modo de operação do DEVORQ que ativa automaticamente quando o Context Mode está instalado e possui sessão ativa para o projeto. Seu objetivo é eliminar redundância de contexto entre sessões, resultando em ~45% de economia de tokens.

### Problema Resolvido

- Re-indexação de 400+ arquivos a cada nova sessão LLM
- Tokens desperdiçados em contexto redundante
- Rate limits mais frequentes por falta de cache
- Alucinações por falta de contexto relevante

### Solução

Índice persistente de contexto que sobrevive entre sessões. O próximo LLM recebe instantly o que precisa via busca no índice, sem precisar re-indexar.

---

## 2. Arquitetura de Componentes

```
┌─────────────────────────────────────────────────────────────────┐
│                         DEVORQ CLI                               │
│                     (bin/devorq)                                │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    lib/detection.sh                              │
│              detect_context_mode() [linha 800]                   │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                   Context Mode Binary                            │
│           ctx (ou context-mode em paths alternativos)            │
└─────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────────┐
│                    Session Database                              │
│     ~/.config/opencode/context-mode/sessions/{hash}.db          │
└─────────────────────────────────────────────────────────────────┘
```

### Fluxo de Ativação

```
devorq init / devorq context-mode status
           │
           ▼
    detect_context_mode()
           │
     ┌─────┼─────┐
     │     │     │
 not_inst no_sess active:*
     │     │     │
     ▼     ▼     ▼
  Warning  Warning  ✅ ATIVO
          │    │
          │    └─→ Carrega regras context-mode.md
          │         Ativa hierarquia ctx_search
          │
          └─→ Sugere: devorq context-mode init
```

---

## 3. Detecção — `detect_context_mode()`

**Arquivo:** `lib/detection.sh:800-837`

### Lógica de Detecção

```bash
detect_context_mode() {
    local root="${1:-.}"
    local home="${HOME:-/root}"

    # 1. Verificar binário ctx
    if command -v ctx > /dev/null 2>&1; then
        ctx_bin="ctx"
    else
        # Paths alternativos
        local ctx_bin_paths=(
            "$home/.nvm/versions/node/v22.22.1/bin/context-mode"
            "$home/.npm-global/bin/context-mode"
            "$home/.local/bin/context-mode"
            "/usr/local/bin/context-mode"
        )
        for bin_path in "${ctx_bin_paths[@]}"; do
            [ -f "$bin_path" ] && ctx_bin="$bin_path" && break
        done
    fi
    [ -z "$ctx_bin" ] && echo "not_installed" && return

    # 2. Verificar diretório de sessões
    local session_dir="$home/.config/opencode/context-mode/sessions"
    [ ! -d "$session_dir" ] && echo "no_sessions" && return

    # 3. Verificar DB do projeto (hash = sha256 do path absoluto)
    local project_hash
    project_hash=$(echo -n "$(cd "$root" && pwd)" | sha256sum | cut -c1-16)
    local db_path="$session_dir/$project_hash.db"

    if [ -f "$db_path" ]; then
        echo "active:$project_hash:$(du -k "$db_path" | cut -f1)"
    else
        echo "no_session"
    fi
}
```

### Retornos Possíveis

| Retorno | Significado | Ação |
|---------|-------------|------|
| `not_installed` | ctx binary não encontrado | Warning + instrução de instalação |
| `no_sessions` | Diretório de sessões não existe | Sugerir `ctx init` |
| `no_session` | DB do projeto não existe | Sugerir `ctx init` + `ctx index` |
| `active:HASH:SIZE` | Sessão ativa | Ativar Modo Monstro |

---

## 4. Hierarquia de Ferramentas

Quando o Modo Monstro está ativo, usar esta ordem de prioridade:

### Prioridade (da maior para menor economia)

| Prioridade | Ferramenta | Economia | Quando Usar |
|------------|------------|----------|-------------|
| 1 | `ctx_search` | ~95% | Buscar contexto indexado |
| 2 | `ctx_batch_execute` | ~70% | Múltiplos comandos/análises |
| 3 | `ctx_execute` | ~80% | Comandos únicos |
| 4 | `Read`/`grep` | 0% | Busca exata, escrita, interativo |

### Critérios de Indexação Automática

| Tipo | Mínimo | Exemplo |
|------|--------|---------|
| File read | 5KB+ | `Read app/Models/Contract.php` |
| Command output | 100 chars | `bash ls -la` |
| grep/search | qualquer | `grep "function"` |

### Quando NÃO Usar ctx_search

- Busca exata de arquivo conhecido (use Read direto)
- Operações de escrita/criação
- Comandos interativos
-养 LMshandoff (use `ctx index` antes)

---

## 5. Comandos

### `devorq context-mode status`

Mostra status atual do Context Mode.

```bash
devorq context-mode status
```

**Output possível:**
```
🐉 Status: ✅ ATIVO
   Session DB: a1b2c3d4e5f6g7h8.db (4KB)

   Economia estimada: ~45% tokens
   Tempo salvo: +35min/sessão
```

```
🐉 Status: ❌ NÃO INSTALADO
   Context-Mode não está instalado.

   Para instalar:
     npm install -g context-mode
```

```
🐉 Status: 🔶 SEM SESSÃO PARA ESTE PROJETO
   Execute: devorq context-mode init
```

### `devorq context-mode init`

Inicializa uma nova sessão de contexto para o projeto.

```bash
devorq context-mode init
```

### `devorq context-mode index [path]`

Indexa o projeto no contexto.

```bash
# Indexar projeto atual
devorq context-mode index

# Indexar diretório específico
devorq context-mode index /path/to/project
```

### `devorq context-mode search "<query>"`

Busca no índice de contexto.

```bash
devorq context-mode search "função de autenticação"
```

### `devorq context-mode stats`

Mostra estatísticas da sessão.

```bash
devorq context-mode stats
```

### `devorq context-mode doctor`

Diagnóstico do sistema Context Mode.

```bash
devorq context-mode doctor
```

---

## 6. Integração com DEVORQ

### `devorq init`

Durante inicialização, `detect_context_mode()` é executado automaticamente:

```bash
# 🐉 Detectar Context-Mode (Modo Monstro)
local ctx_status=$(detect_context_mode "$DEVORQ_ROOT")
if [[ "$ctx_status" == not_installed ]]; then
    log_warn "Context-Mode: não instalado (Modo Monstro desativado)"
elif [[ "$ctx_status" == no_session ]]; then
    log_warn "Context-Mode: sem sessão para este projeto"
    log_info "Execute: devorq context-mode init"
else
    local ctx_hash=$(echo "$ctx_status" | cut -d: -f2)
    local ctx_size=$(echo "$ctx_status" | cut -d: -f3)
    log "🐉 Context-Mode: ✅ ATIVO (${ctx_hash}.db, ${ctx_size}KB)"
fi
```

### `devorq info`

Status do Context Mode aparece no output de `devorq info`.

### Arquivo de Regras

Quando ativo, as regras em `.devorq/rules/context-mode.md` são carregadas e orientam o comportamento do LLM.

---

## 7. Métricas

### Economia de Tokens

| Cenário | Sem Context-Mode | Com Modo Monstro | Economia |
|---------|------------------|------------------|----------|
| Sessão típica (90min) | ~400KB tokens | ~220KB tokens | **45%** |
| Handoff entre LLMs | Re-indexar 400+ arquivos | Busca no índice | **~170 arquivos** |
| Rate limits | Frequentes | Raros | **~80% menos** |

### ROI

| Métrica | Valor |
|---------|-------|
| Implementação | ~4h |
| Economia/sessão | +35min |
| Break-even | ~7 sessões |

### Indicadores de Sucesso

- `% economia de tokens` > 40%
- `tempo salvo` > 30min/sessão
- `# handoffs bem-sucedidos` aumenta
- `taxa de alucinações` diminui

---

## 8. Arquivos Relacionados

| Arquivo | Descrição |
|---------|-----------|
| `lib/detection.sh:800` | Função `detect_context_mode()` |
| `bin/devorq:984-1033` | Comando `cmd_context_mode()` |
| `bin/devorq:1063-1106` | CLI `cmd_context_mode_cli()` |
| `.devorq/rules/context-mode.md` | Regras de operação |
| `docs/specs/implemented/SPEC-0063-...md` | Proposta completa (578 linhas) |

---

## 9. Troubleshooting

### ctx não encontrado

```bash
# Verificar instalação
which ctx
ctx --version

# Reinstalar
npm install -g context-mode
```

### Sessão não encontrada

```bash
# Inicializar nova sessão
devorq context-mode init

# Indexar projeto
devorq context-mode index
```

### DB corrompido

```bash
# Diagnóstico
devorq context-mode doctor

# Reconstruir índice
ctx index /path/to/project --rebuild
```

---

**Última atualização:** 2026-04-16
**Autor:** Nando Dev
**Versão:** 1.0
