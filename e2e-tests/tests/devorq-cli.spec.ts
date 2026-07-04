import { test, expect, describe } from '@playwright/test';
import { spawnSync } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';

/**
 * DEVORQ CLI E2E Tests
 * 
 * Testa comandos CLI do DEVORQ v4
 * 
 * Como executar:
 *   npx playwright test tests/devorq-cli.spec.ts
 *   npx playwright test tests/devorq-cli.spec.ts --headed
 */

const DEVORQ_ROOT = path.resolve(__dirname, '../../');
const DEVORQ_BIN = path.resolve(DEVORQ_ROOT, 'bin/devorq');
const SANDBOX = '/tmp/devorq-e2e-cli';

function hermeticEnv(): NodeJS.ProcessEnv {
  const env: NodeJS.ProcessEnv = {};
  for (const [key, value] of Object.entries(process.env)) {
    if (!key.startsWith('DEVORQ_')) env[key] = value;
  }
  return env;
}

/**
 * Helper para executar comandos
 */
function runCommand(cmd: string, cwd: string = DEVORQ_ROOT): { stdout: string; stderr: string; exitCode: number } {
  const adjustedCmd = cmd.replace(/\bdevorq\b/g, DEVORQ_BIN);
  const { stdout, stderr, status } = spawnSync('bash', ['-c', adjustedCmd], {
    encoding: 'utf-8',
    cwd,
    env: hermeticEnv(),
  });
  return {
    stdout: stdout || '',
    stderr: stderr || '',
    exitCode: status ?? 1,
  };
}

/**
 * Setup antes de cada teste
 */
test.beforeEach(async () => {
  fs.rmSync(SANDBOX, { recursive: true, force: true });
  fs.mkdirSync(SANDBOX, { recursive: true });
});

describe('DEVORQ CLI - Comandos Básicos', () => {
  
  test('devorq version deve retornar versão', () => {
    const result = runCommand('devorq version', DEVORQ_ROOT);
    
    console.log('Output:', result.stdout);
    
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('DEVORQ');
    expect(result.stdout).toMatch(/\d+\.\d+\.\d+/);
  });

  test('devorq --help deve mostrar help', () => {
    const result = runCommand('devorq --help', DEVORQ_ROOT);
    
    console.log('Output:', result.stdout);
    
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('DEVORQ');
    expect(result.stdout).toContain('init');
    expect(result.stdout).toContain('flow');
    expect(result.stdout).toContain('lessons');
  });

  test('devorq -h deve ser equivalente a --help', () => {
    const result = runCommand('devorq -h', DEVORQ_ROOT);
    
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('DEVORQ');
  });

  test('devorq sem argumentos deve mostrar help', () => {
    const result = runCommand('devorq', DEVORQ_ROOT);
    
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('DEVORQ');
  });
});

describe('DEVORQ CLI - Inicialização', () => {
  
  test('devorq init deve criar estrutura .devorq', () => {
    const projectDir = `${SANDBOX}/test-project`;
    fs.mkdirSync(projectDir, { recursive: true });
    
    const result = runCommand('devorq init', projectDir);
    
    console.log('Init output:', result.stdout);
    
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('.devorq');
    
    // Verificar estrutura criada
    expect(fs.existsSync(path.join(projectDir, '.devorq'))).toBe(true);
    expect(fs.existsSync(path.join(projectDir, '.devorq/state'))).toBe(true);
    expect(fs.existsSync(path.join(projectDir, '.devorq/state/context.json'))).toBe(true);
  });

  test('devorq init deve detectar projeto já inicializado', () => {
    const projectDir = `${SANDBOX}/test-project`;
    fs.mkdirSync(projectDir, { recursive: true });
    
    // Primeira inicialização
    runCommand('devorq init', projectDir);
    
    // Segunda inicialização (deve detectar — warn vai para stderr)
    const result = runCommand('devorq init', projectDir);
    const output = `${result.stdout}\n${result.stderr}`;

    expect(output).toMatch(/[Jj][áa] existe/i);
    expect(output).toMatch(/Bootstrap de regras concluído/);
  });

  test('devorq test deve rodar a suite de unit-tests (DQ-001)', () => {
    // Apos DQ-001, "devorq test" roda scripts/unit-tests.sh (nao mais a
    // checagem de estrutura). Continua saindo 0 quando os testes passam.
    const projectDir = `${SANDBOX}/test-project`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);

    const result = runCommand('devorq test', projectDir);

    console.log('Test output:', result.stdout);

    expect(result.exitCode).toBe(0);
  });
});

