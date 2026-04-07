# Code Review Técnico Profundo — DEVORQ

Data da análise: 2026-04-06

## Achados detalhados

### 1) Quebra funcional no fluxo principal por command substitution acidental
📍 LOCALIZAÇÃO: `lib/orchestration/flow.sh:280-305`  
🏷️  CATEGORIA: Fluxo  
⚠️  SEVERIDADE: CRÍTICO  
📝 DESCRIÇÃO: O heredoc de `phase5_contract` não está quoted (`<< EOF`) e contém blocos com crases (
`caminho/arquivo1.php`, etc.). Em bash, crases executam comando; isso dispara tentativas de execução de caminhos Markdown como comandos.  
💡 IMPACTO: O `devorq flow` gera erros em tempo de execução e compromete a geração de contrato/spec em cenários reais.  
✅ SOLUÇÃO RECOMENDADA: Trocar para heredoc literal (`<< 'EOF'`) e interpolar apenas variáveis necessárias de forma explícita.

### 2) Captura de retorno poluída por logs (quebra de parsing)
📍 LOCALIZAÇÃO: `lib/orchestration/flow.sh:33-65` e `lib/orchestration/flow.sh:373-376`  
🏷️  CATEGORIA: Fluxo  
⚠️  SEVERIDADE: ALTO  
📝 DESCRIÇÃO: `run_full_flow` usa `context=$(phase1_detection)`, mas `phase1_detection` escreve logs e dados no stdout. O parsing por `cut -d:` passa a operar sobre múltiplas linhas não estruturadas.  
💡 IMPACTO: Stack/tipo podem ser interpretados incorretamente, contaminando fases subsequentes e regras aplicadas.  
✅ SOLUÇÃO RECOMENDADA: Escrever logs no stderr (`>&2`) e manter stdout apenas para payload estruturado; preferir retorno JSON (`jq -r`) no fluxo.

### 3) Implementação duplicada de funções no módulo de fallback MCP
📍 LOCALIZAÇÃO: `lib/mcp-fallback.sh:18-52` e `lib/mcp-fallback.sh:159-201`  
🏷️  CATEGORIA: Débito Técnico  
⚠️  SEVERIDADE: ALTO  
📝 DESCRIÇÃO: Existem duas versões de log/status (`_mcp_fallback_*` e `mcp_fallback_*`) com lógica quase idêntica.  
💡 IMPACTO: Alto risco de drift funcional, manutenção duplicada e bugs sutis por mudanças aplicadas só em uma variante.  
✅ SOLUÇÃO RECOMENDADA: Consolidar em única implementação interna + wrapper público mínimo, removendo duplicação.

### 4) `spec-index` com seção “Todas as Specs” hardcoded
📍 LOCALIZAÇÃO: `bin/spec-index:39-43`  
🏷️  CATEGORIA: Débito Técnico  
⚠️  SEVERIDADE: ALTO  
📝 DESCRIÇÃO: A tabela principal é fixa e já está desatualizada (há arquivo adicional em `docs/specs` não refletido nessa lista).  
💡 IMPACTO: Índice enganoso, governança de specs quebrada e risco operacional em auditorias/status de entrega.  
✅ SOLUÇÃO RECOMENDADA: Gerar tabela dinamicamente lendo front matter de `docs/specs/*.md` (exceto `_index.md`).

### 5) Checagem de stack em MCP health aponta para caminho incorreto
📍 LOCALIZAÇÃO: `lib/mcp-health-check.sh:189-191`  
🏷️  CATEGORIA: Fluxo  
⚠️  SEVERIDADE: ALTO  
📝 DESCRIÇÃO: O código tenta `source ".devorq/lib/stack-detector.sh"`, caminho que não existe no repo (o módulo está em `lib/stack-detector.sh`).  
💡 IMPACTO: Detecção de stack pode cair em “generic”, mascarando problemas e pulando checks relevantes (ex.: laravel-boost).  
✅ SOLUÇÃO RECOMENDADA: Corrigir para caminho absoluto derivado da raiz do projeto e validar existência com fallback explícito.

### 6) Atualização de `.env` vulnerável a regex injection via `key`
📍 LOCALIZAÇÃO: `lib/core.sh:355-357`  
🏷️  CATEGORIA: Segurança  
⚠️  SEVERIDADE: ALTO  
📝 DESCRIÇÃO: `grep`/`sed` usam `key` sem escaping regex. Chaves com metacaracteres podem causar match/substituição indevida.  
💡 IMPACTO: Corrupção de `.env`, sobrescrita de variáveis erradas e comportamento imprevisível em runtime.  
✅ SOLUÇÃO RECOMENDADA: Validar chave com regex estrita (`^[A-Z_][A-Z0-9_]*$`) e escapar valor para `sed`.

