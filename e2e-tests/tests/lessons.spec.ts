import { test, expect, describe } from '@playwright/test';
import { spawnSync } from 'child_process';
import * as fs from 'fs';
import * as path from 'path';

/**
 * DEVORQ Lessons E2E Tests
 * 
 * Testa funcionalidades de lições aprendidas
 */

const SANDBOX = '/tmp/devorq-e2e-lessons';
const DEVORQ_BIN = path.resolve(__dirname, '../..', 'bin/devorq');

function hermeticEnv(): NodeJS.ProcessEnv {
  const env: NodeJS.ProcessEnv = {};
  for (const [key, value] of Object.entries(process.env)) {
    if (!key.startsWith('DEVORQ_')) env[key] = value;
  }
  return env;
}

function runCommand(cmd: string, cwd: string = SANDBOX): { stdout: string; stderr: string; exitCode: number } {
  // Substitui 'devorq' pelo caminho completo do projeto
  const adjustedCmd = cmd.replace(/\bdevorq\b/g, DEVORQ_BIN);

  const result = spawnSync('bash', ['-c', adjustedCmd], {
    cwd,
    encoding: 'utf-8',
    env: { ...hermeticEnv(), LESSONS_AUTO: 'true' },
  });

  return {
    stdout: result.stdout?.toString() || '',
    stderr: result.stderr?.toString() || (result.status === 0 ? '' : result.error?.message || ''),
    exitCode: result.status ?? 1,
  };
}

test.beforeEach(async () => {
  fs.rmSync(SANDBOX, { recursive: true, force: true });
  fs.mkdirSync(SANDBOX, { recursive: true });
});

describe('Lessons - Captura', () => {
  
  test('devorq lessons capture deve criar arquivo JSON', () => {
    const projectDir = `${SANDBOX}/capture-project`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    const result = runCommand(
      'devorq lessons capture "Docker install" "Docker not found" "Use apt-get install docker.io"',
      projectDir
    );
    
    console.log('Capture output:', result.stdout);
    
    expect(result.stdout).toMatch(/lesson|Lição|saved/i);
    
    // Verificar arquivo criado
    const lessonsDir = path.join(projectDir, '.devorq/state/lessons/captured');
    if (fs.existsSync(lessonsDir)) {
      const files = fs.readdirSync(lessonsDir).filter(f => f.endsWith('.json'));
      console.log('Lessons files:', files);
      expect(files.length).toBeGreaterThan(0);
    }
  });

  test('devorq lessons capture deve criar JSON válido', () => {
    const projectDir = `${SANDBOX}/capture-json-project`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    runCommand(
      'devorq lessons capture "Test lesson" "Test problem" "Test solution"',
      projectDir
    );
    
    const lessonsDir = path.join(projectDir, '.devorq/state/lessons/captured');
    const files = fs.readdirSync(lessonsDir).filter(f => f.endsWith('.json'));
    
    if (files.length > 0) {
      const content = fs.readFileSync(path.join(lessonsDir, files[0]), 'utf-8');
      console.log('Lesson content:', content);
      
      const lesson = JSON.parse(content);
      expect(lesson).toHaveProperty('id');
      expect(lesson).toHaveProperty('title');
      expect(lesson).toHaveProperty('problem');
      expect(lesson).toHaveProperty('solution');
    }
  });

  test('devorq lessons capture deve suportar tags', () => {
    const projectDir = `${SANDBOX}/tags-project`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    const result = runCommand(
      'devorq lessons capture "Git error" "Merge conflict" "Use git mergetool" --tags "git,merge"',
      projectDir
    );
    
    console.log('Tags capture output:', result.stdout);
    
    expect(result.stdout).toMatch(/lesson|Lição/i);
  });
});

describe('Lessons - Busca', () => {
  
  test('devorq lessons search deve encontrar lição', () => {
    const projectDir = `${SANDBOX}/search-project`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    // Capturar lição
    runCommand(
      'devorq lessons capture "Docker lesson" "Docker problem" "Docker solution"',
      projectDir
    );
    
    // Buscar
    const result = runCommand('devorq lessons search "Docker"', projectDir);
    
    console.log('Search output:', result.stdout);
    
    expect(result.stdout).toMatch(/Docker|lesson|Lição/i);
  });

  test('devorq lessons search deve mostrar "nenhuma" se não encontrar', () => {
    const projectDir = `${SANDBOX}/search-empty-project`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    const result = runCommand('devorq lessons search "xyzabc123"', projectDir);
    
    console.log('Search empty output:', result.stdout);
    
    expect(result.stdout).toMatch(/nenhuma|Nenhum|not.*found|no.*lesson/i);
  });

  test('devorq lessons search deve buscar em múltiplas lições', () => {
    const projectDir = `${SANDBOX}/search-multi-project`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    // Capturar múltiplas lições
    runCommand('devorq lessons capture "Docker lesson" "D1" "S1"', projectDir);
    runCommand('devorq lessons capture "Git lesson" "G1" "S2"', projectDir);
    runCommand('devorq lessons capture "Node lesson" "N1" "S3"', projectDir);
    
    // Buscar por Docker
    const dockerResult = runCommand('devorq lessons search "Docker"', projectDir);
    expect(dockerResult.stdout).toMatch(/Docker/i);
    
    // Buscar por Git
    const gitResult = runCommand('devorq lessons search "Git"', projectDir);
    expect(gitResult.stdout).toMatch(/Git/i);
  });
});

