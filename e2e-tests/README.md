# DEVORQ — E2E Tests Project

> Playwright E2E Tests para validar funcionalidades do sistema DEVORQ.

## Estrutura

```
e2e-tests/
├── playwright.config.ts      # Configuração do Playwright
├── package.json             # Dependências Node.js
├── tests/                   # Testes E2E
│   ├── devorq-cli.spec.ts   # Testes de comandos CLI
│   ├── gates.spec.ts         # Testes de gates
│   ├── lessons.spec.ts       # Testes de lições
│   ├── debug.spec.ts         # Testes de debug
│   └── modes-classic-auto.spec.ts  # CLASSIC vs AUTO, prd.json, loop-auto
├── tests-vscode/            # Testes para VS Code Extension
│   ├── extension.spec.ts     # Testes de extensão
│   └── recorder.spec.ts      # Testes de gravação
├── docs/                    # Documentação
│   ├── PLAYWRIGHT_CLI.md    # Guia Playwright CLI
│   ├── PLAYWRIGHT_VSCODE.md # Guia VS Code Extension
│   └── COMPARISON.md        # Comparação
└── reports/                 # Relatórios de testes
```

## Quick Start

### Pré-requisitos

- Node.js 18+
- npm ou yarn
- DEVORQ instalado

### Instalação

```bash
cd e2e-tests
npm install
npx playwright install chromium
```

### Executar Testes

```bash
# Todos os testes
npm test

# Testes específicos
npm test -- --grep "devorq version"

# Modo UI
npm test -- --ui

# Modo headed (ver browser)
npm test -- --headed
```

## Testes Disponíveis

### CLI Tests (`devorq-cli.spec.ts`)

- `devorq version` - Verifica versão
- `devorq --help` - Verifica help
- `devorq init` - Inicialização de projeto
- `devorq test` - Teste de estrutura

### Gates Tests (`gates.spec.ts`)

- GATE-0: Exploration
- GATE-0.5: Project Foundation
- GATE-1: Spec Exists
- GATE-2: Tests Pass
- GATE-3: Context Documented
- GATE-4: Lessons Reviewed
- GATE-5: Handoff Ready
- GATE-6: Context7 Checked
- GATE-7: Systematic Debug

### Lessons Tests (`lessons.spec.ts`)

- Capture lesson
- Search lessons
- Validate lesson
- Approve lesson
- Compile lesson

### Flow Tests (`flows.spec.ts`)

- Fluxo completo init → flow → sync
- Fluxo AUTO mode
- Fluxo CLASSIC mode

## Playwright Extension vs CLI

### Playwright CLI (Node.js)

```bash
# Instalar
npm install @playwright/test

# Executar
npx playwright test

# Gerar relatório
npx playwright show-report
```

**Características:**
- Código TypeScript/JavaScript
- Integração CI/CD
- Relatórios detalhados
- Screenshots/Videos

### Playwright Extension (VS Code)

1. Instale "Playwright Test for VSCode" no VS Code
2. Abra o projeto
3. Use Test Explorer para executar testes

**Características:**
- Gravar testes automaticamente
- Interface visual
- Debug integrado
- Zero config

## Diferenças Principais

| Aspecto | CLI | Extension |
|---------|-----|-----------|
| Setup | Manual | Automático |
| Record | Não | Sim |
| CI/CD | Sim | Não |
| Debug | Bom | Excelente |
| Flexibilidade | Alta | Média |

## Scripts

```json
{
  "scripts": {
    "test": "playwright test",
    "test:headed": "playwright test --headed",
    "test:ui": "playwright test --ui",
    "test:debug": "playwright test --debug",
    "report": "playwright show-report",
    "install": "playwright install chromium",
    "codegen": "playwright codegen"
  }
}
```

## Troubleshooting

### Chromium não instalado

```bash
npx playwright install chromium
```

### Testes falhando

```bash
# Ver screenshots
ls test-results/

# Ver logs
cat playwright.log
```

### Resetar ambiente

```bash
rm -rf test-results/
rm -rf playwright-report/
npx playwright test --project=chromium --reporter=list
```

---

**Versão:** 1.0.0
**Autor:** DEVORQ Team
**Data:** 2026-05-11
