# Referência: React / Vue / Frontend — Regras Específicas de Code Review

Aplique estas regras **além** das regras universais do SKILL.md principal.

---

## ESTRUTURA & ORGANIZAÇÃO

```bash
# Estrutura de componentes
find src/ components/ app/ -name "*.tsx" -o -name "*.jsx" -o -name "*.vue" | grep -v node_modules | head -30

# Componentes muito grandes (> 200 linhas é alerta)
find . -name "*.tsx" -o -name "*.jsx" | grep -v node_modules | xargs wc -l 2>/dev/null | sort -rn | head -10
```

Verificar organização:
```
src/
├── components/    # Reutilizáveis, sem lógica de negócio
│   ├── ui/        # Primitivos (Button, Input, Modal)
│   └── features/  # Compostos por domínio
├── hooks/         # Lógica encapsulada em custom hooks
├── services/      # Chamadas de API
├── stores/        # Estado global
└── types/         # Types/interfaces compartilhados
```

---

## REACT — PADRÕES PROBLEMÁTICOS

### Estado & Re-renders
```bash
grep -rn "useState\|useEffect\|useCallback\|useMemo" src/ --include="*.tsx" --include="*.jsx" | grep -v node_modules | head -20
```

```typescript
// ❌ useEffect para derivar estado (deve ser cálculo direto)
const [fullName, setFullName] = useState('');
useEffect(() => {
  setFullName(`${firstName} ${lastName}`);
}, [firstName, lastName]);

// ✅ Derivado diretamente
const fullName = `${firstName} ${lastName}`;

// ❌ useEffect sem cleanup em subscriptions/timers
useEffect(() => {
  const interval = setInterval(fetchData, 5000);
  // sem return () => clearInterval(interval) → memory leak
});

// ❌ Dependências faltando no array do useEffect
useEffect(() => {
  fetchUser(userId); // userId não está no array
}, []);
```

### Props & Componentes
```bash
# Componentes recebendo muitas props (> 7 é alerta — considerar composição)
grep -rn "interface.*Props" src/ --include="*.tsx" | head -10
```

Sinais de alerta:
- Prop drilling além de 2 níveis (use Context ou estado global)
- Componentes que recebem `onXxx` callbacks excessivos
- Props boolean com nomes ambíguos (`disabled`, `active`, `show`)
- Renderização condicional complexa no JSX (extrair componente)

### Keys em Listas
```bash
grep -rn "\.map(" src/ --include="*.tsx" --include="*.jsx" | grep -v node_modules | head -15
# Verificar se todos os .map() têm key= no elemento raiz
```

```typescript
// ❌ Key com index (causa bugs em listas dinâmicas)
items.map((item, index) => <Item key={index} {...item} />)

// ✅ Key estável e única
items.map((item) => <Item key={item.id} {...item} />)
```

---

## GERENCIAMENTO DE ESTADO

```bash
# Verificar estado global
grep -rn "createContext\|useContext\|createStore\|atom(" src/ --include="*.tsx" --include="*.ts" | grep -v node_modules | head -10
```

Verificar:
- Estado local vs. estado global: está no nível correto?
- Context re-renderizando componentes desnecessariamente? (separar contexts por domínio)
- Estado de servidor (dados da API) em estado global quando React Query/SWR resolveria melhor?
- Mutações de estado fora de setters (imutabilidade violada)?

---

## SEGURANÇA FRONTEND

```bash
# XSS via dangerouslySetInnerHTML
grep -rn "dangerouslySetInnerHTML\|innerHTML\|v-html" src/ --include="*.tsx" --include="*.jsx" --include="*.vue" | grep -v node_modules | head -10
```

Verificar:
- `dangerouslySetInnerHTML` sem sanitização (`DOMPurify`)
- Dados de URL (query params) renderizados diretamente sem validação
- Secrets ou tokens armazenados em `localStorage` sem HTTPOnly cookies
- `eval()` ou `new Function()` com conteúdo dinâmico

---

## ACESSIBILIDADE (A11Y)

```bash
grep -rn "onClick\|onKeyDown" src/ --include="*.tsx" | grep -v node_modules | head -10
# Verificar se elementos interativos são <button> ou têm role= adequado
```

Verificar:
- `<div onClick>` onde deveria ser `<button>` (não acessível por teclado)
- Imagens sem `alt` ou com `alt` genérico ("image", "icon")
- Formulários sem `<label>` associados aos inputs
- Cores com contraste insuficiente para texto

---

## PERFORMANCE FRONTEND

```bash
# Imports pesados sem code splitting
grep -rn "^import" src/ --include="*.tsx" --include="*.ts" | grep -v node_modules | sort | head -20
```

Verificar:
- Componentes grandes não lazy-loaded em rotas?
- Imagens sem dimensões definidas (causa layout shift — CLS)?
- Event listeners globais adicionados sem remoção no cleanup?
- Fonts não preloadadas causando FOUT?
- Bundle size: algum package gigante que tem alternativa menor?
