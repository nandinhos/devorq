# Instalação — DEVORQ

> Guia completo de instalação para Linux, macOS, WSL, e containers Docker.

**Versão:** 4.1.0

---

## Requisitos

```
┌─────────────────────────────────────────────────────────────┐
│  Bash 5+           • Linux/macOS/WSL nativos                │
│  Git               • Para clone e updates                  │
│  jq 1.7+           • Opcional (binary estático incluso)   │
│  SSH               • Opcional (para conexão HUB)          │
└─────────────────────────────────────────────────────────────┘
```

---

## Instalação Padrão (Clone)

```bash
# 1. Clonar repositório
git clone https://github.com/nandinhos/devorq.git ~/projects/devorq

# 2. Adicionar ao PATH (adicione no ~/.bashrc ou ~/.zshrc)
echo 'export PATH="$HOME/projects/devorq/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# 3. Verificar instalação
devorq version

# 4. Testar
devorq test
```

> **Importante:** Use `~/projects/devorq` como destino. Não use `~/devorq` —
> esse caminho era documentado em versões anteriores e pode conflitar com
> instalações antigas. O DEVORQ detecta múltiplas instalações e alerta no
> `devorq version` se encontrar conflito de PATH.

---

## Instalação (via clone — obrigatório)

> **Não existe instalação de arquivo único.** Desde o refactor modular (v3.x),
> `bin/devorq` é apenas o *router* e faz `source` de `lib/`. Baixar só o binário
> falha com `[ERROR] instalacao incompleta`. Use o clone:

```bash
git clone https://github.com/nandinhos/devorq.git ~/projects/devorq
ln -s ~/projects/devorq/bin/devorq ~/bin/devorq   # ~/bin no PATH
devorq version                                        # verificar
```

> **Nota:** Certifique-se que `~/bin` está no PATH. Adicione se necessário:
> `export PATH="$HOME/bin:$PATH"`

---

## jq (Se Não Tiver)

DEVORQ funciona com ou sem `jq`. Com `jq` as saídas são mais limpas.

```bash
# Instalar jq binary estático (funciona em qualquer lugar, mesmo sem apt)
curl -L https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux64 \
  -o ~/bin/jq
chmod +x ~/bin/jq

# Verificar
~/bin/jq --version
```

**Funciona em:** Docker rootless, containers sem apt-get, sistemas sem permissões de root.

---

## Pós-Instalação

```bash
# Inicializar em qualquer projeto
cd /projects/meu-projeto
devorq init

# Verificar estrutura
devorq test

# Testar gates
devorq gate 1
devorq gate 2
devorq gate 3
```

---

## Instalação no WSL

```bash
# Same steps — funciona nativamente no WSL
git clone https://github.com/nandinhos/devorq.git ~/projects/devorq
echo 'export PATH="$HOME/projects/devorq/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
devorq version
```

---

## Instalação no Docker / Container

```bash
# 1. No Dockerfile: clonar o repo completo e symlinkar o router
RUN git clone --depth 1 https://github.com/nandinhos/devorq.git /opt/devorq \
  && ln -s /opt/devorq/bin/devorq /usr/local/bin/devorq

# 2. jq binary estático
RUN curl -L https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux64 \
  -o /usr/local/bin/jq && chmod +x /usr/local/bin/jq
```

---

## Configuração Opcional — Context7 API

Para usar Context7 (consulta de documentação oficial):

```bash
# Via env (sessão atual)
export OPENAI_API_KEY=sk-***

# Via config file (persistente)
mkdir -p ~/.devorq
echo "OPENAI_API_KEY=sk-***" >> ~/.devorq/config
```

> **GATE-6 funciona sem Context7** — apenas mostra warning, nunca bloqueia.

---

## Configuração Opcional — VPS HUB

Para sincronizar lições com o HUB remoto:

