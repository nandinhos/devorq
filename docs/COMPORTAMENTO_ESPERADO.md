# Comportamento Esperado do Sistema DEVORQ v4.0.0

> **Data:** 2026-06-01
> **Versão:** 4.0.0
> **Status:** Documentação para Code Review

---

## 1. Visão Geral

O **DEVORQ** é um framework bash puro para metodologia de desenvolvimento sistemático que implementa:

- **Gates bloqueantes** que impedem avanço sem verificação
- **Sistema de lições aprendidas** que captura e reutiliza conhecimento
- **Handoffs consistentes** entre sessões/agentes
- **Fluxo de trabalho estruturado** com checkpoints

---

## 2. Comandos Principais

### 2.1 Comandos de Workflow

#### `devorq init`
**Comportamento esperado:**
- Cria estrutura `.devorq/` no diretório atual
- Cria subdiretórios: `state/`, `state/lessons/`, `state/lessons/captured/`, `skills/`, `rules/`
- Cria arquivos:
  - `.devorq/state/context.json` (template vazio)
  - `.devorq/state/session.json` (template vazio)
- Se existir `skills/project-foundation/scripts/foundation-init.sh`, executa para criar foundation docs
- Mostra mensagem de sucesso com caminho do `.devorq/`

**Saída esperada:**
```
[DEVORQ] Inicializado .devorq/ em /caminho/projeto
[DEVORQ] Edite .devorq/state/context.json com project, stack e intent
```

**Caso já exista:**
```
[WARN] Ja existe .devorq/ em /caminho/projeto
```
(Retorna 0, não erro)

**Testes E2E:**
```typescript
test('devorq init deve criar estrutura .devorq', async () => {
  const result = runCommand('devorq init', projectDir);
  expect(result.exitCode).toBe(0);
  expect(result.stdout).toContain('.devorq');
  expect(exists('.devorq/state/context.json')).toBe(true);
});
```

---

#### `devorq test`
**Comportamento esperado:**
- Verifica sintaxe de `bin/devorq` com `bash -n`
- Verifica sintaxe de todos os arquivos em `lib/*.sh`
- Verifica existência de arquivos críticos:
  - `lib/lessons.sh`
  - `lib/gates.sh`
  - `lib/compact.sh`
  - `lib/vps.sh`
- Retorna 0 se tudo OK, >0 se erros

**Saída esperada (sucesso):**
```
[DEVORQ] Testando estrutura...
[OK] Estrutura OK (devorq v3.6.0)
```

**Saída esperada (falha):**
```
[DEVORQ] Testando estrutura...
[WARN] lib/lessons.sh: not found
[DEVORQ] 1 erro(s) encontrado(s)
```

**Testes E2E:**
```typescript
test('devorq test deve verificar estrutura', async () => {
  const result = runCommand('devorq test', projectDir);
  expect(result.exitCode).toBe(0);
  expect(result.stdout).toContain('OK');
});
```

---

#### `devorq flow "<intent>"`
**Comportamento esperado:**
- Aceita string de intent como argumento
- Executa gates sequencialmente: 0 → 0.5 → 1 → 2 → 3 → 4 → 5 → 6 → 7
- Cada gate deve ser executado mesmo se anterior falhar (para coleta de status)
- Retorna 0 se todos passarem, >0 se algum falhar

**Saída esperada:**
```
[DEVORQ] Intent: implementar feature X
[DEVORQ] Executando gates 0 -> 0.5 -> 1-7...
[INFO] --- GATE 0 ---
[INFO] --- GATE 0.5 ---
...
[SUCCESS] Flow completo!
```

**Testes E2E:**
```typescript
test('devorq flow deve executar todos os gates', async () => {
  // Criar SPEC.md e foundation docs primeiro
  writeFile('SPEC.md', '# Test\n\n## AC\n- [ ] Test\n');
  
  const result = runCommand('devorq flow "test intent"', projectDir);
  expect(result.stdout).toContain('GATE');
  expect(result.stdout).toContain('Flow completo');
});
```

