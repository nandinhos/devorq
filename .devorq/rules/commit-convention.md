# Commit Convention — DEVORQ v4.1.0

**Formato (Model A — convencional):**
```
tipo(escopo): descrição (detalhamento)
```
`tipo` ∈ feat|fix|refactor|docs|test|style|perf|chore · `escopo` = área (tabela abaixo).
Sem colchetes, sem espaço antes do `(`. O hook `commit-msg` valida exatamente isto.

**Exemplo:**
```
feat(bdd): adiciona validação BDD Given/When/Then (lib/spec.sh migrado)
fix(livewire): corrige Alpine duplicado em x-data (remove CDN inline)
refactor(core): extrai devorq::verify para lib/visual.sh
docs(gates): documenta GATE-6 Context7
```

**Regras:**
- Sem emojis
- Sem Co-Authored-By
- Em português do Brasil
- Tipo deve ser um dos tipos convencionais válidos
- Escopo deve ser um dos escopos válidos
- NUNCA usar commits do tipo "WIP", "temp", "debug"

> **Enforcement real (hook `commit-msg`):** o hook valida apenas o **formato**
> `tipo(escopo):` (regex `^[a-z]+\([a-z]+\):`). Ele **não** rejeita escopo fora da
> lista abaixo. A tabela lista os escopos **recomendados/principais** do DEVORQ;
> se um escopo novo se tornar recorrente, adicione-o aqui e em
> `lib/commit.sh`/`lib/rules.sh` — mas o hook não bloqueia por isso.

**Escopos válidos:**

| Escopo | Uso |
|--------|-----|
| `core` | Core do DEVORQ, libs principais |
| `models` | Models Eloquent, migrations |
| `services` | Services, repositories |
| `livewire` | Componentes Livewire |
| `notifications` | Notifications, emails |
| `routes` | Rotas, controllers |
| `config` | Configurações, environment |
| `database` | Schema, migrations |
| `tests` | Testes (Unit, Feature, E2E/Playwright) |
| `bdd` | Validação BDD, Gherkin, specs |
| `gates` | Gates DEVORQ |
| `unify` | Fase UNIFY |
| `docs` | Documentação |
| `debug` | Debug sistemático |
| `spec` | SPEC.md, requisitos |
| `lessons` | Lições aprendidas |
| `compact` | Handoff, compact |
| `vps` | VPS, infraestrutura |
| `hub` | HUB, sincronização |
| `context` | Contexto, estado |
| `release` | Bump de versão / version sync |

**Tipos válidos (posição 1 — convencional):**

| Tipo | Uso |
|------|-----|
| `feat` | Nova funcionalidade (default) |
| `fix` | Correção de bug |
| `refactor` | Refatoração sem mudança de comportamento |
| `docs` | Documentação |
| `test` | Testes |
| `style` | Formatação (Pint, ESLint) |
| `perf` | Performance |
| `chore` | Manutenção |

**Quando commitar:**
- Após `devorq verify` passar (100% verde)
- NUNCA commitar com teste vermelho
- Um commit por story (unidade lógica)

**Trigger automático de debug:**
Quando teste falha (Playwright, PHPUnit), systematic-debugging entra em ação automaticamente — ver `rules/visual-verification.md`