```bash
# Via env
export DEVORQ_VPS_HOST=187.108.197.199
export DEVORQ_VPS_PORT=6985
export DEVORQ_VPS_USER=root

# Via config file
cat >> ~/.devorq/config << 'EOF'
DEVORQ_VPS_HOST=187.108.197.199
DEVORQ_VPS_PORT=6985
DEVORQ_VPS_USER=root
DEVORQ_PG_DB=hermes_study
DEVORQ_PG_USER=hermes_study
DEVORQ_PG_PORT=5433
EOF

# Testar conexão
devorq vps check
```

---

## Integração com DeepSeek Harness (DSH)

O DEVORQ também pode rodar como **agent preset** no [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness), expondo a metodologia (persona + skill `devorq`) ao agente de código completo.

Instala/repara o plugin (idempotente — o repo é a fonte canônica):

```bash
bash scripts/install-dsh-preset.sh          # instala/repara
bash scripts/install-dsh-preset.sh --dry-run # só mostra o que faria
```

O que o script cria/atualiza em `$DSH_HOME` (default `~/.dsh`):

| Destino | Conteúdo |
|---------|----------|
| `~/.dsh/.agent-presets/devorq/agent.cordis.yml` | Preset DEVORQ (persona, gates, ferramentas) — template do repo |
| `~/.dsh/.agent-presets/devorq/preset.yml` | Metadados do preset |
| `~/.dsh/skills/devorq/SKILL.md` | Skill `devorq` (root user-dsh, rank 400 — auto-descoberta) |

> **Por que a skill fica em `~/.dsh/skills/` e não no preset:** o provider `dsh-skill-filesystem` não varre o diretório do preset — só roots fixos (projeto, custom, usuário, bundled). Colocá-la no root user-dsh (`<dshHome>/skills/`) é auto-descoberta e **sobrevive a cópia do preset** (um `customSkillDirs` apontando para o preset hardcodaria o id e quebraria).

> **Importante:** após instalar/editar o preset, abra uma **nova sessão** no DEVORQ — a composição do preset é carregada por geração (mtime/size do `agent.cordis.yml`) e a sessão corrente não é recomposta.

---

## Verificação Final

```bash
# Versão
devorq version

# Teste de estrutura
devorq test

# Help
devorq help

# Gates
devorq gate 1 && devorq gate 2 && devorq gate 3

# Workflow completo (opcional)
devorq flow "primeiro uso do devorq"
```

---

## Desinstalação

```bash
# Via comando (preserva lessons)
devorq uninstall

# Ou manualmente:
rm -rf ~/.devorq        # estado local (lições perdidas)
rm ~/bin/devorq         # ou ~/.local/bin/devorq

# Remover do PATH (edit ~/.bashrc)
# Remover linha: export PATH="$HOME/devorq/bin:$PATH"
```

> **Nota:** `devorq uninstall` preserva `.devorq/state/lessons/` antes de remover.

---

## Troubleshooting de Instalação

|| Sintoma | Solução |
|---------|---------|
| `devorq: command not found` | `export PATH="$HOME/projects/devorq/bin:$PATH"` |
| `devorq version` mostra versão inesperada | Verifique qual binário está no PATH: `which devorq` |
| `devorq: multiple installations detected` | Remova instalações antigas: `rm -rf ~/devorq ~/.devorq_v3` |
| `Permission denied` | `chmod +x ~/projects/devorq/bin/devorq` |
| `bash: devorq: No such file` | Verificar se PATH contém diretório correto: `echo $PATH` |
| jq errors | `curl -L .../jq-linux64 -o ~/bin/jq && chmod +x ~/bin/jq` |

### Detectando instalações concorrentes

Se `devorq version` afficher `[WARN] multiple installations found`, identifique
todas as cópias:

```bash
find ~ -maxdepth 2 -name "devorq" -type f 2>/dev/null | xargs -I{} sh -c 'echo "=== {} ===" && head -3 {}'
```

Manenha apenas `~/projects/devorq/` (ou `~/bin/devorq` com symlink para ela).

---

**Versão:** 4.1.0
**Repo:** https://github.com/nandinhos/devorq