---

#### `devorq gate [0-7]`
**Comportamento esperado:**
- Executa gate específico
- Cada gate tem comportamento específico (ver seção 3)
- Retorna 0 se gate passar, >0 se falhar

**Saída esperada:**
```
[INFO] --- GATE X ---
[PASS] GATE-X: X Descricao
```

**Testes E2E:**
```typescript
test('devorq gate 0 deve executar GATE-0', async () => {
  const result = runCommand('devorq gate 0', projectDir);
  expect(result.stdout).toContain('GATE');
});
```

---

### 2.2 Comandos de Lições

#### `devorq lessons capture "<title>" "<problem>" "<solution>"`
**Comportamento esperado:**
- Aceita 3 argumentos: título, problema, solução
- Cria arquivo JSON em `.devorq/state/lessons/captured/`
- Nome do arquivo: `lesson_<timestamp>.json`
- Estrutura JSON:
```json
{
  "id": "lesson_<timestamp>",
  "title": "<title>",
  "problem": "<problem>",
  "solution": "<solution>",
  "created_at": "<ISO timestamp>",
  "validated": false,
  "approved": false,
  "compiled": false,
  "tags": []
}
```
- Retorna 0 se criado com sucesso

**Saída esperada:**
```
[✓] Lição salva: lesson_20260513_010112_222
Titulo da licao
```

**Testes E2E:**
```typescript
test('devorq lessons capture deve criar arquivo JSON', async () => {
  const result = runCommand(
    'devorq lessons capture "Docker" "Not found" "apt install"',
    projectDir
  );
  expect(result.stdout).toContain('Lição salva');
  
  const lessonsDir = '.devorq/state/lessons/captured';
  const files = readdir(lessonsDir).filter(f => f.endsWith('.json'));
  expect(files.length).toBeGreaterThan(0);
});
```

---

#### `devorq lessons list [all|pending|approved|validated|compiled]`
**Comportamento esperado:**
- Lista lições do diretório `.devorq/state/lessons/captured/`
- Filtra por status se argumento fornecido
- Mostra tabela com colunas: ID, Título, Tags, Status
- Retorna 0 sempre

**Saída esperada:**
```
[LESSONS] Total: 3 | Filtro: all

| ID                  | Título              | Tags  | Status    |
|---------------------|--------------------|-------|-----------|
| lesson_xxx          | Docker install     | docker| pending   |
| lesson_yyy          | Git merge          | git   | validated |
| lesson_zzz          | Laravel migrate    | laravel| approved  |
```

**Testes E2E:**
```typescript
test('devorq lessons list deve listar lições', async () => {
  const result = runCommand('devorq lessons list', projectDir);
  expect(result.stdout).toMatch(/LESSONS|Total:/);
});
```

---

#### `devorq lessons search "<query>"`
**Comportamento esperado:**
- Busca nos títulos e problemas das lições
- Retorna lista de matches
- Se não encontrar, retorna mensagem informativa

**Saída esperada (encontrou):**
```
[RESULTS] 2 licao(oes) encontrada(s) para "docker":

| ID                  | Título              |
|---------------------|---------------------|
| lesson_xxx          | Docker install      |
| lesson_yyy          | Docker compose      |
```

**Saída esperada (não encontrou):**
```
[INFO] Nenhuma licao encontrada para: xyz123
```

**Testes E2E:**
```typescript
test('devorq lessons search deve encontrar lição', async () => {
  runCommand('devorq lessons capture "Docker" "P" "S"', projectDir);
  
  const result = runCommand('devorq lessons search "Docker"', projectDir);
  expect(result.stdout).toMatch(/Docker|lesson/);
});
```

---

#### `devorq lessons validate [--auto]`
**Comportamento esperado:**
- Valida lições pendentes com Context7 API
- Se `--auto`, pula prompts
- Atualiza campo `validated: true` nas lições aprovadas
- Retorna 0 se validação OK

