# HANDOFF PACKAGE — Bloco D: Documentação e Prompts Multi-LLM

> **Modelo Híbrido (Opção C)**
> Seções 1, 4 e 6 geradas com base no estado atual do projeto.
> Princípio: o executor abre este arquivo e executa. Zero perguntas.

---

## METADADOS

- **Tarefa**: Documentar a metodologia v2.1 (skills spec/break e estrutura de prompts agnóstica)
- **Data**: 2026-04-03
- **Arquiteto**: Nando Dev + Antigravity (Tier 1)
- **Executor recomendado**: Tier 2 (qualquer modelo)
- **Branch**: main
- **Worktree**: não aplicável (trabalhar na main)
- **Estimativa**: 1 arquivo modificado, 5 criados/refatorados

---

## PROTOCOLO DE SESSÃO

**Execução iterativa**
[Sessão Tier 1 — planejamento]     → gera este handoff
        ↓ handoff package
[Nova sessão Tier 2 — execução]    → executa, commita, retorna RETORNO
        ↓ relatório de retorno
[Nova sessão Tier 1 — verificação] → lê este handoff + RETORNO

**Para o executor (Tier 2)**
- Abra uma sessão nova.
- Leia apenas este arquivo.
- Não explique suas ações, retorne o formato do Bloco 7.

---

## 1. SNAPSHOT DO PROJETO

- **Stack**: Markdown
- **Estado atual**: Blocos A, B e C finalizados. O sistema agora suporta MCP incremental para JSON confiavelmente. O trabalho deste bloco independe do código-fonte Bash, focando unicamente na matriz de documentação e engenharia de prompts da automação DEVORQ v2.1.
- **Destaque**: O framework agora prevê o uso formal de `/spec` e `/break` antes de qualquer execução pesada.

---

## 2. CONTRATO DE ESCOPO

### FAZER

1. Criar `prompts/activation.md` que descreva o funcionamento, inicialização e uso das skills do repositório, mas **sem fazer menção específica ao nome de qualquer IA**.
2. Secar (refatorar) os arquivos `prompts/gemini.md`, `prompts/opencode.md` e `prompts/antigravity.md` para terem no máximo ~30 linhas. Eles devem conter **apenas** instruções e tags intrínsecas da API/plataforma deles, indicando que devem ler o `activation.md` para absorver os detalhes comportamentais e macro-metodológicos do sistema.
3. Atualizar o `CLAUDE.md`, inserindo as skills `/spec` e `/break` na listagem de overview e no fluxo primário de desenvolvimento.
4. Criar o documento `SLASH_COMMANDS.md` listando e explicando a funcionalidade dessas chamadas dentro do Devorq.
5. Inserir na modelagem da skill em `.devorq/skills/handoff/SKILL.md` a adoção sumária dos pacotes baseados nestas 7 seções.

### NÃO FAZER

- Não editar scripts executáveis (`*.sh` ou `.bats`).
- Não deletar nenhuma instrução crítica dos prompts-mãe sem garantir que ela passará intacta para o local seguro e compartilhado do `activation.md`.

---

## 3. TASK BRIEF

### Step 0 — Verificação de divergência

```bash
git fetch origin
git log --oneline origin/main..HEAD
```
Se estiver divergente, pause e reporte ao arquiteto. Caso contrário, prossiga.

### Sub-task D1: Base Agnóstica e Slash Commands

1. **`prompts/activation.md`**: Crie detalhando a abordagem Devorq: mentalidade Thin Client vs Fat Server, o isolamento dos pacotes Handoff em 7 blocos e o gatilho das requisições via `/spec` e `/break`. Nenhuma nomenclatura restrita (ex: "Claude", "Gemini") deve estar no escopo universal.
2. **`SLASH_COMMANDS.md`**: Crie listando as macros e atalhos aceitos via slash command na plataforma, reforçando como a equipe os acionará.

### Sub-task D2: Enxugamento dos injetores diretos

Em **`prompts/gemini.md`**, **`prompts/opencode.md`** e **`prompts/antigravity.md`**:
Remova regras genéricas e comportamentos do sistema operados no `activation.md`. Mantenha apenas:
- Como aquele modelo específico deve gerenciar suas funções exclusivas (tool calls do Gemini, diretrizes XML do Claude no opencode, etc).
- Uma instrução imperativa: *"Esteja ciente do nosso modelo agnóstico. Leia a nossa metodologia universal em `prompts/activation.md` para internalizar os fundamentos de comportamento sistêmico do DEVORQ."*

### Sub-task D3: CLAUDE.md

Abra o **`CLAUDE.md`**. Na seção de Skills e Fluxos de Controle de Versão/Planejamento, torne explícita a obrigatoriedade de decompor os subníveis macros usando `/spec` seguido de `/break` antes do envio de sub-tarefas e pacotes de Handoff para camada subordinada. Modifique os números em qualquer sumário que cite explicitamente que o frame agora comporta 17 core skills.

### Sub-task D4: Atualização da Skill de Handoff

Em **`.devorq/skills/handoff/SKILL.md`**, reescreva a descrição das seções englobando a exigência dos formatos: Metadados, Snapshot, Contrato, Task Brief, Verificação e Retorno. O executor ao puxar essa skill tem que entender que sua principal vocação é compilar blocos semânticos desta exata forma.

---

## 4. VERIFICAÇÃO

- Rodar `./bin/devorq skills` no terminal.
  - Verifique se as skills citadas refletem a presença de `spec`, `break` e `handoff`. (Você deve ver 17 listadas na consolidação).
- Valide que os arquivos recém processados contém menos peso: faça um `wc -l prompts/{gemini,opencode,antigravity}.md`. Eles devem estar curtos, não mais que 40 linhas num limite conservador.

---

## 5. PADRÕES OBRIGATÓRIOS PARA ESTA TASK

- Todos os textos técnicos devem utilizar estilo afiado, Markdown semântico (Headers precisos) e obrigatoriamente Português do Brasil (pt-BR).
- Crie um único commit final em nome da documentação, englobando este Bloco D. Formato DEVORQ exigido (`docs: <sua mensagem em pt-BR>`).

---

## 6. DONE CRITERIA

- [ ] `prompts/activation.md` preenchido como pilar central, abstraído de grifes LLM.
- [ ] Prompts das engines (`gemini.md`, etc) esvaziados até sobraram suas diretrizes vitais intrínsecas e ref ao activation.
- [ ] `CLAUDE.md` aponta `/spec` e `/break` atualizados.
- [ ] O `SLASH_COMMANDS.md` gerado.
- [ ] `handoff/SKILL.md` padronizado na documentação sobre as 7 seções iterativas.

---

## 7. RETORNO ESPERADO

Ao concluir suas obrigações locais, formate a seguinte resposta (markdown puro) e entregue:

```markdown
# RETORNO — Bloco D: Documentação e Prompts Multi-LLM

- **SHA commit D1 (docs)**: [hash]
- **Quantidade de linhas gemini.md**: [N]
- **Quantidade de linhas opencode.md**: [N]
- **Quantidade de linhas antigravity.md**: [N]
- **Smoke test skills devolveu 17?**: [Sim/Não]
- **Desvios do plano**: [nenhum | breve descrição caso necessário]
- **Erros ou atritos em markdown encontrados**: [nenhum | breve descrição]
```
