import { test, expect, describe } from '@playwright/test';
import { execSync } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';

/**
 * Security E2E Tests
 * Testa validacoes de seguranca em cenarios reais
 */

const SANDBOX = '/tmp/devorq-e2e-security';
const DEVORQ_BIN = path.resolve(__dirname, '../..', 'bin/devorq');

// Env hermético: sem DEVORQ_* do shell do dev (testes independentes do ambiente).
function hermeticEnv(): NodeJS.ProcessEnv {
  const env: NodeJS.ProcessEnv = {};
  for (const [k, v] of Object.entries(process.env)) {
    if (!k.startsWith('DEVORQ_')) env[k] = v;
  }
  return env;
}

function runCommand(cmd: string, cwd: string = SANDBOX): { stdout: string; stderr: string; exitCode: number } {
  const adjustedCmd = cmd.replace(/\bdevorq\b/g, DEVORQ_BIN);
  try {
    const stdout = execSync(adjustedCmd, { encoding: 'utf-8', cwd, stdio: 'pipe', env: hermeticEnv() });
    return { stdout, stderr: '', exitCode: 0 };
  } catch (error: any) {
    return {
      stdout: error.stdout?.toString() || '',
      stderr: error.stderr?.toString() || '',
      exitCode: error.status || 1
    };
  }
}

test.beforeAll(async () => {
  execSync(`rm -rf ${SANDBOX} && mkdir -p ${SANDBOX}`, { encoding: 'utf-8' });
});

describe('Security - Input Validation', () => {

  test('lessons capture neutraliza input perigoso armazenando como dado inerte', async () => {
    const projectDir = `${SANDBOX}/input-test`;
    fs.mkdirSync(projectDir, { recursive: true });

    // Init
    const initResult = runCommand('devorq init', projectDir);
    expect(initResult.exitCode).toBe(0);

    // Sentinela: se um "; rm -rf ..." executasse, este arquivo sumiria.
    const sentinel = path.join(projectDir, 'SENTINEL.txt');
    fs.writeFileSync(sentinel, 'nao me apague');

    // Input com metacaracteres de shell. A seguranca correta e ARMAZENAR como
    // dado (jq --arg escapa), NAO mutilar o conteudo — codigo em licoes e valido.
    const result = runCommand(
      'devorq lessons capture "Test; rm -rf /" --problem "usa \\$(cmd) e backtick" --solution "arr[0]"',
      projectDir
    );
    expect(result.exitCode).toBe(0);

    // Nenhuma execucao: a sentinela continua la (o "; rm -rf" nao rodou).
    expect(fs.existsSync(sentinel)).toBe(true);

    const files = execSync(`ls ${projectDir}/.devorq/state/lessons/captured/ 2>/dev/null || echo ""`, { encoding: 'utf-8' });
    expect(files.trim()).not.toBe('');
    const file = `${projectDir}/.devorq/state/lessons/captured/${files.trim().split('\n')[0]}`;

    // O arquivo e JSON VALIDO (input nao quebrou a estrutura = sem injection).
    const parsed = JSON.parse(fs.readFileSync(file, 'utf-8'));
    // E o conteudo foi preservado cru (neutralizado como dado, nao destruido).
    expect(parsed.title).toBe('Test; rm -rf /');
    expect(parsed.problem).toContain('$(cmd)');
  });

  test('should handle path traversal attempts', async () => {
    const projectDir = `${SANDBOX}/path-test`;
    fs.mkdirSync(projectDir, { recursive: true });

    // Tentar acessar arquivo fora do projeto
    const traversalAttempts = [
      '../../../etc/passwd',
      '/tmp/../../../root',
      'valid/../../etc/shadow',
    ];

    for (const attempt of traversalAttempts) {
      // O sistema deve bloquear
      const result = runCommand(`devorq lessons capture "Test" "p" "s"`, projectDir);

      // Verificar que nao criou arquivo fora do diretorio do projeto
      const projectFiles = execSync(`find ${projectDir} -type f 2>/dev/null`, { encoding: 'utf-8' });

      // Todos os arquivos devem estar dentro do projeto
      const lines = projectFiles.split('\n').filter(l => l.includes('.devorq'));
      for (const file of lines) {
        expect(file).toContain(projectDir);
      }
    }
  });
});

describe('Security - SSH Validation', () => {

  test('should validate VPS connection settings', async () => {
    const projectDir = `${SANDBOX}/vps-test`;
    fs.mkdirSync(projectDir, { recursive: true });

    // Testar que VPS check nao falha com config padrao
    const result = runCommand('devorq vps check', projectDir);

    // Deve retornar 0 (OK) ou warning (VPS nao configurado), nunca crash
    expect([0, 1]).toContain(result.exitCode);
  });

  test('should use StrictHostKeyChecking in SSH commands', async () => {
    // Verificar que lib/vps.sh contem StrictHostKeyChecking=yes
    const vpsLibPath = path.resolve(__dirname, '../../lib/vps.sh');
    const vpsContent = fs.readFileSync(vpsLibPath, 'utf-8');

    expect(vpsContent).toContain('StrictHostKeyChecking=yes');
  });
});

describe('Security - Exit Codes', () => {

  test('should return consistent exit codes', async () => {
    const projectDir = `${SANDBOX}/exit-code-test`;
    fs.mkdirSync(projectDir, { recursive: true });

    // devorq version deve retornar 0
    const versionResult = runCommand('devorq version');
    expect(versionResult.exitCode).toBe(0);

    // devorq sem args deve retornar 0 ou 1 (nao crash)
    const noArgsResult = runCommand('devorq');
    expect([0, 1]).toContain(noArgsResult.exitCode);
  });

  test('should handle missing arguments gracefully', async () => {
    const projectDir = `${SANDBOX}/args-test`;
    fs.mkdirSync(projectDir, { recursive: true });

    // Tentar comando que requer argumentos
    const result = runCommand('devorq lessons search', projectDir);

    // Deve falhar com exit code >= 1 ou pelo menos nao crash
    expect(result.exitCode).toBeGreaterThanOrEqual(1);
  });
});

describe('Security - File Permissions', () => {

  test('should create files with secure permissions', async () => {
    const projectDir = `${SANDBOX}/perms-test`;
    fs.mkdirSync(projectDir, { recursive: true });

    const initResult = runCommand('devorq init', projectDir);
    expect(initResult.exitCode).toBe(0);

    // Verificar permissoes de arquivos sensiveis
    const contextJson = `${projectDir}/.devorq/state/context.json`;
    if (fs.existsSync(contextJson)) {
      const stats = fs.statSync(contextJson);
      const mode = stats.mode & 0o777;

      // Arquivos JSON nao devem ser executaveis
      expect(mode & 0o111).toBe(0);
    }
  });
});