### 7) Parsing frágil de `.env` (quebra com `=` no valor e espaços)
📍 LOCALIZAÇÃO: `lib/core.sh:331-341`  
🏷️  CATEGORIA: Qualidade  
⚠️  SEVERIDADE: MÉDIO  
📝 DESCRIÇÃO: Parser linha-a-linha baseado em `IFS='=' read` + `xargs` remove espaços e pode truncar/alterar valores válidos (`JWT=aaa=bbb`, strings com espaços).  
💡 IMPACTO: Variáveis carregadas incorretamente, falhas difíceis de rastrear e diferenças entre ambiente real e esperado.  
✅ SOLUÇÃO RECOMENDADA: Parser robusto (ex.: `dotenv` compatível) ou lógica shell que preserve conteúdo após o primeiro `=` sem `xargs` destrutivo.

### 8) Loop com word-splitting para arquivos pode quebrar em paths com espaço
📍 LOCALIZAÇÃO: `bin/devorq:315-316`, `bin/devorq:373-374`, `lib/handoff.sh:162`  
🏷️  CATEGORIA: Fluxo  
⚠️  SEVERIDADE: MÉDIO  
📝 DESCRIÇÃO: Iterações `for f in $file_list`/`for f in $(ls ...)` quebram com espaços e caracteres especiais em nomes de arquivo.  
💡 IMPACTO: Contagem incorreta de artefatos, status errado de specs/handoffs e falsos negativos de implementação.  
✅ SOLUÇÃO RECOMENDADA: Iterar com `while IFS= read -r` e globs nativos (`for f in "$dir"/*.md; do ...`).

### 9) Uso extensivo de `sed -i` sem compatibilidade BSD/macOS
📍 LOCALIZAÇÃO: `bin/devorq:385-386`, `lib/handoff.sh:194`, `lib/feature-lifecycle.sh:322`  
🏷️  CATEGORIA: Arquitetura  
⚠️  SEVERIDADE: MÉDIO  
📝 DESCRIÇÃO: Sintaxe GNU `sed -i` sem extensão falha em BSD sed (macOS), reduzindo portabilidade.  
💡 IMPACTO: Comandos de update quebram em estações de dev comuns, afetando adoção e previsibilidade.  
✅ SOLUÇÃO RECOMENDADA: Helper cross-platform (`sed_inplace`) que detecta GNU/BSD e aplica flags corretas.

### 10) Inconsistência de versão/documentação pública
📍 LOCALIZAÇÃO: `README.md:1` e `bin/devorq:550`  
🏷️  CATEGORIA: Fluxo  
⚠️  SEVERIDADE: MÉDIO  
📝 DESCRIÇÃO: README declara v2.1 enquanto help CLI declara v2.0.  
💡 IMPACTO: Ambiguidade de suporte, dúvidas sobre compatibilidade de comandos e ruído em troubleshooting.  
✅ SOLUÇÃO RECOMENDADA: Centralizar versão em `VERSION` e renderizar em help/README de forma única.

### 11) Arquitetura com módulos “God files” e baixa separação por domínio
📍 LOCALIZAÇÃO: `lib/feature-lifecycle.sh (1047 linhas)`, `lib/orchestration.sh (732)`, `lib/state.sh (652)`, `bin/devorq (612)`  
🏷️  CATEGORIA: Arquitetura  
⚠️  SEVERIDADE: MÉDIO  
📝 DESCRIÇÃO: Arquivos muito extensos acumulam múltiplas responsabilidades (CLI, IO, estado, regras).  
💡 IMPACTO: Aumenta custo de onboarding, revisão e risco de regressão em mudanças pequenas.  
✅ SOLUÇÃO RECOMENDADA: Extrair submódulos por bounded context (specs, handoff, state, mcp, lifecycle) + contratos de interface.

### 12) Ausência de CI e execução automática de testes
📍 LOCALIZAÇÃO: repositório sem `.github/workflows/*`  
🏷️  CATEGORIA: Qualidade  
⚠️  SEVERIDADE: ALTO  
📝 DESCRIÇÃO: Não há pipeline versionado para rodar validações/testes em PR.  
💡 IMPACTO: Regressões chegam à branch principal sem barreira automatizada.  
✅ SOLUÇÃO RECOMENDADA: Adicionar workflow CI (bash lint + bats + smoke tests do CLI).

