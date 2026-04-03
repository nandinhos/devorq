# 🚀 DEVORQ - Automação de Engenharia Multi-LLM (v2.1)

<div align="center">
  <p><strong>Transformando IAs em Desenvolvedores de Elite através de Orquestração Thin Client, Contextualização Incremental e Padrões Estritos.</strong></p>
</div>

---

## 🎯 O que é o DEVORQ?

O **DEVORQ** (Desenvolvimento Orquestrador) é um framework avançado projetado para acoplar metodologias sólidas de Engenharia de Software às principais LLMs (Claude, Gemini, OpenCode, GPT). Ele atua como um sistema nervoso central que, através de injeção de contexto agnóstica e automação via MCPs (Model Context Protocol), blinda o projeto contra *hallucinations*, over-engineering e quebra de regras arquiteturais.

Em sua versão **v2.1**, o DEVORQ adota formalmente a arquitetura **Thin Client vs Fat Server**, centralizando toda a "mente" do framework no arquivo pilar `activation.md` e tornando o prompt específico das IAs puramente estrutural.

---

## ⚙️ Arquitetura e Pilares da v2.1

### 1. Modelo de Comunicação Agnóstica (Multi-LLM)
O DEVORQ agora opera sobre a filosofia universal:
- **`prompts/activation.md`**: O "Cérebro" único universal. Contém todas as metodologias de orquestração (como iterar, como quebrar tarefas, o modelo mental de planejamento e TDD).
- **Adaptadores Finos (`gemini.md`, `claude.md`, etc)**: Interfaces mínimas exclusivas para o viés natural de cada modelo, focadas unicamente em engatilhar o protocolo primário.

### 2. O Processo de Sub-Engenharia (`/spec` & `/break`)
Nenhuma feature complexa é executada diretamente sob a abordagem de Big Bang. O fluxo impõe uma dissecção milimétrica:
1. **`/spec`**: A Inteligência atua como *Arquiteta* (Tier 1), formulando os limites estritos e o design isolado do problema.
2. **`/break`**: Quebra exata da arquitetura em pacotes subatômicos e testáveis.
3. **`Handoff`**: Documento de contrato de estado gerado em 7 blocos estruturados, que servirá de *Task Brief* impecável para a sessão executora (Tier 2).

### 3. As 17 Skills de Elite (Sistemas Interligados)
Um arsenal de ferramentas modulares acopladas em `.devorq/skills/`, entre elas:
- `handoff` - Geração do Pacote Padrão Ouro de sessão delegada.
- `scope-guard` - Proteção rígida do escopo contra desvios de engenharia e complexidade acidental.
- `quality-gate` - Pipeline analítico rigoroso pré-commit.
- `tdd` - Ciclo nativo iterativo Red-Green-Refactor.
- `learned-lesson` - Documentação persistente no repositório para evitar regressão das IAs (Zero-Shot optimization).

### 4. Orquestração Direta e Automática (Motor CLI)
A automação basal garante a adaptação ao ambiente real de build.
O motor nativo Bash CLI avalia a árvore de arquivos, detecta dependências e subframeworks (Laravel, Next.js, Django) via heurística local e vincula dinamicamente servidores de contexto MCP (Ex: **Laravel Boost MCP** para ecossistemas PHP e **Context7** para genéricos).

---

## ⚡ Quick Start

### 1. Clonagem e Acoplamento
```bash
git clone https://github.com/nandinhos/devorq.git

# Acople a orquestração no seu próprio projeto:
cp -r devorq/.devorq/ /caminho/do/projeto/
cp -r devorq/bin/ /caminho/do/projeto/
cp devorq/SLASH_COMMANDS.md /caminho/do/projeto/
```

### 2. Boot na Sessão de AI
Ao inicializar um terminal assistido ou painel de Inteligência (Cursor, Claude CLI, Gemini), inicie injetando o contexto base:
> *"Acesse e leia as diretrizes contidas em `prompts/activation.md`."*

### 3. Chamando Ferramentas
Invoque capacidades especializadas usando Slash Commands diretamente, exemplos:
- `/spec [escopo]` - Desenhar o projeto e blindar os contornos de arquitetura.
- `/break [escopo]` - Desengatilhar uma cadeia sequencial de testes e desenvolvimento.

---

## 🏗 Estrutura Central (Tree)

```text
/
├── .devorq/
│   ├── rules/          # Quality Gates engessados por domínio da linguagem
│   ├── skills/         # Catálogo das Skills operacionais do Workflow
│   └── templates/      # Padrões Universais (ex: Metodologia de Handoff)
├── bin/
│   └── devorq          # CLI Engine nativo em Shell Script
├── lib/
│   ├── detect.sh             # Motor avaliador AST Local de Frameworks
│   ├── mcp-json-generator.sh # Montador estrito de payload p/ MCPs
│   └── ...
├── prompts/
│   ├── activation.md   # Mente universal do Sistema (LLM-Agnostic)
│   └── *.md            # Adaptadores nativos para engines (Claude, etc)
├── docs/               # ADRs, Especificações e Histórico Rígido
└── SLASH_COMMANDS.md   # Índice Explicativo de Invocação Rápida
```

---

## 📍 Componentes Auxiliares

- [**SLASH COMMANDS**](SLASH_COMMANDS.md) - Manual instantâneo dos atalhos primários do sistema.
- [**Handoff Package**](docs/templates/handoff-package.md) - Entenda o modelo T1/T2 adotado.

---

## 🛡 Filosofia
O **DEVORQ** existe para garantir que a Inteligência Artificial não atue levianamente como uma rima livre de preencher código, mas sim sob o rigor de um *Engenheiro Sênior*, submetendo-se a restrições contratuais, testes obrigatórios e clareza de escopo desde o primeiro byte até o commit em `main`.

Distribuído sob a licença **MIT**. Veja o arquivo `LICENSE` para diretrizes legais.  
**@nandinhos — Elevando a régua do desenvolvimento automatizado.**