import { test, expect, describe } from '@playwright/test';
import { execSync } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';

/**
 * DEVORQ Gates E2E Tests
 * 
 * Testa todos os gates do sistema DEVORQ v3
 */

const SANDBOX = '/tmp/devorq-e2e-gates';
const DEVORQ_BIN = path.resolve(__dirname, '../..', 'bin/devorq');

// Env hermético: remove DEVORQ_* do ambiente para os testes não herdarem
// configuração do shell do dev (ex: DEVORQ_ALLOW_NO_RUNNER, DEVORQ_INTENT).
function hermeticEnv(): NodeJS.ProcessEnv {
  const env: NodeJS.ProcessEnv = {};
  for (const [k, v] of Object.entries(process.env)) {
    if (!k.startsWith('DEVORQ_')) env[k] = v;
  }
  return env;
}

function runCommand(cmd: string, cwd: string = SANDBOX): { stdout: string; stderr: string; exitCode: number } {
  // Substitui 'devorq' pelo caminho completo do projeto
  const adjustedCmd = cmd.replace(/\bdevorq\b/g, DEVORQ_BIN);

  try {
    const stdout = execSync(adjustedCmd, { encoding: 'utf-8', cwd, env: hermeticEnv() });
    return { stdout, stderr: '', exitCode: 0 };
  } catch (error: any) {
    return {
      stdout: error.stdout?.toString() || '',
      stderr: error.stderr?.toString() || '',
      exitCode: error.status || 1
    };
  }
}

test.beforeEach(async () => {
  execSync(`cd /tmp && rm -rf ${SANDBOX} && mkdir -p ${SANDBOX}`, { encoding: 'utf-8' });
});

describe('GATE-0: Exploration', () => {
  
  test('GATE-0 deve executar com intent DDD', () => {
    const projectDir = `${SANDBOX}/ddd-project`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    // Criar SPEC.md com keywords DDD
    fs.writeFileSync(
      path.join(projectDir, 'SPEC.md'),
      '# Domain Project\n\n## Vision\nDDD domain model.\n\n## Acceptance Criteria\n\n### AC-1: Domain Model\n\nGiven a user is logged in\nWhen they access the domain\nThen they see the model\n'
    );
    
    const result = runCommand('devorq gate 0', projectDir);
    
    console.log('GATE-0 DDD output:', result.stdout);
    
    expect(result.stdout).toMatch(/GATE.*0/i);
  });

  test('GATE-0 deve detectar env-context', () => {
    const projectDir = `${SANDBOX}/env-project`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    const result = runCommand('devorq gate 0', projectDir);
    
    console.log('GATE-0 env output:', result.stdout);
    
    expect(result.stdout).toMatch(/GATE/i);
  });
});

describe('GATE-0.5: Project Foundation', () => {
  
  test('GATE-0.5 deve validar foundation docs', () => {
    const projectDir = `${SANDBOX}/foundation-project`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    // Criar foundation docs básicos
    fs.writeFileSync(
      path.join(projectDir, '.devorq/state/5w2h.json'),
      JSON.stringify({ project: 'test', what: 'test', why: 'test' }, null, 2)
    );
    
    fs.writeFileSync(
      path.join(projectDir, '.devorq/state/premissas.json'),
      JSON.stringify({ project: 'test', premissas: [] }, null, 2)
    );
    
    fs.writeFileSync(
      path.join(projectDir, '.devorq/state/riscos.json'),
      JSON.stringify({ project: 'test', riscos: [] }, null, 2)
    );
    
    fs.writeFileSync(
      path.join(projectDir, '.devorq/state/requisitos.json'),
      JSON.stringify({ project: 'test', requisitos: [] }, null, 2)
    );
    
    fs.writeFileSync(
      path.join(projectDir, '.devorq/state/restricoes.json'),
      JSON.stringify({ project: 'test', restricoes: [] }, null, 2)
    );
    
    const result = runCommand('devorq gate 0.5', projectDir);
    
    console.log('GATE-0.5 output:', result.stdout);
    
    expect(result.stdout).toMatch(/GATE.*0\.5|Foundation/i);
  });
});

describe('GATE-1: Spec Exists', () => {
  
  test('GATE-1 deve falhar sem SPEC.md', () => {
    const projectDir = `${SANDBOX}/no-spec`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    const result = runCommand('devorq gate 1', projectDir);

    console.log('GATE-1 no-spec output:', result.stdout);

    expect(result.stdout).toMatch(/GATE.*1|FAIL|SPEC.*not.*found/i);
    // gate bloqueante: sem SPEC.md o exit DEVE ser != 0 (semantica de bloqueio)
    expect(result.exitCode).not.toBe(0);
  });

  test('GATE-1 deve passar com SPEC.md válido', () => {
    const projectDir = `${SANDBOX}/with-spec`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    // SPEC.md >= 100 bytes (gate_1 exige conteudo minimo); antes o fixture tinha
    // ~70 bytes e o gate FALHAVA, mas o teso so olhava stdout e passava falso.
    fs.writeFileSync(
      path.join(projectDir, 'SPEC.md'),
      '# Test Project\n\n## Vision\nProjeto de teste para validar o GATE-1 com conteudo suficiente.\n\n## Acceptance Criteria\n\n- [ ] Feature 1 implementada e testada\n'
    );

    const result = runCommand('devorq gate 1', projectDir);

    console.log('GATE-1 with-spec output:', result.stdout);

    expect(result.stdout).toMatch(/GATE.*1|PASS/i);
    // gate deve PASSAR: exit 0 com SPEC valido
    expect(result.exitCode).toBe(0);
  });

  test('GATE-1 deve falhar com SPEC.md vazio', () => {
    const projectDir = `${SANDBOX}/empty-spec`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    fs.writeFileSync(path.join(projectDir, 'SPEC.md'), '');
    
    const result = runCommand('devorq gate 1', projectDir);
    
    console.log('GATE-1 empty-spec output:', result.stdout);

    expect(result.stdout).toMatch(/GATE.*1|FAIL|empty/i);
    // SPEC.md vazio: gate bloqueante deve falhar com exit != 0
    expect(result.exitCode).not.toBe(0);
  });
});

