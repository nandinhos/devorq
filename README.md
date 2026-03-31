# 🚀 DEVORQ - Desenvolvimento Orquestrador (v1.3.0)

> **"Transformando LLMs em Desenvolvedores de Elite através de Disciplina Técnica e Orquestração de Contexto."**

O **DEVORQ** é um framework de workflow avançado que impõe as melhores práticas de engenharia de software em qualquer LLM (Claude, Gemini, GPT-4). Ele orquestra o ciclo de vida do desenvolvimento, prevenindo débitos técnicos e garantindo que o código produzido seja modular, testado e aderente à stack do projeto.

---

## 🛠 Os Três Pilares do DEVORQ

O ecossistema DEVORQ é sustentado por três componentes fundamentais:

### 1. Agentes Especializados (6 Agentes)
Diferente de prompts genéricos, o DEVORQ utiliza agentes com contextos profundos em stacks específicas:
- **`laravel`** - Expert em Laravel Ecosystem & TALL Stack (Tailwind, Alpine, Livewire).
- **`filament`** - Especialista em construir painéis administrativos robustos com Filament PHP.
- **`python`** - Focado em análise de dados, extração de informações e automação.
- **`php`** - Desenvolvedor PHP moderno seguindo estritamente as normas PSR.
- **`shell`** - Expert em Bash, automação de infraestrutura e scripting.
- **`general`** - O orquestrador central que coordena a interação entre os demais agentes.

### 2. Skills DEVORQ (11 Skills)
Coleção de ferramentas e metodologias para manter a qualidade durante o desenvolvimento:
- `/scope-guard`: **Obrigatório**. Bloqueia over-engineering e garante o cumprimento do contrato.
- `/pre-flight`: Valida tipos, enums e estruturas antes de iniciar o código.
- `/env-context`: Detecção automática e contínua da stack e do ambiente.
- `/schema-validate`: Garante a integridade do banco de dados e constraints.
- `/quality-gate`: Checklist técnico rigoroso executado antes de cada commit.
- `/session-audit`: Auditoria de eficiência e identificação de gaps no workflow.
- `/spec-export`: Gera handoffs técnicos perfeitos para troca de modelos AI.
- `tdd`: Framework nativo para ciclo RED → GREEN → REFACTOR.
- `systematic-debugging`: Metodologia de investigação profunda de bugs.
- `code-review`: Revisão automática baseada em princípios de Clean Code.
- `learned-lesson`: Documentação persistente de aprendizados para evitar erros futuros.

### 3. Regras de Stack (Quality Gates)
Localizadas em `.devorq/rules/stack/`, definem o "padrão ouro" para cada linguagem:
- **Laravel-Tall**: Proíbe logic em views, exige uso de Actions/Services.
- **Python**: Exige Type Hints, Docstrings e padrões de persistência.
- **PHP**: Aplica padrões PSR e Tipagem Estrita (Strict Types).

---

## ⚡ Guia de Início Rápido

### Instalação Profissional

```bash
# 1. Clone o repositório
git clone https://github.com/nandinhos/devorq.git

# 2. Integre ao seu projeto existente
cp -r .devorq/ /caminho/do/seu-projeto/
cp -r bin/ /caminho/do/seu-projeto/
cp lib/detect.sh /caminho/do/seu-projeto/lib/

# 3. Dê permissão ao CLI
chmod +x /caminho/do/seu-projeto/bin/devorq
```

### Comandos de Ativação (Slash Commands)

Você pode invocar o poder do DEVORQ diretamente no chat do seu LLM:
- `/devorq-laravel [tarefa]` - Ativa o contexto Laravel TALL.
- `/devorq-python [tarefa]` - Inicia processamento de dados Python.
- `/devorq-flow [tarefa]` - Executa o ciclo completo desde o escopo até o commit.

---

## 🏗 Estrutura do Projeto

```text
devorq/
├── .devorq/             # Core: Agentes, Skills e Regras
├── bin/                 # CLI Executável (devorq)
├── lib/                 # Bibliotecas de Orquestração e Validação
├── prompts/             # Ativações otimizadas para Claude/Gemini/OpenCode
├── docs/                # Documentação técnica detalhada
└── SLASH_COMMANDS.md    # Referência rápida de comandos
```

---

## 📌 Documentação Complementar

- [**Guia de Instalação**](INSTALL.md) - Métodos avançados e Docker.
- [**Fluxo de Desenvolvimento**](FLUXO_DESENVOLVIMENTO.md) - Explicando o ciclo de vida.
- [**Quick Start**](QUICKSTART.md) - Templates de prompts de ativação.
- [**Slash Commands**](SLASH_COMMANDS.md) - Tabela completa de atalhos.

---

## 🛡 Licença

Distribuído sob a licença MIT. Veja `LICENSE` para mais informações.

---
*Criado por @nandinhos - Elevando o nível do desenvolvimento assistido por AI.*