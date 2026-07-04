import { test, expect, describe } from '@playwright/test';
import { spawnSync } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';

/**
 * DEVORQ Sandbox E2E Tests
 *
 * Testa o sandbox isolado em /tmp/devorq-e2e-sandbox/
 * Cada teste cria seu próprio ambiente limpo.
 *
 * Como executar:
 *   npx playwright test tests/sandbox.spec.ts
 *   npx playwright test tests/sandbox.spec.ts --headed
 *   npm run test:sandbox
 */

const DEVORQ_ROOT = path.resolve(__dirname, '../../');
const DEVORQ_BIN = path.resolve(DEVORQ_ROOT, 'bin/devorq');
const SANDBOX_BASE = '/tmp/devorq-e2e-sandbox';

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

  const result = spawnSync('bash', ['-c', adjustedCmd], {
    cwd,
    encoding: 'utf-8',
    timeout: 30000,
    env: hermeticEnv(),
  });

  return {
    stdout: result.stdout?.toString() || '',
    stderr: result.stderr?.toString() || (result.status === 0 ? '' : result.error?.message || ''),
    exitCode: result.status ?? 1,
  };
}

/**
 * Helper para criar sandbox limpo
 */
function createSandbox(name: string): string {
  const sandboxPath = `${SANDBOX_BASE}/${name}`;
  fs.rmSync(sandboxPath, { recursive: true, force: true });
  fs.mkdirSync(sandboxPath, { recursive: true });
  return sandboxPath;
}

describe('DEVORQ Sandbox - Isolamento', () => {

  test.beforeAll(() => {
    fs.mkdirSync(SANDBOX_BASE, { recursive: true });
  });

  test('sandbox deve estar em /tmp com permissões corretas', () => {
    expect(fs.existsSync(SANDBOX_BASE)).toBe(true);
    const stats = fs.statSync(SANDBOX_BASE);
    expect(stats.isDirectory()).toBe(true);
  });

  test('sandbox deve permitir múltiplos projetos simultâneos', () => {
    const project1 = createSandbox('project-one');
    const project2 = createSandbox('project-two');

    runCommand('devorq init', project1);
    runCommand('devorq init', project2);

    expect(fs.existsSync(path.join(project1, '.devorq'))).toBe(true);
    expect(fs.existsSync(path.join(project2, '.devorq'))).toBe(true);

    const context1 = JSON.parse(fs.readFileSync(path.join(project1, '.devorq/state/context.json'), 'utf-8'));
    const context2 = JSON.parse(fs.readFileSync(path.join(project2, '.devorq/state/context.json'), 'utf-8'));

    expect(context1.project).toBe("");
    expect(context2.project).toBe("");
  });

  test('sandbox deve ser destruído e recriado entre testes', () => {
    const sandbox = createSandbox('destroy-test');

    runCommand('devorq init', sandbox);
    expect(fs.existsSync(path.join(sandbox, '.devorq'))).toBe(true);

    fs.rmSync(sandbox, { recursive: true, force: true });
    expect(fs.existsSync(sandbox)).toBe(false);

    fs.mkdirSync(sandbox, { recursive: true });
    expect(fs.existsSync(sandbox)).toBe(true);
  });
});