describe('GATE-2: Tests Pass', () => {
  
  test('GATE-2 deve verificar estrutura', () => {
    const projectDir = `${SANDBOX}/test-project`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    fs.writeFileSync(path.join(projectDir, 'SPEC.md'), '# Test\n\n## AC\n- [ ] Test\n');
    
    const result = runCommand('devorq gate 2', projectDir);
    
    console.log('GATE-2 output:', result.stdout);
    
    expect(result.stdout).toMatch(/GATE.*2/i);
  });
});

describe('GATE-3: Context Documented', () => {
  
  test('GATE-3 deve criar context.json', () => {
    const projectDir = `${SANDBOX}/context-project`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    const result = runCommand('devorq gate 3', projectDir);
    
    console.log('GATE-3 output:', result.stdout);
    
    // Verificar que context.json foi criado/atualizado
    const contextFile = path.join(projectDir, '.devorq/state/context.json');
    expect(fs.existsSync(contextFile)).toBe(true);
  });

  test('GATE-3 deve validar context.json existente', () => {
    const projectDir = `${SANDBOX}/context-valid`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    // Criar context.json válido
    fs.writeFileSync(
      path.join(projectDir, '.devorq/state/context.json'),
      JSON.stringify({
        project: 'test',
        intent: 'testing',
        stack: ['bash']
      }, null, 2)
    );
    
    const result = runCommand('devorq gate 3', projectDir);
    
    console.log('GATE-3 valid output:', result.stdout);
    
    expect(result.stdout).toMatch(/GATE.*3/i);
  });
});

describe('GATE-4: Lessons Reviewed', () => {
  
  test('GATE-4 deve passar sem lições (aviso)', () => {
    const projectDir = `${SANDBOX}/no-lessons`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    const result = runCommand('devorq gate 4', projectDir);
    
    console.log('GATE-4 no-lessons output:', result.stdout);
    
    expect(result.stdout).toMatch(/GATE.*4/i);
  });

  test('GATE-4 deve passar com lições', () => {
    const projectDir = `${SANDBOX}/with-lessons`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    // Capturar lição
    runCommand(
      'devorq lessons capture "Test" "Problem" "Solution"',
      projectDir
    );
    
    const result = runCommand('devorq gate 4', projectDir);
    
    console.log('GATE-4 with-lessons output:', result.stdout);
    
    expect(result.stdout).toMatch(/GATE.*4/i);
  });
});

describe('GATE-5: Handoff Ready', () => {
  
  test('GATE-5 deve gerar JSON válido', () => {
    const projectDir = `${SANDBOX}/handoff-project`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    const result = runCommand('devorq gate 5', projectDir);
    
    console.log('GATE-5 output:', result.stdout);
    
    expect(result.stdout).toMatch(/GATE.*5/i);
    
    // Verificar que handoff.json foi criado
    const handoffFile = path.join(projectDir, '.devorq/state/handoff.json');
    if (fs.existsSync(handoffFile)) {
      const content = fs.readFileSync(handoffFile, 'utf-8');
      expect(content).toMatch(/\{/);
    }
  });
});

describe('GATE-6: Context7 Checked', () => {
  
  test('GATE-6 deve verificar Context7 (aviso)', () => {
    const projectDir = `${SANDBOX}/context7-project`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    const result = runCommand('devorq gate 6', projectDir);
    
    console.log('GATE-6 output:', result.stdout);
    
    // GATE-6 nunca bloqueia
    expect(result.stdout).toMatch(/GATE.*6/i);
  });
});

describe('GATE-7: Systematic Debug', () => {
  
  test('GATE-7 deve verificar estado', () => {
    const projectDir = `${SANDBOX}/debug-project`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    const result = runCommand('devorq gate 7', projectDir);
    
    console.log('GATE-7 output:', result.stdout);
    
    expect(result.stdout).toMatch(/GATE.*7|Debug/i);
  });
});

describe('Fluxo Completo de Gates', () => {
  
  test('devorq flow deve executar todos os gates', () => {
    const projectDir = `${SANDBOX}/flow-project`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    // Criar SPEC.md
    fs.writeFileSync(
      path.join(projectDir, 'SPEC.md'),
      '# Flow Test\n\n## Vision\n\nTest.\n\n## Acceptance Criteria\n\n### AC-1\n\nGiven user is logged in\nWhen they click button\nThen action happens\n'
    );
    
    const result = runCommand('devorq flow "test intent"', projectDir);
    
    console.log('Flow output:', result.stdout);
    
    // Verificar que gates foram executados
    expect(result.stdout).toMatch(/GATE/i);
  });
});
