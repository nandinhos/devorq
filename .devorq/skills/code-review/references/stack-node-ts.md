# Referência: Node.js / TypeScript / Next.js — Regras Específicas de Code Review

Aplique estas regras **além** das regras universais do SKILL.md principal.

---

## VERSÕES & DEPENDÊNCIAS

```bash
# Versões declaradas
node --version 2>/dev/null; cat .nvmrc 2>/dev/null
cat package.json | grep -E '"node"|"engines"'
grep '"typescript"' package.json

# Pacotes desatualizados com vulnerabilidades
npm audit 2>/dev/null | tail -20

# Dependências duplicadas ou conflitantes
npm ls --depth=0 2>/dev/null | grep -E "WARN|ERR" | head -10
```

---

## TYPESCRIPT — QUALIDADE DE TIPOS

```bash
# any implícito ou explícito (red flag)
grep -rn ": any\|as any\|<any>" src/ app/ --include="*.ts" --include="*.tsx" | grep -v node_modules | grep -v ".d.ts" | head -20

# Type assertions forçadas sem justificativa
grep -rn " as [A-Z]" src/ app/ --include="*.ts" | grep -v node_modules | head -10

# Non-null assertions excessivas
grep -rn "!\." src/ app/ --include="*.ts" --include="*.tsx" | grep -v node_modules | head -10
```

Padrões problemáticos:
```typescript
// ❌ Desabilitar TypeScript
// @ts-ignore
// @ts-expect-error (sem justificativa)
const data = response as any;

// ✅ Tipos explícitos e seguros
interface ApiResponse<T> {
  data: T;
  error: string | null;
}
const data: ApiResponse<User> = await fetchUser(id);
```

Verificar:
- `strict: true` no tsconfig.json?
- Tipos de retorno explícitos em funções públicas?
- Enums ou union types em vez de magic strings?
- Generics bem utilizados vs. types duplicados?

---

## ASYNC/AWAIT & PROMISES

```bash
# Promises sem .catch() ou try/catch
grep -rn "\.then(" src/ --include="*.ts" --include="*.js" | grep -v "\.catch\|node_modules" | head -10

# await sem try/catch em operações críticas
grep -rn "await " src/ --include="*.ts" | grep -v "try\|node_modules" | head -20
```

Padrões:
```typescript
// ❌ Erro engolido
fetchData().then(data => process(data)); // sem .catch()

// ❌ await não tratado
const data = await fetch(url); // sem try/catch, sem verificação de status

// ✅ Correto
try {
  const response = await fetch(url);
  if (!response.ok) throw new Error(`HTTP ${response.status}`);
  const data: ResponseType = await response.json();
} catch (error) {
  logger.error('fetchData failed', { error, url });
  throw error; // re-throw se o chamador precisa saber
}
```

---

## NEXT.JS (se detectado)

```bash
cat next.config.js next.config.mjs 2>/dev/null
ls app/ pages/ 2>/dev/null | head -20
```

### Server Components vs. Client Components
```bash
# Verificar uso desnecessário de 'use client'
grep -rn '"use client"' app/ src/ | grep -v node_modules | head -15
```

Padrões problemáticos:
- `'use client'` no topo de páginas que só renderizam dados estáticos
- Fetch de dados em Client Components quando Server Component resolveria
- Secrets de API acessados em código client-side (sem `NEXT_PUBLIC_` prefix mas visível no browser)
- `useEffect` para buscar dados quando `async/await` em Server Component é mais seguro

### Data Fetching
```typescript
// ❌ Fetch sem revalidação configurada
const data = await fetch('https://api.example.com/data');

// ✅ Cache e revalidação explícitos
const data = await fetch('https://api.example.com/data', {
  next: { revalidate: 3600 } // ou { tags: ['products'] }
});
```

### API Routes / Route Handlers
```bash
grep -rn "export.*GET\|export.*POST\|export.*PUT\|export.*DELETE" app/api/ --include="*.ts" | head -15
```

Verificar:
- Autenticação verificada antes de qualquer operação?
- Input validado com zod/joi antes de usar?
- Rate limiting configurado?
- Erros retornam status codes corretos (não sempre 200)?

---

## SEGURANÇA NODE.JS

```bash
# Environment variables expostas ao client
grep -rn "process\.env\." src/ app/ --include="*.ts" --include="*.tsx" | grep -v "NEXT_PUBLIC_\|node_modules" | head -15

# Deserialização insegura
grep -rn "JSON\.parse\|eval(" src/ --include="*.ts" --include="*.js" | grep -v node_modules | grep -v ".test." | head -10
```

Verificar:
- Variáveis de ambiente sensíveis NUNCA com prefixo `NEXT_PUBLIC_`
- `helmet` configurado em Express/Fastify APIs?
- CORS restrito a origens conhecidas?
- Inputs de usuário passados para `child_process.exec` ou `eval`?

---

## PERFORMANCE

```bash
# Imports que podem causar bundle grande
grep -rn "import \* as\|require(" src/ --include="*.ts" --include="*.tsx" | grep -v node_modules | head -10
```

Verificar:
- Tree-shaking funcionando? Imports nomeados em vez de `import * as`?
- Imagens com `next/image` para otimização automática?
- Fontes com `next/font` para evitar layout shift?
- Lazy loading em componentes pesados com `dynamic()` ou `React.lazy()`?
- `React.memo` e `useMemo`/`useCallback` usados onde há impacto mensurável (não prematuramente)?

---

## TESTES (Jest/Vitest)

```bash
find . -name "*.test.ts" -o -name "*.spec.ts" | grep -v node_modules | head -20
```

Verificar:
- Mocks de módulos externos corretos e não excessivos?
- `beforeEach`/`afterEach` limpando estado entre testes?
- Testes de integração cobrindo fluxos de API críticos?
- Snapshots desatualizados que perderam significado?
