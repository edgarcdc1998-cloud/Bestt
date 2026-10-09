# Best Player Android — catálogo e séries

Proposta aprovada em 9 de outubro de 2026. Base: `02280c5a1dcd13334aa4021c4311002fed8b2d3d`.

## Direção visual

- Fundo escuro, superfícies discretas e destaque vermelho existente.
- Tipografia Roboto do Material no Android; títulos com até duas linhas.
- Navegação inferior: Ao vivo, Filmes, Séries, Favoritos.
- Margens de 16 px, espaçamento de 12 px entre capas e cantos de 12 px.
- Capas com proporção 2:3, largura adaptável e imagem substituta para URLs ausentes ou inválidas.
- Continuar assistindo: cartões horizontais com progresso determinado apenas quando a duração é conhecida.
- Séries: capa, sinopse, seleção de temporada e lista de episódios em uma área rolável.
- Estados separados: carregando, vazio, erro com nova tentativa.

## Correções

1. Uma entrada de série M3U com URL direta deve oferecer reprodução sem consultar a API Xtream.
2. Uma falha de consulta de episódios deve mostrar uma mensagem de erro e permitir nova tentativa, sem afirmar que a série está vazia.
3. Home deve observar a biblioteca compartilhada e atualizar progresso após o retorno do player; ouvintes e recursos são liberados ao sair.

## Validação

Testes de regressão antes das correções, análise estática, suíte Flutter e compilação Android no GitHub Actions. A validação em aparelho com um provedor real permanece uma etapa distinta.

## Figma

Arquivo criado: https://www.figma.com/design/s7HuvZIrmXf8AOA7j7h0HV

A primeira chamada de edição foi bloqueada pelo limite do plano Starter. O arquivo ainda não contém telas; não deve ser tratado como mockup concluído.
