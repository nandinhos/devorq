# DEVORQ Slash Commands

> Comandos para ativar o workflow DEVORQ em qualquer plataforma de IA

---

## Como Usar

Simply type the slash command at the start of your message to activate DEVORQ mode.

---

## Comandos Disponíveis

### /devorq
**Ativa**: Modo completo DEVORQ com todas as verificações

```
/devorq implementar sistema de autenticação OAuth2
```

Ativa:
- Detecção automática de contexto
- Contrato de escopo (/scope-guard)
- Validação de tipos (/pre-flight)
- TDD obrigatório
- Quality gate (/quality-gate)
- Session audit (/session-audit)

---

### /devorq-laravel
**Ativa**: Modo Laravel TALL Stack

```
/devorq-laravel criar componente Livewire para列表 de usuários
```

Ativa:
- Agente Laravel expert
- Regras Laravel/TALL
- Validação contra documentação oficial
- TDD com Pest/Phpunit

---

### /devorq-shell
**Ativa**: Modo Shell/Bash scripting

```
/devorq-shell criar script para backup automático do banco
```

Ativa:
- Agente Shell expert
- Scripts com set -eEo pipefail
- Validação de portabilidade

---

### /devorq-python
**Ativa**: Modo Python (análise de dados/documentos)

```
/devorq-python extrair dados de PDFs e gerar relatório
```

Ativa:
- Agente Python expert
- Type hints obrigatórios
- Docstrings formatadas
- Testes com pytest

---

### /devorq-filament
**Ativa**: Modo Filament Admin

```
/devorq-filament criar panel admin para gestão de usuários
```

Ativa:
- Agente Filament expert
- Resource/Form/Table builders
- Widgets para dashboard

---

### /devorq-start
**Ativa**: Inicializar projeto DEVORQ

```
/devorq-start
```

Executa:
- Detecção de stack
- Detecção de tipo (greenfield/brownfield/legacy)
- Criação de regras do projeto

---

### /devorq-checkpoint
**Ativa**: Criar checkpoint de continuidade

```
/devorq-checkpoint
```

Salva:
- Estado atual do git
- Stack e contexto
- Para recuperação em caso de rate limit

---

### /devorq-audit
**Ativa**: Auditoria de sessão

```
/devorq-audit
```

Classifica:
- EFICIENTE / ACEITÁVEL / DESPERDIÇADA
- Identifica causa raiz
- Métricas de eficiência

---

### /devorq-info
**Ativa**: Exibir informações de estado e versão do projeto

```
/devorq-info
```

Inspeciona:
- Versão core do orquestrador
- Stack detectada e runtime ativo
- Caminhos e configuração de ambiente

---

### /devorq-skills
**Ativa**: Listagem de skills instaladas e versões

```
/devorq-skills
```

Exibe:
- Todas as skills disponíveis no diretório .devorq/skills/
- Versão atual de cada skill (baseada no CHANGELOG)
- Recomendações de atualização de skills

---

### /devorq-upgrade
**Ativa**: Atualização interativa do core DEVORQ

```
/devorq-upgrade
```

Comportamento:
- **Interativo**: Solicita confirmação do usuário antes de agir
- Atualiza binários em bin/ e bibliotecas em lib/
- Recomenda atualização para melhorar performance e estabilidade

---

## Formato de Resposta DEVORQ

Ao ativar qualquer comando, o fluxo segue:

```
┌────────────────────────────────────────────┐
│  DEVORQ - [STACK]                          │
├────────────────────────────────────────────┤
│  Contexto: [detected automatically]        │
│  Stack: [laravel/python/php/shell]          │
│  LLM: [antigravity/gemini/claude/opencode]  │
├────────────────────────────────────────────┤
│  Fluxo:                                     │
│  1. /scope-guard → 2. /pre-flight           │
│  3. TDD → 4. /quality-gate                  │
│  5. /session-audit → checkpoint             │
└────────────────────────────────────────────┘
```

---

## Skills Disponíveis (17)

| Comando | Descrição |
|---------|-----------|
| `/devorq-info` | Exibe estado, versão e contexto do projeto |
| `/devorq-skills` | Lista todas as skills e suas versões |
| `/devorq-upgrade` | Atualiza infraestrutura do orquestrador (Interativo) |
| `/spec` | Gera contrato de escopo (FAZER/NÃO FAZER/ARQUIVOS) → Gate 1 |
| `/break` | Decompõe tarefa complexa em subtarefas manejáveis |
| `/pre-flight` | Valida tipos, enums e dependências → Gate 2 |
| `/quality-gate` | Checklist pré-commit → Gate 3 |
| `/learned-lesson` | Captura lições da sessão → Gate 5 |
| `/session-audit` | Coleta métricas de eficiência |
| `/env-context` | Detecta stack, runtime e banco |
| `/tdd` | Ciclo RED → GREEN → REFACTOR |
| `/systematic-debugging` | Investigação metódica de bugs |
| `/code-review` | Revisão baseada em Clean Code |
| `/schema-validate` | Valida integridade de schema |
| `/integrity-guardian` | Valida padrões Livewire/Alpine |
| `/brainstorming` | Fase de design e exploração |
| `handoff generate` | Gera spec para próximo LLM → Gate 4 |
| `/scope-guard` | Alias para /spec |
| constraint-loader | Carrega artefatos por tipo |
| verification | Verificação pré-completion |

---

> **Fluxo v2.1**: `/spec` seguido de `/break` é obrigatório antes de enviar sub-tarefas para camada subordinada.

---

## Configuração por Plataforma

### Claude Code / Claude Desktop
Adicionar em `CLAUDE.md`:
```
Use DEVORQ workflow para todas as tasks.
Comandos: /devorq, /devorq-laravel, /devorq-shell
```

### Gemini CLI
Adicionar em `.env` ou configurações:
```
DEVORQ_MODE=true
```

### Antigravity
Suporta automaticamente via contexto.

### OpenCode
Suporta automaticamente via contexto.

---

## Exemplos de Uso

### Laravel Feature
```
/devorq-laravel criar sistema de notificações em tempo real com Livewire e Pusher
```

### Python Data Analysis
```
/devorq-python analisar planilha Excel com dados de vendas e gerar gráficos
```

### Shell Script
```
/devorq-shell criar script de deploy automático com Docker e GitHub Actions
```

### Full Flow
```
/devorq implementar API RESTful com autenticação JWT e documentação OpenAPI
```

---

> **Nota**: Os comandos podem ser combinados ou customizados conforme necessidade do projeto.