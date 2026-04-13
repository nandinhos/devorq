# DEVORQ Installer

## Instalação do Zero

```bash
curl -fsSL https://raw.githubusercontent.com/nandinhos/devorq/main/install-devorq.sh | bash
```

Isso instala o DEVORQ em `~/.devorq/` e cria symlink em `~/.local/bin/devorq`.

## Instalar em um Projeto

```bash
cd meu-projeto
devorq install
```

Isso copia bin/, lib/, .devorq/ para o projeto e cria `.devorq/version`.

## Ativar no Projeto

```bash
devorq activate
```

Exporta DEVORQ_ROOT e adiciona bin/ ao PATH.

## Atualizar DEVORQ

```bash
devorq update
```

Atualiza a instalação global e replica nos projetos.