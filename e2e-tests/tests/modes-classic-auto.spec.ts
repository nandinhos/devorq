import { test, expect, describe } from '@playwright/test';
import { spawnSync } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';

/**
 * E2E — consistência Modo CLASSIC (`devorq flow` / gates) vs Modo AUTO (`devorq auto` → loop-auto.sh).
 *
 * Contexto de arquitetura (o que estes testes presupõem):
 *
 * 1. **CLASSIC** — `lib/commands/workflow.sh`: `devorq::cmd_flow` itera gates `0 → 0.5 → 1 … 7`
 *    via `devorq::cmd_gate` / `lib/gates.sh`. Não usa `prd.json`.
 *
 * 2. **AUTO (CLI)** — `bin/devorq` `devorq::cmd_auto` despacha para
 *    `skills/devorq-auto/scripts/loop-auto.sh`, que lê `prd.json` (schema híbrido: `passes`/`status`,
 *    `acceptanceCriteria`/`acceptance_criteria`), delegação opcional, depois `check-story.sh`.
 *
 * 3. **Modo híbrido legado** — `lib/auto.sh` alinha predicados de `prd.json` com loop-auto; a entrada
 *    principal da CLI continua sendo `loop-auto.sh`.
 *
 * 4. **Seletor** — `devorq mode` → `skills/devorq-mode/mode-selector.sh` (classificação; não altera flow/auto).
 */

const DEVORQ_ROOT = path.resolve(__dirname, '../..');
const DEVORQ_BIN = path.join(DEVORQ_ROOT, 'bin/devorq');
const LOOP_AUTO = path.join(DEVORQ_ROOT, 'skills/devorq-auto/scripts/loop-auto.sh');
const MODE_SELECTOR = path.join(DEVORQ_ROOT, 'skills/devorq-mode/mode-selector.sh');
const SANDBOX = '/tmp/devorq-e2e-modes-sandbox';

const JQ_PENDING =
  'select((.passes != true) and (.status != "done" and .status != "complete"))';

const JQ_DONE =
  'select(.status == "done" or .status == "complete")';

const e2eEnv = {
  ...process.env,
  PATH: process.env.PATH ?? '',
  DEVORQ_ROOT,
  DEVORQ_DIR: DEVORQ_ROOT,
  // Habilita dry-run do loop-auto.sh em testes: o loop e fail-closed sem
  // DEVORQ_DELEGATE_FN (DQ-005) e check-story.sh e fail-closed sem runner
  // (DQ-005). Como o cenario do teste e parse de argumento posicional
  // (nao execucao real), sem isto o teste cai no menu interativo e quebra
  // em /dev/stdin (sem tty).
  DEVORQ_AUTO_SIMULATE: '1',
  DEVORQ_AUTO_ALLOW_NO_RUNNER: '1',
};

function copyValidFoundation(stateDir: string) {
  const ex = path.join(DEVORQ_ROOT, 'skills/project-foundation/examples');
  const pairs: [string, string][] = [
    ['5w2h-example.json', '5w2h.json'],
    ['premissas-example.json', 'premissas.json'],
    ['riscos-example.json', 'riscos.json'],
    ['requisitos-example.json', 'requisitos.json'],
    ['restricoes-example.json', 'restricoes.json'],
  ];
  for (const [src, dest] of pairs) {
    fs.copyFileSync(path.join(ex, src), path.join(stateDir, dest));
  }
}

function specMdMinimal(): string {
  return (
    '# E2E Classic Flow\n\n## Vision\n\n' +
    'This project exists only to validate `devorq flow` gate ordering in Playwright. '.repeat(5) +
    '\n\n## Acceptance Criteria\n\n' +
    '- [ ] First acceptance criterion for the sandbox project.\n' +
    '- [ ] Second criterion to keep the spec meaningful.\n'
  );
}

function runCommand(
  cmd: string,
  cwd: string = DEVORQ_ROOT,
  input?: string
): { stdout: string; stderr: string; exitCode: number } {
  const adjusted = cmd.replace(/\bdevorq\b/g, DEVORQ_BIN);
  const r = spawnSync('bash', ['-c', adjusted], {
    cwd,
    encoding: 'utf-8',
    input: input ?? undefined,
    env: e2eEnv,
  });
  return {
    stdout: r.stdout?.toString() ?? '',
    stderr: r.stderr?.toString() ?? '',
    exitCode: r.status ?? 1,
  };
}