**Saída esperada:**
```
[INFO] Validando 2 licao(oes)...
[✓] lesson_xxx validada
[INFO] Validacao concluida
```

**Testes E2E:**
```typescript
test('devorq lessons validate deve validar lições', async () => {
  const result = runCommand('devorq lessons validate --auto', projectDir);
  expect(result.stdout).toMatch(/Validando|concluida/);
});
```

---

#### `devorq lessons approve <id> [--skill=<name>]`
**Comportamento esperado:**
- Aprova lição específica para virar skill
- Se `--skill=<name>`, associa a skill específica
- Atualiza campo `approved: true` e `skill_name`
- Retorna 0 se aprovada

**Saída esperada:**
```
[✓] Lição lesson_xxx aprovada
[INFO] Skill: my-skill
```

**Testes E2E:**
```typescript
test('devorq lessons approve deve aprovar lição', async () => {
  const result = runCommand('devorq lessons approve lesson_xxx --skill=test', projectDir);
  expect(result.stdout).toContain('aprovada');
});
```

---

#### `devorq lessons compile [<id>] [--dry-run]`
**Comportamento esperado:**
- Compila lição aprovada em skill
- Cria/atualiza `skills/<skill_name>/SKILL.md`
- Se `--dry-run`, mostra preview sem modificar
- Retorna 0 se compilado

**Saída esperada:**
```
[INFO] Compilando 1 licao(oes) approved...
[✓] lesson_xxx compilada
[INFO] Skill my-skill atualizada
```

**Testes E2E:**
```typescript
test('devorq lessons compile deve compilar lição', async () => {
  const result = runCommand('devorq lessons compile lesson_xxx --dry-run', projectDir);
  expect(result.stdout).toMatch(/Compilando|dry-run/);
});
```

---

### 2.3 Comandos de Contexto

#### `devorq context [lint|stats|pack|merge|set|clear]`
**Comportamento esperado:**
- Sem argumento: mostra contexto atual e estatísticas
- `lint`: valida sanidade do context.json
- `stats`: mostra tamanho em chars/tokens
- `pack`: comprime contexto
- `merge`: merge de dois contextos
- `set`: define campo específico
- `clear`: limpa contexto

**Saída esperada (sem argumento):**
```
Context Stats:
  Tamanho: 234B / ~58 tokens
  Status: Saudável
  Intent: não definido

{
  "project": "meu-projeto",
  "stack": [],
  "intent": "",
  ...
}
```

**Testes E2E:**
```typescript
test('devorq context deve mostrar contexto', async () => {
  const result = runCommand('devorq context', projectDir);
  expect(result.stdout).toMatch(/Context|context/);
});
```

---

#### `devorq compact`
**Comportamento esperado:**
- Gera JSON de handoff para próxima sessão
- Lê de `context.json` e `git status`
- Gera arquivo `handoff.json`
- Retorna JSON na saída padrão

**Saída esperada:**
```json
{
  "handoff": {
    "project": "meu-projeto",
    "stack": ["bash", "jq"],
    "intent": "implementar feature X",
    "gates_completed": [0, 1, 2],
    "pending_gates": [3, 4, 5],
    "timestamp": "2026-05-13T..."
  }
}
```

**Testes E2E:**
```typescript
test('devorq compact deve gerar handoff', async () => {
  const result = runCommand('devorq compact', projectDir);
  expect(result.stdout).toMatch(/\{|handoff/);
});
```

---

### 2.4 Comandos de Foundation

#### `devorq foundation [status|create|validate|migrate|edit]`
**Comportamento esperado:**
- `status`: mostra status dos 5 foundation docs
- `create`: wizard interativo para criar docs
- `validate`: valida todos os 5 docs
- `migrate`: migra de SPEC.md
- `edit`: abre doc específico para edição

