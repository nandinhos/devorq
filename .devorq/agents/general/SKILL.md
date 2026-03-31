# Agente General - Orquestrador

## Responsabilidade
Coordenar o fluxo completo de desenvolvimento, identificando qual agente especializado deve atuar e garantindo que todas as fases sejam seguidas.

## Detecção Automática de Stack

```bash
# Detectar stack
if [ -f "composer.json" ] && grep -q "laravel" composer.json; then
    stack="laravel"
elif [ -f "composer.json" ]; then
    stack="php"
elif [ -f "package.json" ]; then
    stack="node"
elif [ -f "requirements.txt" ]; then
    stack="python"
fi
```

## Agentes Disponíveis

| Stack | Agente | Quando Usar |
|-------|--------|-------------|
| Laravel | laravel/SKILL.md | Projetos Laravel |
| Filament | filament/SKILL.md | Admin panels com Filament |
| PHP puro | php/SKILL.md | Projetos PHP sem framework |
| Python | python/SKILL.md | Scripts de análise, extração |
| Genérico | general/SKILL.md | Outras stacks |

## Fluxo de Orquestração

### 1. Inicialização (devorq init)
- Detectar stack
- Detectar tipo projeto (greenfield/brownfield/legacy)
- Detectar LLM
- Carregar regras do projeto
- Selecionar agente especializado

### 2. Task (devorq flow "intent")
- Validar intent
- Carregar agente especializado
- Executar /scope-guard
- Executar /pre-flight
- Executar /schema-validate
- Implementar com TDD
- Executar /quality-gate
- Executar /session-audit
- Criar checkpoint

### 3. Handoff (spec-export)
- Se mudar de LLM, exportar spec
- Se rate limit, usar checkpoint

## Regras de Ouro

1. **Sempre detectar stack primeiro** - Sem detecção = decisões erradas
2. **Usar agente especializado** - Cada stack tem nuances
3. **Seguir fluxo completo** - Não pular fases
4. **Validar com Context7** - Fonte de verdade é documentação oficial
5. **Checkpoint antes de qualquer interrupção** - Rate limits acontecem

## Integração com MCP

```bash
# Validar documentação com Context7
npx @context7/mcp-server query "Laravel 12 migration create table"

# Validar versão específica
npx @context7/mcp-server query "PHP 8.4 typed properties"
```

## Contexto Persistente

O orchestrator mantém estado em `.devorq/state/`:
- context.json: Stack, LLM, tipo projeto
- session.json: Sessão atual
- checkpoints/: Para continuidade

## Feedback Loop

1. /session-audit classifica eficiência
2. Métricas são salvas
3. Próxima sessão usa contexto histórico
4. Agente aprende com padrões do projeto