function jqStoriesMapLength(file: string, jqExpr: string): number {
  const r = spawnSync('jq', [`.stories | map(${jqExpr}) | length`, file], {
    encoding: 'utf-8',
  });
  if (r.status !== 0) {
    throw new Error((r.stderr ?? '') + (r.stdout ?? ''));
  }
  return parseInt(String(r.stdout).trim(), 10);
}

function commitFixture(projectDir: string, files: string[]) {
  spawnSync('git', ['config', 'user.email', 'e2e@devorq.local'], { cwd: projectDir, encoding: 'utf-8' });
  spawnSync('git', ['config', 'user.name', 'DEVORQ E2E'], { cwd: projectDir, encoding: 'utf-8' });
  const add = spawnSync('git', ['add', ...files], { cwd: projectDir, encoding: 'utf-8' });
  expect(add.status, (add.stderr ?? '') + (add.stdout ?? '')).toBe(0);
  const commit = spawnSync('git', ['commit', '-m', 'test(auto): fixture auto limpa (E2E-001)'], { cwd: projectDir, encoding: 'utf-8' });
  expect(commit.status, (commit.stderr ?? '') + (commit.stdout ?? '')).toBe(0);
}

function assertGateOrder(stdout: string) {
  const labels = ['GATE-0', 'GATE-0.5', 'GATE-1', 'GATE-2', 'GATE-3', 'GATE-4', 'GATE-5', 'GATE-6', 'GATE-7'];
  let last = -1;
  for (const g of labels) {
    const idx = stdout.indexOf(g);
    expect(idx, `deve conter ${g}`).toBeGreaterThanOrEqual(0);
    expect(idx, `${g} deve aparecer depois do gate anterior`).toBeGreaterThan(last);
    last = idx;
  }
}

test.beforeEach(() => {
  fs.rmSync(SANDBOX, { recursive: true, force: true });
  fs.mkdirSync(SANDBOX, { recursive: true });
});

describe('Seletor devorq mode (CLASSIC vs AUTO)', () => {
  test('mode classic imprime MODE=CLASSIC', () => {
    const r = runCommand('devorq mode classic', DEVORQ_ROOT);
    expect(r.exitCode).toBe(0);
    expect(r.stdout + r.stderr).toContain('MODE=CLASSIC');
  });

  test('mode auto imprime MODE=AUTO', () => {
    const r = runCommand('devorq mode auto', DEVORQ_ROOT);
    expect(r.exitCode).toBe(0);
    expect(r.stdout + r.stderr).toContain('MODE=AUTO');
  });

  test('mode-selector.sh existe e aceita classic com SPEC no projeto', () => {
    const projectDir = path.join(SANDBOX, 'mode-arg');
    fs.mkdirSync(projectDir, { recursive: true });
    fs.writeFileSync(path.join(projectDir, 'SPEC.md'), specMdMinimal());
    spawnSync('git', ['init'], { cwd: projectDir, encoding: 'utf-8' });
    runCommand('devorq init', projectDir);
    expect(fs.existsSync(MODE_SELECTOR)).toBe(true);
    const r = spawnSync('bash', [MODE_SELECTOR, 'classic', projectDir], {
      cwd: DEVORQ_ROOT,
      encoding: 'utf-8',
      env: e2eEnv,
    });
    expect(r.status).toBe(0);
    expect((r.stdout ?? '') + (r.stderr ?? '')).toContain('MODE=CLASSIC');
  });
});

describe('Fluxo CLASSIC (devorq flow)', () => {
  test('flow executa gates 0 a 7 na ordem quando foundation + spec existem', () => {
    const projectDir = path.join(SANDBOX, 'classic-flow');
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);

    const state = path.join(projectDir, '.devorq/state');
    copyValidFoundation(state);

    fs.writeFileSync(path.join(projectDir, 'SPEC.md'), specMdMinimal());

    const r = runCommand('devorq flow "e2e classic"', projectDir);
    expect(r.exitCode).toBe(0);
    assertGateOrder(r.stdout + r.stderr);
    expect(r.stdout + r.stderr).toMatch(/Flow completo|completo/i);
  });
});

