# DEVORQ - Instalação e Uso

## O que é DEVORQ?

DEVORQ é um orquestrador de desenvolvimento orientado a skills que transforma qualquer LLM em um desenvolvedor disciplinado, seguindo as melhores práticas de programação.

## Requisitos

- Bash 4.0+
- Git
- (Opcional) Docker para projetos Laravel com Sail
- (Opcional) MCP Context7 para validação de documentação

## Instalação em Novo Projeto

### Método 1: Clone Direto

```bash
# Clone o repositório
git clone https://github.com/nandinhos/devorq.git /caminho/para/devorq

# Copie a estrutura para seu projeto
cp -r /caminho/para/devorq/.devorq /seu-projeto/
cp -r /caminho/para/devorq/bin /seu-projeto/
cp /caminho/para/devorq/lib/detect.sh /seu-projeto/lib/

# Configure a CLI
chmod +x /seu-projeto/bin/devorq
export PATH="$PATH:/seu-projeto/bin"

# Inicialize
cd /seu-projeto
devorq init
```

### Método 2: Submodule (Recomendado para múltiplos projetos)

```bash
# Adicione como submodule no seu projeto
git submodule add https://github.com/nandinhos/devorq.git .devorq

# Configure
chmod +x .devorq/bin/devorq
export PATH="$PATH:$(pwd)/.devorq/bin"

# Inicialize
devorq init
```

### Método 3: Instalação Global

```bash
# Clone global
git clone https://github.com/nandinhos/devorq.git /opt/devorq

# Adicione ao PATH (adicione no ~/.bashrc ou ~/.zshrc)
export DEVORQ_ROOT=/opt/devorq
export PATH="$PATH:$DEVORQ_ROOT/bin"

# Use em qualquer projeto
cd /seu-projeto
devorq init
```

## Uso Básico

### Inicializar Projeto

```bash
devorq init
```

Detecta automaticamente:
- Stack (Laravel, Node, Python, etc)
- Tipo de projeto (greenfield, brownfield, legacy)
- Runtime (Docker, local)
- Banco de dados
- LLM atual

### Executar Fluxo Completo

```bash
devorq flow "implementar sistema de login OAuth2"
```

Executa automaticamente:
1. Detecção de contexto
2. Análise de projeto (PRD, legado)
3. Estabelecimento de regras
4. Brainstorm rigoroso
5. Geração de contrato (/scope-guard)
6. Geração de spec detalhada

### Modo Agente

```bash
devorq agent
```

Mostra o fluxo completo de desenvolvimento e skills disponíveis.

### Verificar Contexto

```bash
devorq context
```

## Estrutura de Arquivos

```
seu-projeto/
├── .devorq/                 # Configurações DEVORQ
│   ├── skills/              # Skills do sistema
│   │   ├── scope-guard/
│   │   ├── tdd/
│   │   └── ...
│   ├── rules/               # Regras do projeto
│   │   └── project.md
│   └── state/               # Estado persistente
│       ├── context.json
│       └── ...
├── bin/
│   └── devorq               # CLI
├── lib/
│   ├── detect.sh            # Módulo de detecção
│   └── orchestration/
│       └── flow.sh          # Orquestrador
└── (seu código)
```

## Comandos Disponíveis

| Comando | Descrição |
|---------|-----------|
| `devorq init` | Inicializar projeto |
| `devorq flow <intent>` | Executar fluxo completo |
| `devorq agent` | Ativar modo agente |
| `devorq context` | Mostrar contexto atual |
| `devorq checkpoint` | Criar checkpoint |
| `devorq info` | Info resumida |
| `devorq skills` | Listar skills |
| `devorq help` | Ajuda |

## Configuração de MCP (Opcional)

Para usar validação com Context7, configure o `.mcp.json`:

```json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@context7/mcp-server"]
    }
  }
}
```

## Stack Suportadas

- **PHP puro**: Validação de PSR
- **Laravel**: TALL Stack (Tailwind, Alpine.js, Laravel, Livewire)
- **Filament**: Admin panels
- **Python**: Análise de documentos, extração de dados
- **Node.js**: Next.js, React, Vue
- **Go/Rust**: Genérico

## Fluxo de Desenvolvimento

```
1. devorq init                    → Configurar projeto
2. devorq flow "minha task"       → Executar task completa

Durante a implementação:
- /env-context     → Detectar contexto (automático)
- /scope-guard     → Contrato de escopo
- /pre-flight      → Validar tipos
- /schema-validate → Validar banco
- tdd              → RED → GREEN → REFACTOR
- /quality-gate    → Checklist pré-commit
- /session-audit   → Métricas de eficiência
- checkpoint       → Para continuidade
```

## Perguntas Frequentes

### Preciso de internet?
- Não, funciona offline para detecção de stack
- MCP Context7 requer internet para validação de documentação

### Funciona com qualquer LLM?
- Sim, detecta automaticamente: Antigravity, Gemini, Claude, MiniMax

### Posso customizar as skills?
- Sim, edite os arquivos em `.devorq/skills/`

### Como atualizar?
```bash
cd .devorq  # ou onde安装ou
git pull origin main
```

---

Para mais informações, consulte FLUXO_DESENVOLVIMENTO.md