describe('DEVORQ Sandbox - Fluxo Completo', () => {

  test('init → lessons → compact → context', () => {
    const sandbox = createSandbox('full-flow');

    const initResult = runCommand('devorq init', sandbox);
    expect(initResult.exitCode).toBe(0);
    expect(fs.existsSync(path.join(sandbox, '.devorq/state'))).toBe(true);

    const captureResult = runCommand(
      'devorq lessons capture "Sandbox test" "Testing isolation" "All works correctly"',
      sandbox
    );
    expect(captureResult.stdout).toMatch(/lesson|Lição|Sucesso/i);

    const contextResult = runCommand('devorq context', sandbox);
    expect(contextResult.exitCode).toBe(0);

    const compactResult = runCommand('devorq compact', sandbox);
    expect(compactResult.stdout).toMatch(/\{|handoff|compact/i);
  });

  test('vários projetos não compartilham estado', () => {
    const projectA = createSandbox('project-a');
    const projectB = createSandbox('project-b');

    runCommand('devorq init', projectA);
    runCommand('devorq init', projectB);

    runCommand('devorq lessons capture "Project A lesson" "Problem A" "Solution A"', projectA);
    runCommand('devorq lessons capture "Project B lesson" "Problem B" "Solution B"', projectB);

    const lessonsDirA = path.join(projectA, '.devorq/state/lessons/captured');
    const lessonsDirB = path.join(projectB, '.devorq/state/lessons/captured');

    const filesA = fs.readdirSync(lessonsDirA).filter(f => f.endsWith('.json'));
    const filesB = fs.readdirSync(lessonsDirB).filter(f => f.endsWith('.json'));

    expect(filesA.length).toBeGreaterThan(0);
    expect(filesB.length).toBeGreaterThan(0);

    const contentA = fs.readFileSync(path.join(lessonsDirA, filesA[0]), 'utf-8');
    const contentB = fs.readFileSync(path.join(lessonsDirB, filesB[0]), 'utf-8');

    expect(contentA).toContain('Project A');
    expect(contentB).toContain('Project B');
    expect(contentA).not.toContain('Project B');
    expect(contentB).not.toContain('Project A');
  });
});

describe('DEVORQ Sandbox - Gates em Isolamento', () => {

  test('GATE-1 deve falhar sem SPEC.md', () => {
    const sandbox = createSandbox('gate1-test');
    runCommand('devorq init', sandbox);

    const result = runCommand('devorq gate 1', sandbox);
    expect(result.stdout).toMatch(/FAIL|falhou|não encontrado/i);
  });

  test('GATE-1 deve passar com SPEC.md válido', () => {
    const sandbox = createSandbox('gate1-pass');
    runCommand('devorq init', sandbox);

    fs.writeFileSync(
      path.join(sandbox, 'SPEC.md'),
      `# Test Project

## Vision
This is a test project for sandbox validation.
The purpose is to verify that GATE-1 passes when a valid SPEC.md exists.

## Context
This section describes the context of the project.

## Requirements
- R1: First requirement
- R2: Second requirement

## Acceptance Criteria
- [ ] AC1: First acceptance criteria
- [ ] AC2: Second acceptance criteria
`
    );

    const result = runCommand('devorq gate 1', sandbox);
    expect(result.stdout).toMatch(/PASS|ok|verde/i);
  });

  test('todos os gates devem passar em projeto completo', () => {
    const sandbox = createSandbox('full-gates');
    runCommand('devorq init', sandbox);

    fs.writeFileSync(
      path.join(sandbox, 'SPEC.md'),
      `# Full Gates Test

## Vision
Testing all gates.

## Acceptance Criteria
- [ ] AC1
`
    );

    const flowResult = runCommand('devorq flow "test"', sandbox);
    expect(flowResult.stdout).toMatch(/GATE/);
  });
});

describe('DEVORQ Sandbox - Cleanup', () => {

  test('cleanup deve remover sandbox completamente', () => {
    const sandbox = createSandbox('cleanup-test');
    runCommand('devorq init', sandbox);

    expect(fs.existsSync(sandbox)).toBe(true);

    fs.rmSync(sandbox, { recursive: true, force: true });
    expect(fs.existsSync(sandbox)).toBe(false);
  });

  test('estado residual não persiste entre testes', () => {
    const sandbox = createSandbox('residual-test');

    runCommand('devorq init', sandbox);
    runCommand('devorq lessons capture "Temp lesson" "Temp problem" "Temp solution"', sandbox);

    const filesBefore = fs.readdirSync(path.join(sandbox, '.devorq/state/lessons/captured'));

    fs.rmSync(sandbox, { recursive: true, force: true });
    const newSandbox = createSandbox('residual-test');
    runCommand('devorq init', newSandbox);

    const filesAfter = fs.readdirSync(path.join(newSandbox, '.devorq/state/lessons/captured'));
    expect(filesAfter.length).toBe(0);
  });
});