describe('prd.json e Modo AUTO (loop-auto)', () => {
  test('prd.json raiz: stories completadas (all done)', () => {
    const prdPath = path.join(DEVORQ_ROOT, 'prd.json');
    expect(fs.existsSync(prdPath)).toBe(true);
    const done = jqStoriesMapLength(prdPath, JQ_DONE);
    expect(done).toBeGreaterThan(0);
  });

  test('loop-auto: DIR + número como segundo token não sobrescreve o diretório', () => {
    const projectDir = path.resolve(path.join(SANDBOX, 'auto-positional'));
    fs.mkdirSync(projectDir, { recursive: true });
    spawnSync('git', ['init'], { cwd: projectDir, encoding: 'utf-8' });
    fs.writeFileSync(
      path.join(projectDir, 'SPEC.md'),
      '# P\n\n## A\n\n- [ ] x\n'
    );
    fs.writeFileSync(
      path.join(projectDir, 'prd.json'),
      JSON.stringify(
        {
          project: 'e2e',
          stories: [
            {
              id: 't-1',
              title: 'Story simples',
              description: 'Sem keywords de complexidade',
              priority: 1,
              status: 'pending',
              acceptance_criteria: ['Critério único'],
            },
          ],
        },
        null,
        2
      )
    );
    runCommand('devorq init', projectDir);
    commitFixture(projectDir, ['SPEC.md', 'prd.json']);

    const r = spawnSync('bash', [LOOP_AUTO, projectDir, '1'], {
      cwd: DEVORQ_ROOT,
      encoding: 'utf-8',
      input: '\n',
      env: e2eEnv,
    });
    const out = (r.stdout ?? '') + (r.stderr ?? '');
    expect(r.status, out).toBe(0);
    expect(out).not.toMatch(/Nao encontrei SPEC\.md.*\b1\b/);
    expect(out).toMatch(/stories pendentes|AUTO MODE (COMPLETED|FAILED|INCOMPLETE)|processadas/i);
  });

  test('devorq auto 1 não trata o número como path do projeto', () => {
    const projectDir = path.resolve(path.join(SANDBOX, 'auto-cli'));
    fs.mkdirSync(projectDir, { recursive: true });
    spawnSync('git', ['init'], { cwd: projectDir, encoding: 'utf-8' });
    fs.writeFileSync(path.join(projectDir, 'SPEC.md'), '# P\n\n## A\n\n- [ ] x\n');
    fs.writeFileSync(
      path.join(projectDir, 'prd.json'),
      JSON.stringify(
        {
          project: 'e2e',
          stories: [
            {
              id: 't-1',
              title: 'Simple',
              priority: 1,
              status: 'pending',
              acceptance_criteria: ['one'],
            },
          ],
        },
        null,
        2
      )
    );
    runCommand('devorq init', projectDir);

    const r = spawnSync('bash', ['-c', `${DEVORQ_BIN} auto 1`], {
      cwd: projectDir,
      encoding: 'utf-8',
      input: '\n',
      env: e2eEnv,
    });
    const out = (r.stdout ?? '') + (r.stderr ?? '');
    expect(out).not.toMatch(/Nao encontrei SPEC\.md.*\b1\b/);
    expect(out).toMatch(/Executando AUTO mode|stories pendentes|AUTO MODE (COMPLETED|FAILED|INCOMPLETE)|processadas/i);
  });
});

describe('prd-only: predicado de pendência', () => {
  test('uma story só com status=pending conta como 1 pendente', () => {
    const d = path.join(SANDBOX, 'prd-only');
    fs.mkdirSync(d, { recursive: true });
    spawnSync('git', ['init'], { cwd: d, encoding: 'utf-8' });
    fs.writeFileSync(path.join(d, 'SPEC.md'), '# X\n');
    fs.writeFileSync(
      path.join(d, 'prd.json'),
      JSON.stringify({ stories: [{ id: 'a', title: 't', priority: 1, status: 'pending' }] }, null, 2)
    );
    const pending = jqStoriesMapLength(path.join(d, 'prd.json'), JQ_PENDING);
    expect(pending).toBe(1);
  });
});