**Saída esperada (status):**
```
[DEVORQ] Project Foundation Status

[OK] 5w2h.json
[OK] premissas.json
[WARN] riscos.json (vazio)
[OK] requisitos.json
[OK] restricoes.json

[INFO] Execute: devorq foundation validate
```

**Testes E2E:**
```typescript
test('devorq foundation status deve mostrar status', async () => {
  const result = runCommand('devorq foundation status', projectDir);
  expect(result.stdout).toMatch(/5w2h|premissas|riscos|requisitos|restricoes/);
});
```

---

### 2.5 Comandos de Exploração

#### `devorq scope validate <arquivo>`
**Comportamento esperado:**
- Valida contrato de escopo
- Retorna 0 se válido, >0 se incompleto

**Saída esperada (válido):**
```
[✓] Contrato válido
```

**Saída esperada (inválido):**
```
[FAIL] Contrato incompleto
[WARN] Seção FAZER vazia
```

---

#### `devorq scope template [laravel|filament|default]`
**Comportamento esperado:**
- Mostra template de contrato de escopo
- Tipos: laravel, filament, default
- Retorna template no stdout

**Testes E2E:**
```typescript
test('devorq scope template deve mostrar template', async () => {
  const result = runCommand('devorq scope template', projectDir);
  expect(result.stdout).toContain('CONTRATO DE ESCOPO');
});
```

---

#### `devorq ddd explore`
**Comportamento esperado:**
- Informa sobre workshop DDD
- Redireciona para skill `ddd-deep-domain`

**Saída esperada:**
```
[DEVORQ] DDD Domain Workshop
[INFO] Carregue a skill: hermes load ddd-deep-domain
```

---

#### `devorq ddd validate`
**Comportamento esperado:**
- Valida se SPEC.md tem modelo mental DDD válido
- Executa script `skills/ddd-deep-domain/scripts/ddd-validate-spec.sh`
- Retorna 0 se válido

**Saída esperada (válido):**
```
[PASS] SPEC.md tem modelo mental válido
```

**Saída esperada (inválido):**
```
[FAIL] SPEC.md não tem alma
```

**Testes E2E:**
```typescript
test('devorq ddd validate deve validar SPEC', async () => {
  const result = runCommand('devorq ddd validate', devorqRoot);
  expect(result.exitCode).toBe(0);
});
```

---

#### `devorq spec validate`
**Comportamento esperado:**
- Valida estrutura do SPEC.md
- Verifica se tem Vision, Acceptance Criteria
- Retorna 0 se válido

**Saída esperada:**
```
[INFO] SPEC.md válido
```

---

### 2.6 Comandos de VPS/HUB

#### `devorq vps check`
**Comportamento esperado:**
- Testa conexão SSH com VPS HUB
- Se VPS configurado e respondendo: mostra OK
- Se não configurado: mostra warning

**Saída esperada (configurado):**
```
[INFO] VPS: Conectando...
[✓] VPS OK (187.108.197.199:6985)
```

**Saída esperada (não configurado):**
```
[WARN] VPS não configurado
[INFO] Configure VPS_HOST, VPS_PORT, VPS_USER
```

**Testes E2E:**
```typescript
test('devorq vps check deve testar conexão', async () => {
  const result = runCommand('devorq vps check', devorqRoot);
  expect(result.stdout).toMatch(/VPS|Check|ping|ERROR/);
});
```

---

#### `devorq sync push`
**Comportamento esperado:**
- Sincroniza lições locais para HUB PostgreSQL
- Usa SSH para conectar
- Retorna 0 se OK

**Saída esperada:**
```
[INFO] Sincronizando lessons para HUB...
[✓] 3 lições sincronizadas
```

---

#### `devorq sync pull`
**Comportamento esperado:**
- Baixa lições do HUB para local
- Retorna 0 se OK

**Saída esperada:**
```
[INFO] Sincronizando lessons do HUB...
[✓] 5 lições baixadas
```

---

### 2.7 Comandos de Meta

