# E2E Tests - Guia Rápido de Uso

## Como Executar os Testes

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

# Modo visual (ver browser)
npm test -- --headed

# Modo UI
npm test -- --ui

# Apenas um arquivo
npm test -- tests/devorq-cli.spec.ts

# Apenas testes com "version" no nome
npm test -- --grep "version"

# Debug
npm test -- --debug
```

## Estrutura de Testes

```
tests/
├── devorq-cli.spec.ts    # Comandos CLI básicos
├── gates.spec.ts         # Testes de gates
├── lessons.spec.ts       # Testes de lições
└── context.spec.ts       # Testes de contexto
```

## Cenários de Teste

### 1. Testar Comandos Básicos

```bash
npm test -- tests/devorq-cli.spec.ts --grep "version"
```

### 2. Testar Gates

```bash
npm test -- tests/gates.spec.ts
```

### 3. Testar Lições

```bash
npm test -- tests/lessons.spec.ts
```

### 4. Todos os Testes

```bash
npm test
```

## Ver Resultados

```bash
# Abrir relatório HTML
npm run report
```

## Troubleshooting

### Erro: Cannot find module

```bash
npm install
```

### Erro: Chromium not found

```bash
npx playwright install chromium
```

### Testes falhando

```bash
# Ver screenshots
ls test-results/

# Modo headed
npm test -- --headed
```

---

## Playwright Extension vs CLI

### Como Usar Extension

1. Abra o VS Code na pasta `e2e-tests`
2. Instale a extensão "Playwright Test for VSCode"
3. Veja os testes no Test Explorer
4. Clique ▶️ para executar

### Como Usar CLI

```bash
cd e2e-tests
npm test
```

---

**Para mais detalhes, consulte:**
- `docs/PLAYWRIGHT_COMPARISON.md`
- `docs/PLAYWRIGHT_EXTENSION_VS_CLI.md`
