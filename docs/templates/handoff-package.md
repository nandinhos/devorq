# HANDOFF PACKAGE — [nome da tarefa]

> **Modelo Híbrido (Opção C)**
> Seções 1, 4 e 6 são geradas automaticamente pelo CLI (`./bin/devorq handoff generate`).
> Seções 2, 3, 5 e 7 são preenchidas manualmente pelo arquiteto (Tier 1).
> Princípio: o executor abre este arquivo e executa. Zero perguntas.

---

## METADADOS

- **Tarefa**: [nome descritivo]
- **Data**: YYYY-MM-DD
- **Arquiteto**: [nome + modelo Tier 1 usado]
- **Executor recomendado**: Tier 2 (qualquer modelo)
- **Fallback**: qualquer modelo Tier 2 com este mesmo pacote
- **Branch**: [nome da branch]
- **Worktree**: [caminho, se aplicável]
- **Estimativa**: [N arquivos, N testes esperados]

---

## 1. SNAPSHOT DO PROJETO
> Gerado pelo CLI. Máximo 10 linhas. Não editar manualmente.

- **Stack**: [detectado por `./bin/devorq context`]
- **LLM ativa**: [detectado]
- **Último commit main**: [SHA — mensagem]
- **Estado atual**: [o que já está feito e é relevante para esta task]
- **Branch de trabalho**: [nome]

---

## 2. CONTRATO DE ESCOPO
> Preenchido pelo arquiteto. Este é o único documento de autoridade.

### FAZER
1. [ação específica + arquivo exato]
2. [ação específica + arquivo exato]

### NÃO FAZER
- [proibição explícita — sem ambiguidade]
- [proibição explícita]

### ARQUIVOS AUTORIZADOS
- `caminho/exato/arquivo.ext` (criar | modificar | deletar)

### ARQUIVOS PROIBIDOS
- `caminho/arquivo.ext` — motivo: [razão objetiva]

---

## 3. TASK BRIEF
> Preenchido pelo arquiteto. Arquivo por arquivo. Sem "a implementar depois".

### `caminho/arquivo1.ext`
**Ação**: criar
**Conteúdo completo**:
```
[conteúdo exato — não resumido, não "similar ao anterior"]
```

### `caminho/arquivo2.ext`
**Ação**: modificar
**Localização**: após linha N (`texto exato da linha de referência`)
**Trecho a inserir**:
```
[código ou conteúdo exato]
```

---

## 4. VERIFICAÇÃO
> Gerado pelo CLI com base nos testes existentes. Verificar antes de commitar.

```bash
[comando de teste completo]
```
**Output esperado**:
```
[resultado exato — copiar da última execução conhecida]
```

```bash
[comando de smoke test do CLI]
```
**Output esperado**: `[resultado]`

---

## 5. PADRÕES OBRIGATÓRIOS PARA ESTA TASK
> Preenchido pelo arquiteto. Só os padrões relevantes aqui — não copiar tudo.

- [padrão 1 — específico para esta task]
- [padrão 2]

Regras globais em: `.devorq/rules/` e `CLAUDE.md`

---

## 6. DONE CRITERIA
> Base gerada pelo CLI. Arquiteto pode adicionar itens específicos.

- [ ] Testes passando: `[comando]` → `[N/N ok]`
- [ ] Arquivos criados/modificados estão na lista autorizada
- [ ] Nenhuma referência a `.aidev/` em arquivos novos
- [ ] Sem secrets ou lógica de negócio exposta no frontend
- [ ] [critério específico da task 1]
- [ ] [critério específico da task 2]
- [ ] Commit com mensagem: `[tipo]([escopo]): [descrição em pt-BR]`

---

## 7. RETORNO ESPERADO
> Preenchido pelo arquiteto para orientar o implementador.

Ao concluir, retornar ao arquiteto:

```markdown
# RETORNO — [nome da tarefa]

- **SHA do commit**: [hash]
- **Testes**: [N/N passando]
- **Arquivos modificados**: [lista exata]
- **Desvios do plano**: [nenhum | descrição objetiva]
- **Dúvidas para próxima iteração**: [nenhuma | lista]
```

---

## NOTAS DO ARQUITETO
> Campo livre para contexto adicional que não se encaixa nas seções acima.

[observações, riscos conhecidos, decisões de design que motivaram as escolhas]

### REGRA GLOBAL DE COMMITS

Todos os handoffs DEVORQ devem seguir esta estrutura de commit:

- **Formato**: tipo(especialização): descrição detalhada
- **Idioma**: português do Brasil
- **Sem emojis**: usar texto puro
- **Sem Co-Authorship**: remover linhas de co-authored-by
- **Corpo detalhado**: cada item em linha própria, indentado com 2 espaços
- **Exemplo**:
  ```
  feat(skills): adicionar /spec e /break para projetos grandes
  
  Adiciona novas skills e atualiza arquivos existentes:
  - skill /spec: especificação formal antes de iniciar desenvolvimento
  - skill /break: decomposição de spec em tasks (protótipo visual primeiro)
  - constraint-loader: Step 0 de busca de código reutilizável
  ```