#### `devorq version`
**Comportamento esperado:**
- Retorna versão do DEVORQ
- Formato: `DEVORQ vX.Y.Z`

**Saída esperada:**
```
DEVORQ v3.6.0
```

**Testes E2E:**
```typescript
test('devorq version deve retornar versão', async () => {
  const result = runCommand('devorq version', devorqRoot);
  expect(result.stdout).toContain('DEVORQ');
  expect(result.stdout).toMatch(/\d+\.\d+\.\d+/);
});
```

---

#### `devorq stats`
**Comportamento esperado:**
- Mostra estatísticas de uso
- Se executado no repo DEVORQ: mostra stats do framework
- Se executado em projeto: mostra stats do projeto

**Saída esperada:**
```
═══════════════════════════════════════
  DEVORQ Statistics
═══════════════════════════════════════

═══ Lições ═══
  Capturadas:   3
  Validadas:    1
  Aprovadas:   2

═══ Gates ═══
  Completados: 5/7

═══ Contexto ═══
  Tamanho:     234B / ~58 tokens
  Status:      Saudável

═══════════════════════════════════════
```

**Testes E2E:**
```typescript
test('devorq stats deve mostrar estatísticas', async () => {
  const result = runCommand('devorq stats', devorqRoot);
  expect(result.stdout).toMatch(/Stats|Lições/);
});
```

---

#### `devorq debug`
**Comportamento esperado:**
- Workflow interativo de debug sistemático
- 4 fases: Capture → Investigate → Hypothesize → Implement
- Retorna 0 se debug OK

**Saída esperada (interativo):**
```
═══════════════════════════════════════
  DEVORQ Systematic Debugging Workflow
  Regra: SEM causa raiz = SEM fix
═══════════════════════════════════════

[INFO] Erro reportado: <erro>

── Phase 1 Checklist ──
  [ ] Mensagem de erro lida com atenção? ✓
  [ ] Erro reproduzido com sucesso?      ○
  ...
```

**Testes E2E:**
```typescript
test('devorq debug deve executar workflow', async () => {
  const result = runCommand('echo "" | devorq debug', projectDir);
  expect(result.stdout).toMatch(/Debug|DEBU/);
});
```

---

## 3. Sistema de Gates

### 3.1 Gate 0: Exploration (OPCIONAL)

**Comportamento:**
- Detecta intent do usuário
- Carrega skills de exploração se aplicável:
  - `env-context`: Detecta stack/ambiente
  - `scope-guard`: Contrato de escopo
  - `ddd-deep-domain`: Exploração DDD
- Nunca bloqueia

**Saída esperada:**
```
[INFO] --- GATE 0 ---
[PASS] GATE-0: 0 GATE-0 completo (env-context: true)
```

---

### 3.2 Gate 0.5: Project Foundation (BLOQUEANTE)

**Comportamento:**
- Valida existência dos 5 foundation docs:
  - `5w2h.json`
  - `premissas.json`
  - `riscos.json`
  - `requisitos.json`
  - `restricoes.json`
- Cada doc deve ter pelo menos 1 item
- **BLOQUEANTE**: Impede avanço se inválido

**Saída esperada (inválido):**
```
[FAIL] 5w2h.json não existe
[FAIL] premissas.json não existe
[FAIL] riscos.json não existe
[FAIL] requisitos.json não existe
[FAIL] restricoes.json não existe
[FAIL] GATE-0.5: Foundation docs incompletos
```

**Saída esperada (válido):**
```
[PASS] GATE-0.5: 0.5 Project Foundation OK
```

---

### 3.3 Gate 1: Spec Exists (BLOQUEANTE)

**Comportamento:**
- Verifica se `SPEC.md` existe
- Verifica se tem conteúdo (não vazio)
- Verifica se tem Vision e Acceptance Criteria
- **BLOQUEANTE**: Impede avanço se inválido

**Saída esperada (inválido):**
```
[FAIL] GATE-1: SPEC.md não encontrado
```

