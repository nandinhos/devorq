# Regras do Projeto - Greenfield

## Contexto
- Tipo: Sistema novo
- Stack: generic
- Regra: Arquitetura primeiro, código depois

## Regras de Ouro
1. TDD Obrigatório
2. PRD como fonte de verdade
3. Code Review antes de merge

## Padrões
- Estrutura: MVC padrão
- Testes: Feature tests
- Linter: Pint

## Thin Client, Fat Server

Todo projeto DEVORQ segue este princípio de segurança:
- Frontend: captura intenção do usuário, exibe resposta do backend
- Backend: valida, processa, retorna apenas o necessário
- NUNCA lógica de negócio no frontend (cálculos, permissões, autorizações)