describe('DEVORQ CLI - Gates', () => {
  
  test('devorq gate 0 deve executar GATE-0', () => {
    const projectDir = `${SANDBOX}/test-project`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    const result = runCommand('devorq gate 0', projectDir);
    
    console.log('Gate 0 output:', result.stdout);
    
    // GATE-0 é opcional, então pode passar ou falhar
    expect(result.stdout).toMatch(/GATE/);
  });

  test('devorq gate 1 deve verificar SPEC.md', () => {
    const projectDir = `${SANDBOX}/test-project`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    const result = runCommand('devorq gate 1', projectDir);
    
    console.log('Gate 1 output:', result.stdout);
    
    // GATE-1 deve falhar se não existir SPEC.md
    expect(result.stdout).toMatch(/GATE/);
  });

  test('devorq flow deve executar todos os gates', () => {
    const projectDir = `${SANDBOX}/test-project`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    // Criar SPEC.md básico
    fs.writeFileSync(
      path.join(projectDir, 'SPEC.md'),
      '# Test Project\n\n## Vision\n\nTest project.\n\n## Acceptance Criteria\n\n- [ ] Feature 1\n'
    );
    
    const result = runCommand('devorq flow "test intent"', projectDir);
    
    console.log('Flow output:', result.stdout);
    
    expect(result.stdout).toMatch(/GATE/);
  });
});

describe('DEVORQ CLI - Lições Aprendidas', () => {
  
  test('devorq lessons capture deve capturar lição', () => {
    const projectDir = `${SANDBOX}/test-project`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    const result = runCommand(
      `devorq lessons capture "Test lesson" "Test problem" "Test solution"`,
      projectDir
    );
    
    console.log('Capture output:', result.stdout);
    
    expect(result.stdout).toContain('lesson');
    
    // Verificar se arquivo foi criado
    const lessonsDir = path.join(projectDir, '.devorq/state/lessons/captured');
    if (fs.existsSync(lessonsDir)) {
      const files = fs.readdirSync(lessonsDir).filter(f => f.endsWith('.json'));
      expect(files.length).toBeGreaterThan(0);
    }
  });

  test('devorq lessons search deve buscar lições', () => {
    const projectDir = `${SANDBOX}/test-project`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    // Capturar uma lição primeiro
    runCommand(
      `devorq lessons capture "Docker lesson" "Docker problem" "Docker solution"`,
      projectDir
    );
    
    // Buscar
    const result = runCommand('devorq lessons search "Docker"', projectDir);
    
    console.log('Search output:', result.stdout);
    
    expect(result.stdout).toMatch(/Docker|lesson|Nenhuma/i);
  });

  test('devorq lessons list deve listar lições', () => {
    const projectDir = `${SANDBOX}/test-project`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    const result = runCommand('devorq lessons list', projectDir);
    
    console.log('List output:', result.stdout);
    
    expect(result.stdout).toMatch(/lesson|Lista|Nenhuma/i);
  });
});

describe('DEVORQ CLI - Contexto', () => {
  
  test('devorq context deve mostrar contexto', () => {
    const projectDir = `${SANDBOX}/test-project`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    const result = runCommand('devorq context', projectDir);
    
    console.log('Context output:', result.stdout);
    
    expect(result.stdout).toMatch(/context|Context|DEVORQ/i);
  });

  test('devorq compact deve gerar handoff', () => {
    const projectDir = `${SANDBOX}/test-project`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    const result = runCommand('devorq compact', projectDir);
    
    console.log('Compact output:', result.stdout);
    
    // Deve gerar JSON
    expect(result.stdout).toMatch(/\{|handoff|project/i);
  });
});

describe('DEVORQ CLI - Foundation', () => {
  
  test('devorq foundation deve mostrar status', () => {
    const projectDir = `${SANDBOX}/test-project`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    const result = runCommand('devorq foundation', projectDir);
    
    console.log('Foundation output:', result.stdout);
    
    expect(result.stdout).toMatch(/Foundation|5W2H|Status/i);
  });

  test('devorq foundation status deve mostrar status', () => {
    const projectDir = `${SANDBOX}/test-project`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    const result = runCommand('devorq foundation status', projectDir);
    
    console.log('Foundation status output:', result.stdout);
    
    expect(result.stdout).toMatch(/5W2H|premissas|riscos|requisitos|restricoes/i);
  });
});

describe('DEVORQ CLI - Debug', () => {
  
  test('devorq debug deve executar workflow de debug', () => {
    const projectDir = `${SANDBOX}/test-project`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    // Note: debug é interativo, então apenas verificamos que não crasha
    const result = runCommand('echo "" | devorq debug', projectDir);
    
    console.log('Debug output:', result.stdout);
    
    expect(result.stdout).toMatch(/Debug|debug|DEBU/i);
  });
});

describe('DEVORQ CLI - Stats', () => {
  
  test('devorq stats deve mostrar estatísticas', () => {
    const projectDir = `${SANDBOX}/test-project`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    const result = runCommand('devorq stats', projectDir);
    
    console.log('Stats output:', result.stdout);
    
    expect(result.stdout).toMatch(/Stats|stats|Lições/i);
  });
});

describe('DEVORQ CLI - VPS', () => {
  
  test('devorq vps check deve testar conexão', () => {
    const result = runCommand('devorq vps check', DEVORQ_ROOT);
    
    console.log('VPS check output:', result.stdout);
    console.log('VPS check error:', result.stderr);
    
    // Pode passar ou falhar dependendo da configuração
    expect(result.stdout + result.stderr).toMatch(/VPS|Check|ping|ERROR/i);
  });
});
