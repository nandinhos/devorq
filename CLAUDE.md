# DEVORQ - Configuração para Claude Code

> Este arquivo ativa o workflow DEVORQ automaticamente no Claude Code.

## Ativação

Para ativar o modo DEVORQ, use qualquer um dos comandos slash:

### Comandos Principais

| Comando | Ativa |
|---------|-------|
| `/devorq` | Fluxo completo |
| `/devorq-laravel` | Modo Laravel TALL |
| `/devorq-shell` | Modo Shell/Bash |
| `/devorq-python` | Modo Python |
| `/devorq-filament` | Modo Filament |
| `/devorq-start` | Inicializar projeto |
| `/devorq-checkpoint` | Criar checkpoint |
| `/devorq-audit` | Auditoria de sessão |

## Fluxo Obrigatório

Ao ativar qualquer comando DEVORQ, siga esta sequência:

```
1. /scope-guard     → Contrato de escopo (OBRIGATÓRIO)
2. /pre-flight      → Validar tipos e enums
3. /env-context     → Detectar stack (automático)
4. tdd              → RED → GREEN → REFACTOR
5. /quality-gate    → Checklist pré-commit (OBRIGATÓRIO)
6. /session-audit   → Métricas (OBRIGATÓRIO)
7. checkpoint       → Para continuidade
```

## Regras de Ouro

1. **SEMPRE** usar /scope-guard antes de qualquer código
2. **SEMPRE** executar /quality-gate antes de commit
3. **SEMPRE** fazer /session-audit ao final da sessão
4. **NUNCA** pular fases de validação
5. **SEMPRE** criar checkpoint antes de interromper

## Stack Suportadas

- **Laravel/TALL**: Tailwind + Alpine.js + Laravel + Livewire
- **Filament**: Admin panels
- **PHP Puro**: PSR standards
- **Python**: Análise de dados, extração de documentos
- **Shell**: Bash scripting

## Detecção Automática

O sistema detecta automaticamente:
- Stack (via composer.json, package.json, requirements.txt)
- Tipo de projeto (greenfield, brownfield, legacy)
- Runtime (Docker, local)
- LLM atual (Antigravity, Gemini, Claude, MiniMax)

## Validação de Documentação

Para validar contra documentação oficial, usar MCP Context7:
```bash
npx @context7/mcp-server query "Laravel 12 migrations"
```

## Configuração DEVORQ

O estado é persistido em `.devorq/state/`:
- `context.json`: Stack, LLM, tipo
- `contracts/`: Contratos de escopo
- `checkpoints/`: checkpoints para continuidade
- `session-audits/`: Métricas de eficiência

---

> Para mais informações, consulte a documentação completa em: https://github.com/nandinhos/devorq