### 13) Suite de testes cobre estrutura/texto, pouco comportamento crítico
📍 LOCALIZAÇÃO: `tests/skills.bats:9-87`, `tests/paths.bats:17-85`, `tests/sourcing.bats:21-55`  
🏷️  CATEGORIA: Qualidade  
⚠️  SEVERIDADE: ALTO  
📝 DESCRIÇÃO: Predomina teste de existência/grep; fluxos críticos (`flow`, `spec update`, `handoff update`, parsing de estado) não têm cobertura robusta.  
💡 IMPACTO: Bugs de runtime (como os vistos em `flow`) passam sem detecção prévia.  
✅ SOLUÇÃO RECOMENDADA: Priorizar testes comportamentais de ponta-a-ponta com fixtures temporárias e asserts funcionais.

### 14) Dependência de `jq` declarada como opcional em partes, mas assumida em outras
📍 LOCALIZAÇÃO: `README.md:13`, `lib/mcp-fallback.sh:42-47`, `lib/mcp-fallback.sh:190-195`  
🏷️  CATEGORIA: Gap  
⚠️  SEVERIDADE: MÉDIO  
📝 DESCRIÇÃO: O projeto comunica poucos requisitos, mas há caminhos sem fallback real quando `jq` não está disponível.  
💡 IMPACTO: Falhas em ambientes mínimos e comportamento inconsistente entre módulos.  
✅ SOLUÇÃO RECOMENDADA: Definir política única: `jq` obrigatório (com check no bootstrap) ou fallback validado em todos os módulos.

### 15) Logs runtime não estão totalmente cobertos pelo `.gitignore`
📍 LOCALIZAÇÃO: `lib/mcp-fallback.sh:26-28`, `.gitignore:40-60`  
🏷️  CATEGORIA: Segurança  
⚠️  SEVERIDADE: MÉDIO  
📝 DESCRIÇÃO: O módulo grava `.devorq/logs/mcp-fallback.log`, mas `.devorq/logs/` não está ignorado.  
💡 IMPACTO: Risco de versionar logs operacionais (potencialmente sensíveis) por acidente.  
✅ SOLUÇÃO RECOMENDADA: Ignorar `.devorq/logs/` e mascarar dados sensíveis antes de persistir mensagens.

---

## Resumo Executivo
O repositório apresenta boa intenção de automação, mas há falhas relevantes de corretude no fluxo principal e inconsistências entre documentação, implementação e testabilidade. Os problemas mais graves estão em `flow.sh` (quebra de execução e parsing), governança de specs não confiável (`spec-index` hardcoded) e cobertura de testes insuficiente para fluxos críticos. Em segurança, o manejo de `.env` e logs merece endurecimento imediato. Sem CI e sem contratos internos claros entre módulos, o risco de regressão permanece alto.

## Top 5 Prioridades
1. Corrigir `flow.sh` (heredocs + separação stdout/stderr) para eliminar falhas críticas de execução.
2. Tornar `spec-index` 100% dinâmico, removendo tabela hardcoded.
3. Endurecer `set_env_value`/`load_env` para parsing e escrita seguras.
4. Implementar CI com execução de testes e smoke tests do CLI.
5. Consolidar duplicações de `mcp-fallback` e corrigir path de stack detector no health-check.

## Mapa de Débito Técnico (contagem)
- Débito Técnico: 2
- Segurança: 3
- Arquitetura: 2
- Fluxo: 5
- Performance: 0
- Qualidade: 3
- Gap: 1

## Roadmap de Refinamento
### Sprint 1 (corretude + risco alto)
- Itens 1, 2, 5, 12, 13.

### Sprint 2 (segurança + robustez de estado/config)
- Itens 6, 7, 15, 14.

### Sprint 3 (manutenibilidade + portabilidade)
- Itens 3, 8, 9, 10, 11.

## Quick Wins (baixo esforço / alto impacto)
- Adicionar `.devorq/logs/` no `.gitignore`.
- Corrigir caminho de source no `mcp_health_all`.
- Substituir `for f in $(ls ...)` por glob + `while read`.
- Unificar versão exibida no help com `VERSION`.
- Criar smoke test de `./bin/devorq flow "teste"` em ambiente temporário.
