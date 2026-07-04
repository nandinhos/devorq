import { test, expect, describe } from '@playwright/test';
import { spawnSync } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';

/**
 * Debug Tests - Para investigar problemas
 */

const SANDBOX = '/tmp/devorq-e2e-debug';
const DEVORQ_BIN = path.resolve(__dirname, '../..', 'bin/devorq');

function hermeticEnv(): NodeJS.ProcessEnv {
  const env: NodeJS.ProcessEnv = {};
  for (const [key, value] of Object.entries(process.env)) {
    if (!key.startsWith('DEVORQ_')) env[key] = value;
  }
  return env;
}

function runCommand(cmd: string, cwd: string = SANDBOX): { stdout: string; stderr: string; exitCode: number } {
  console.log(`[DEBUG] Executing: ${cmd}`);
  console.log(`[DEBUG] Working dir: ${cwd}`);
  console.log(`[DEBUG] DEVORQ_BIN: ${DEVORQ_BIN}`);
  
  // Substitui 'devorq' pelo caminho completo do projeto
  const adjustedCmd = cmd.replace(/\bdevorq\b/g, DEVORQ_BIN);
  
  console.log(`[DEBUG] Adjusted cmd: ${adjustedCmd}`);
  
  const result = spawnSync('bash', ['-c', adjustedCmd], {
    cwd,
    encoding: 'utf-8',
    env: hermeticEnv(),
  });
  const stdout = result.stdout?.toString() || '';
  const stderr = result.stderr?.toString() || (result.status === 0 ? '' : result.error?.message || '');

  console.log(`[DEBUG] stdout: "${stdout}"`);
  console.log(`[DEBUG] stderr: "${stderr}"`);
  console.log(`[DEBUG] status: ${result.status}`);

  return {
    stdout,
    stderr,
    exitCode: result.status ?? 1,
  };
}

test.beforeAll(async () => {
  fs.rmSync(SANDBOX, { recursive: true, force: true });
  fs.mkdirSync(SANDBOX, { recursive: true });
});

describe('Debug - Devorq Binary', () => {
  
  test('verificar se devorq existe e é executável', () => {
    const devorqExists = fs.existsSync(DEVORQ_BIN);
    console.log(`[TEST] DEVORQ_BIN exists: ${devorqExists}`);
    expect(devorqExists).toBe(true);
    
    if (devorqExists) {
      const stats = fs.statSync(DEVORQ_BIN);
      console.log(`[TEST] DEVORQ_BIN size: ${stats.size}`);
      console.log(`[TEST] DEVORQ_BIN mode: ${stats.mode}`);
    }
  });

  test('devorq version deve funcionar', () => {
    const result = runCommand('devorq version', SANDBOX);
    console.log(`[TEST] version result:`, result);
    
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('DEVORQ');
  });

  test('devorq init deve criar estrutura', () => {
    const projectDir = `${SANDBOX}/init-test`;
    fs.mkdirSync(projectDir, { recursive: true });
    
    const result = runCommand('devorq init', projectDir);
    console.log(`[TEST] init result:`, result);
    
    expect(result.exitCode).toBe(0);
    expect(result.stdout).toContain('.devorq');
    
    // Verificar estrutura
    expect(fs.existsSync(path.join(projectDir, '.devorq'))).toBe(true);
    expect(fs.existsSync(path.join(projectDir, '.devorq/state'))).toBe(true);
  });

  test('devorq lessons capture deve funcionar', () => {
    const projectDir = `${SANDBOX}/capture-test`;
    fs.mkdirSync(projectDir, { recursive: true });
    
    // Init primeiro
    const initResult = runCommand('devorq init', projectDir);
    console.log(`[TEST] init for capture:`, initResult);
    expect(initResult.exitCode).toBe(0);
    
    // Capturar lição
    const captureResult = runCommand(
      'devorq lessons capture "Debug lesson" "Problem" "Solution"',
      projectDir
    );
    console.log(`[TEST] capture result:`, captureResult);
    
    // Imprimir ambos stdout e stderr
    console.log(`[TEST] capture stdout: "${captureResult.stdout}"`);
    console.log(`[TEST] capture stderr: "${captureResult.stderr}"`);
    
    // Verificar se pelo menos um contém algo
    const combined = captureResult.stdout + captureResult.stderr;
    console.log(`[TEST] combined output: "${combined}"`);
    
    expect(combined).toMatch(/lesson|Lição|saved|✓/i);
    
    // Verificar arquivo
    const lessonsDir = path.join(projectDir, '.devorq/state/lessons/captured');
    console.log(`[TEST] lessonsDir exists: ${fs.existsSync(lessonsDir)}`);
    
    if (fs.existsSync(lessonsDir)) {
      const files = fs.readdirSync(lessonsDir).filter(f => f.endsWith('.json'));
      console.log(`[TEST] lessons files:`, files);
      expect(files.length).toBeGreaterThan(0);
    }
  });
});