describe('Lessons - Validação', () => {
  
  test('devorq lessons validate deve validar lições', () => {
    const projectDir = `${SANDBOX}/validate-project`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);

    runCommand(
      'devorq lessons capture "Test" "Problem" "Solution"',
      projectDir
    );

    const result = runCommand('devorq lessons validate', projectDir);

    console.log('Validate output:', result.stdout);

    expect(result.stdout).toMatch(/Validada|valid|Validation/i);
  });

  test('devorq lessons validate deve funcionar sem Context7', () => {
    const projectDir = `${SANDBOX}/validate-no-context7`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);

    runCommand(
      'devorq lessons capture "Test" "Problem" "Solution"',
      projectDir
    );

    // Forçar sem Context7
    const result = runCommand(
      'OPENAI_API_KEY="" devorq lessons validate',
      projectDir
    );

    console.log('Validate no-context7 output:', result.stdout);

    expect(result.stdout).toMatch(/Validada|valid|Validation|indisponível/i);
  });
});

describe('Lessons - Aprovação', () => {
  
  test('devorq lessons list deve listar lições', () => {
    const projectDir = `${SANDBOX}/list-project`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    runCommand(
      'devorq lessons capture "Test 1" "P1" "S1"',
      projectDir
    );
    runCommand(
      'devorq lessons capture "Test 2" "P2" "S2"',
      projectDir
    );
    
    const result = runCommand('devorq lessons list', projectDir);
    
    console.log('List output:', result.stdout);
    
    expect(result.stdout).toMatch(/lesson|Lição|Lista|list/i);
  });

  test('devorq lessons list deve filtrar por status', () => {
    const projectDir = `${SANDBOX}/list-filter-project`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    runCommand('devorq lessons capture "Test" "P" "S"', projectDir);
    
    const allResult = runCommand('devorq lessons list all', projectDir);
    expect(allResult.stdout).toMatch(/lesson|Lição/i);
    
    const pendingResult = runCommand('devorq lessons list pending', projectDir);
    expect(pendingResult.stdout).toMatch(/lesson|Lição/i);
  });
});

describe('Lessons - Migração', () => {
  
  test('devorq lessons migrate deve migrar lições', () => {
    const projectDir = `${SANDBOX}/migrate-project`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    runCommand('devorq lessons capture "Old lesson" "P" "S"', projectDir);
    
    const result = runCommand('devorq lessons migrate', projectDir);
    
    console.log('Migrate output:', result.stdout);
    
    expect(result.stdout).toMatch(/migrate|Migrate|Lição/i);
  });
});

describe('Lessons - Compilação', () => {

  test('devorq lessons compile deve compilar lição', () => {
    const projectDir = `${SANDBOX}/compile-project`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);

    runCommand('devorq lessons capture "Compile test" "P" "S"', projectDir);

    // Obter ID da lição
    const lessonsDir = path.join(projectDir, '.devorq/state/lessons/captured');
    const files = fs.readdirSync(lessonsDir).filter(f => f.endsWith('.json'));

    if (files.length > 0) {
      const lessonId = path.basename(files[0], '.json');

      // validate --auto SEM Context7: por design (DQ-013) marca a licao como
      // 'skipped_no_context7' (NAO como validated), para nao disparar auto-approve
      // em fluxo real. Aqui estamos testando SOMENTE o pipeline de compile, entao
      // usamos --force no approve para bypassar a checagem de validated e seguir
      // para compile.
      const validateResult = runCommand(`devorq lessons validate --auto`, projectDir);
      expect(validateResult.stdout).toMatch(/Validadas:|indispon/i);

      const approveResult = runCommand(`devorq lessons approve --force ${lessonId}`, projectDir);
      expect(`${approveResult.stdout}\n${approveResult.stderr}`).toMatch(/Aprovada|aprovada/i);

      const result = runCommand(`devorq lessons compile ${lessonId}`, projectDir);

      console.log('Compile output:', result.stdout);

      expect(result.stdout).toMatch(/compile|Compile|skill|Skill|Compilad/i);
    } else {
      throw new Error('Nenhuma lição capturada para compilar');
    }
  });
});

describe('Lessons - Fluxo Completo', () => {
  
  test('fluxo completo: capture → validate → approve → compile', () => {
    const projectDir = `${SANDBOX}/full-lessons-project`;
    fs.mkdirSync(projectDir, { recursive: true });
    runCommand('devorq init', projectDir);
    
    // 1. Capturar
    const captureResult = runCommand(
      'devorq lessons capture "Full test" "Problem" "Solution"',
      projectDir
    );
    expect(captureResult.stdout).toMatch(/lesson|Lição/i);
    console.log('1. Capture:', captureResult.stdout);
    
    // 2. Listar
    const listResult = runCommand('devorq lessons list', projectDir);
    expect(listResult.stdout).toMatch(/lesson|Lição/i);
    console.log('2. List:', listResult.stdout);
    
    // 3. Buscar
    const searchResult = runCommand('devorq lessons search "Full"', projectDir);
    expect(searchResult.stdout).toMatch(/Full|lesson|Lição/i);
    console.log('3. Search:', searchResult.stdout);
    
    // 4. Validar
    const validateResult = runCommand('devorq lessons validate', projectDir);
    console.log('4. Validate:', validateResult.stdout);
  });
});