**Saída esperada (válido):**
```
[PASS] GATE-1: 1 SPEC.md existe e é válido
```

---

### 3.4 Gate 2: Tests Pass (BLOQUEANTE)

**Comportamento:**
- Executa `devorq test` no projeto
- Verifica se estrutura está OK
- **BLOQUEANTE**: Impede avanço se testes falharem

**Saída esperada:**
```
[PASS] GATE-2: 2 Tests Pass OK
```

---

### 3.5 Gate 3: Context Documented (BLOQUEANTE)

**Comportamento:**
- Verifica se `context.json` existe
- Verifica se tem campos obrigatórios:
  - `project`
  - `stack`
  - `intent`
- **BLOQUEANTE**: Impede avanço se inválido

**Saída esperada (inválido):**
```
[FAIL] GATE-3: context.json inválido
```

**Saída esperada (válido):**
```
[PASS] GATE-3: 3 Context Documented
```

---

### 3.6 Gate 4: Lessons Reviewed (BLOQUEANTE)

**Comportamento:**
- Verifica se há lições capturadas
- Se não houver, apenas aviso (não bloqueia)
- Se houver, verifica se foram revisadas

**Saída esperada (sem lições):**
```
[WARN] Nenhuma lição capturada
[PASS] GATE-4: 4 Lessons Reviewed (sem lições)
```

**Saída esperada (com lições):**
```
[INFO] 3 lições capturadas
[PASS] GATE-4: 4 Lessons Reviewed
```

---

### 3.7 Gate 5: Handoff Ready (BLOQUEANTE)

**Comportamento:**
- Executa `devorq compact`
- Verifica se JSON gerado é válido
- **BLOQUEANTE**: Impede avanço se inválido

**Saída esperada:**
```
[PASS] GATE-5: 5 Handoff Ready — JSON válido gerado
```

---

### 3.8 Gate 5.5: UNIFY (AVISO)

**Comportamento:**
- Executa fase UNIFY
- Verifica se todos ACs foram implementados
- **NUNCA BLOQUEIA**: Apenas aviso

**Saída esperada:**
```
[INFO] UNIFY: Verificando ACs...
[PASS] GATE-5.5: UNIFY executado
```

---

### 3.9 Gate 6: Context7 Checked (AVISO)

**Comportamento:**
- Verifica se Context7 API está disponível
- Testa conexão
- **NUNCA BLOQUEIA**: Apenas aviso

**Saída esperada:**
```
[INFO] Context7: API disponível (method: CLI)
[PASS] GATE-6: 6 Context7 Checked
```

---

### 3.10 Gate 7: Systematic Debug (SE ERRO)

**Comportamento:**
- Verifica se há erros pendentes
- Se não houver, passa direto
- Se houver, executa workflow de debug
- **NUNCA BLOQUEIA**: Usado apenas quando há erros

**Saída esperada (sem erros):**
```
[PASS] Nenhum problema detectado — GATE-7 OK
```

---

## 4. Estrutura de Diretórios

### 4.1 Estrutura do Framework

```
devorq_v3/
├── bin/
│   └── devorq                 # CLI entry point
├── lib/
│   ├── commands/               # Módulos de comandos
│   │   ├── workflow.sh
│   │   ├── lessons.sh
│   │   ├── context.sh
│   │   ├── exploration.sh
│   │   ├── foundation.sh
│   │   ├── integration.sh
│   │   ├── utils.sh
│   │   ├── skills.sh
│   │   ├── debug.sh
│   │   └── execution.sh
│   ├── *.sh                   # Bibliotecas core
│   │   ├── gates.sh
│   │   ├── lessons.sh
│   │   ├── context.sh
│   │   ├── compact.sh
│   │   └── ...
├── skills/                    # Skills do ecossistema
│   ├── project-foundation/
│   ├── env-context/
│   ├── scope-guard/
│   └── ddd-deep-domain/
├── scripts/                   # Scripts auxiliares
│   ├── ci-test.sh
│   ├── e2e-test.sh
│   ├── sync-push.py
│   └── sync-pull.py
├── .github/
│   └── workflows/
│       └── ci.yml            # CI/CD
├── docs/                      # Documentação
├── e2e-tests/               # Testes E2E Playwright
└── .devorq/                 # Config do framework
```

