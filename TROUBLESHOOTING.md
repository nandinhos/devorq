# Troubleshooting — DEVORQ

> Problemas comuns e soluções.

**Versão:** 4.0.0

---

## "jq: command not found"

**Causa:** `jq` não está instalado e não há apt-get (container rootless).

**Solução:**
```bash
curl -L https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux64 \
  -o ~/bin/jq
chmod +x ~/bin/jq
export PATH="$HOME/bin:$PATH"

# Verificar
~/bin/jq --version
```

> DEVORQ funciona sem `jq` — usa fallback grep/sed. Mas com `jq` as saídas são mais limpas.

---

## "devorq: command not found"

**Causa:** `bin/devorq` não está no PATH.

**Solução:**
```bash
# Temporary (sessão atual)
export PATH="$HOME/devorq/bin:$PATH"

# Permanent
echo 'export PATH="$HOME/devorq/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

**Verificar:**
```bash
which devorq
devorq version
```

---

## "Permission denied" ao executar devorq

**Solução:**
```bash
chmod +x ~/devorq/bin/devorq
# ou
chmod +x ~/bin/devorq
```

---

## "bash: devorq: No such file or directory" mesmo com PATH correto

**Causa:** Executando dentro de um container Docker onde `~/bin` é um volume diferente.

**Solução:**
```bash
# Verificar ambiente
echo $PATH
which devorq
ls -la ~/bin/devorq

# Usar caminho absoluto se necessário
/path/to/devorq/bin/devorq version
```

---

## "lib/gates.sh not found" ou outra lib não encontrada

**Causa:** `DEVORQ_ROOT` ou `DEVORQ_LIB` com caminho errado.

**Solução:**
```bash
# Definir explicitamente
export DEVORQ_ROOT="$HOME/devorq"
export DEVORQ_LIB="$DEVORQ_ROOT/lib"

# Verificar
ls $DEVORQ_LIB/*.sh
```

---

## GATE sempre vermelho

**Passo 1:** Execute com debug para ver o que falha:
```bash
bash -x bin/devorq gate 1
bash -x bin/devorq gate 2
```

**Passo 2:** Corrija o problema identificado.

**Passo 3:** Teste novamente.

---

## "context.json" não encontrado

**Causa:** Projeto não foi inicializado.

**Solução:**
```bash
devorq init
devorq gate 3
```

**Se já existe:**
```bash
rm -rf .devorq   # remover se quiser recriar
devorq init
```

---

## GATE-6 sempre warn (Context7)

**Causa:** `OPENAI_API_KEY` não configurada.

**Solução:**
```bash
# Via env
export OPENAI_API_KEY=sk-***

# Via config file
mkdir -p ~/.devorq
echo "OPENAI_API_KEY=sk-***" >> ~/.devorq/config
```

> **Nota:** GATE-6 nunca bloqueia mesmo sem API key. É apenas um aviso.

---

## SSH "Connection refused" ao VPS

**Causa:** VPS offline ou porta diferente.

**Solução — verificar:**
```bash
ssh -p 6985 -o ConnectTimeout=5 root@187.108.197.199 "echo ok"
```

**Se falhar:**
- VPS pode estar reiniciando — aguarde e tente novamente
- Verificar se porta está correta (6985)
- Verificar se IP está correto (187.108.197.199)

---

## PostgreSQL "connection refused" no container

**Causa:** Container `hermesstudy_postgres` não está rodando.

**Solução:**
```bash
# Verificar status
ssh -p 6985 root@187.108.197.199 "docker ps | grep postgres"

# Iniciar se parado
ssh -p 6985 root@187.108.197.199 "docker start hermesstudy_postgres"

# Testar conexão
ssh -p 6985 root@187.108.197.199 \
  "docker exec hermesstudy_postgres psql -U hermes_study -d hermes_study -c 'SELECT 1;'"
```

---

## "No such file or directory" ao importar lib

**Causa:** `DEVORQ_LIB` ou `DEVORQ_ROOT` com caminho errado.

**Solução:**
```bash
export DEVORQ_ROOT="$HOME/devorq"
export DEVORQ_LIB="$DEVORQ_ROOT/lib"

# Verificar
ls $DEVORQ_LIB/*.sh
```

---

## devorq init não cria .devorq/

**Verificar:**
1. Está em um diretório com permissão de escrita
2. `.devorq/` não existe já (init não sobrescreve se já existir)
3. `devorq version` mostra versão válida

```bash
# Forçar recriação
rm -rf .devorq
devorq init

# Verificar
ls -la .devorq/
```

---

## devorq build falha

```bash
# Ver exatamente onde falhou
bash -x bin/devorq build

# Ou gate por gate
devorq gate 1
devorq gate 2
devorq gate 3
# ...etc
```

---

## sync push/pull não funciona

**Verificar:**
```bash
# 1. VPS está online
devorq vps check

# 2. Scripts existem
ls -la scripts/sync-push.py
ls -la scripts/sync-pull.py

# 3. Python disponível
python3 --version

# 4. Testar manualmente
python3 scripts/sync-push.py
```

---

## Lessons não aparecem no search

```bash
# Verificar se diretório existe
ls -la .devorq/state/lessons/

# Verificar se há lições
find .devorq/state/lessons/ -name "*.json"

# Verificar conteúdo
cat .devorq/state/lessons/*.json
```

---

## Shellcheck errors

DEVORQ usa `set -euo pipefail` e shellcheck stringent.

**Para validar localmente:**
```bash
# Instalar shellcheck (se quiser)
apt install shellcheck   # ou: brew install shellcheck

# Validar
shellcheck bin/devorq
shellcheck lib/*.sh
```

**Nota:** Alguns `shellcheck disable` são intencionais (ex: `source` dinâmico).

---

## Problema Não Listado

```bash
# Modo verbose
devorq -v <comando>

# Trace completo
bash -x bin/devorq <comando>

# Ver logs / estado
cat .devorq/state/context.json
cat .devorq/state/session.json

# Ver versão
devorq version

# Reportar issue em:
# https://github.com/nandinhos/devorq/issues
```

---

**Versão:** 4.0.0
**Repo:** https://github.com/nandinhos/devorq