### 4.2 Estrutura de Projeto (após `devorq init`)

```
meu-projeto/
├── .devorq/
│   ├── state/
│   │   ├── context.json       # Estado atual
│   │   ├── session.json      # Dados da sessão
│   │   ├── handoff.json     # Handoff
│   │   └── lessons/
│   │       └── captured/     # Lições aprendidas
│   ├── skills/               # Skills geradas
│   └── rules/                # Regras específicas
├── SPEC.md                   # Especificação
└── src/                      # Código do projeto
```

---

## 5. Códigos de Retorno

| Código | Significado |
|--------|-------------|
| 0 | Sucesso |
| 1 | Erro genérico |
| 2 | Parâmetro inválido |
| 3 | Arquivo não encontrado |
| 4 | Validação falhou |
| 5 | Permissão negada |

---

## 6. Variáveis de Ambiente

| Variável | Descrição | Obrigatório |
|----------|-----------|-------------|
| `DEVORQ_ROOT` | Caminho do framework | Não (detectado automaticamente) |
| `DEVORQ_LIB` | Caminho das libs | Não (derivado de DEVORQ_ROOT) |
| `DEVORQ_VERSION` | Versão | Não (lido de VERSION) |
| `VPS_HOST` | IP do VPS HUB | Para sync |
| `VPS_PORT` | Porta SSH do VPS | Para sync |
| `VPS_USER` | Usuário SSH | Para sync |
| `OPENAI_API_KEY` | API key para Context7 | Para validação de lições |

---

## 7. Formato de Mensagens

### 7.1 Cores (TTY)

| Cor | Código | Uso |
|-----|---------|-----|
| Verde | `\033[0;32m` | Sucesso, OK |
| Amarelo | `\033[0;33m` | Warning, Aviso |
| Vermelho | `\033[0;31m` | Erro, Fail |
| Cyan | `\033[0;36m` | Info, Headers |
| Reset | `\033[0m` | Reset de cor |

### 7.2 Prefixos

| Prefixo | Significado |
|---------|-------------|
| `[DEVORQ]` | Mensagem do sistema |
| `[INFO]` | Informação |
| `[WARN]` | Aviso/Warning |
| `[FAIL]` | Falha/Erro |
| `[✓]` | Sucesso |
| `[PASS]` | Teste passou |
| `[ERROR]` | Erro |

---

## 8. Testes de Regressão

### 8.1 Comandos Básicos
- [ ] `devorq version` retorna versão
- [ ] `devorq --help` mostra help
- [ ] `devorq init` cria estrutura
- [ ] `devorq test` verifica estrutura

### 8.2 Lições
- [ ] `devorq lessons capture` cria JSON
- [ ] `devorq lessons list` mostra lista
- [ ] `devorq lessons search` busca
- [ ] `devorq lessons validate` valida
- [ ] `devorq lessons approve` aprova
- [ ] `devorq lessons compile` compila

### 8.3 Gates
- [ ] `devorq gate 0` executa
- [ ] `devorq gate 0.5` valida foundation
- [ ] `devorq gate 1` valida SPEC
- [ ] `devorq gate 2` executa testes
- [ ] `devorq gate 3` valida contexto
- [ ] `devorq gate 4` verifica lições
- [ ] `devorq gate 5` gera handoff
- [ ] `devorq gate 6` verifica Context7
- [ ] `devorq gate 7` debug

### 8.4 Fluxo Completo
- [ ] `devorq flow` executa todos os gates
- [ ] Handoff é gerado corretamente
- [ ] Contexto é preservado

---

## 9. Casos de Borda

### 9.1 Projeto Já Inicializado
```bash
$ devorq init
[WARN] Ja existe .devorq/ em /projeto
# Retorna 0, não erro
```

### 9.2 SPEC.md Vazio
```bash
$ devorq gate 1
[FAIL] GATE-1: SPEC.md está vazio ou incompleto
# Retorna 1
```

### 9.3 Sem Lições
```bash
$ devorq lessons list
[LESSONS] Total: 0 | Filtro: all
# Não é erro, apenas informativo
```

### 9.4 VPS Não Configurado
```bash
$ devorq vps check
[WARN] VPS não configurado
[INFO] Configure VPS_HOST, VPS_PORT, VPS_USER
# Não é erro, apenas aviso
```

---

## 10. Performance

### 10.1 Tempos Esperados

| Comando | Tempo Máximo |
|---------|-------------|
| `devorq version` | < 100ms |
| `devorq --help` | < 200ms |
| `devorq init` | < 500ms |
| `devorq test` | < 1s |
| `devorq lessons list` | < 500ms |
| `devorq context` | < 300ms |
| `devorq gate 1` | < 500ms |
| `devorq flow` | < 5s (todos os gates) |

### 10.2 Limites de Memória
- Contexto: < 60KB (verde), < 120KB (amarelo), > 120KB (vermelho)
- Lições: Sem limite definido (pode crescer)

---

## 11. Compatibilidade

### 11.1 Bash
- Mínimo: Bash 4.0
- Recomendado: Bash 5.0+

### 11.2 Dependências
- `jq`: Opcional (scripts funcionam sem, mas com funcionalidades reduzidas)
- `git`: Necessário para sync
- `ssh`: Necessário para VPS
- `python3`: Necessário para scripts Python

### 11.3 Sistemas Operacionais
- Linux: ✅ Suportado
- macOS: ✅ Suportado
- Windows (WSL): ✅ Suportado
- Windows (nativo): ❌ Não suportado

---

## 12. Segurança

### 12.1 Validação de Input
- Todos os inputs são validados
- Comandos destrutivos pedem confirmação
- Sem hardcoding de credenciais

### 12.2 Permissões
- Scripts não exigem sudo
- Arquivos criados com permissões seguras (644)
- Diretórios com 755

### 12.3 Dados Sensíveis
- `OPENAI_API_KEY`: Nunca é logado ou commitado
- Credenciais VPS: Apenas em variáveis de ambiente
- Lições: Podem conter informações sensíveis (usar `.gitignore`)

---

## 13. Logging

### 13.1 Níveis de Log
- `ERROR`: Erros fatais
- `WARN`: Avisos (não bloqueiam)
- `INFO`: Informações gerais
- `DEBUG`: Logs de debug (apenas se `DEVORQ_DEBUG=1`)

### 13.2 Destinos
- STDOUT: Saída normal
- STDERR: Erros e warnings

---

## 14. Internacionalização

### 14.1 Idioma
- Padrão: Português brasileiro
- Cores: ANSI escape codes
- Datas: ISO 8601

### 14.2 Mensagens
Todas as mensagens do sistema estão em português para manter consistência com o autor.

---

## 15. Resolução de Problemas

### 15.1 Problema: "command not found"
**Solução:** Verificar se `devorq` está no PATH
```bash
which devorq
export PATH="$HOME/bin:$PATH"
```

### 15.2 Problema: "permission denied"
**Solução:** Tornar script executável
```bash
chmod +x bin/devorq
```

### 15.3 Problema: "jq not found"
**Solução:** Instalar jq (opcional) ou ignorar funcionalidades
```bash
sudo apt-get install jq  # Linux
brew install jq          # macOS
```

### 15.4 Problema: Gates não executam
**Solução:** Verificar se SPEC.md existe
```bash
ls -la SPEC.md
```

---

*Documento criado para code review - DEVORQ v3.6.0*
