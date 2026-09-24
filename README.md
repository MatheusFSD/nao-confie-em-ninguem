# Não confie em ninguém — primeira cena

Uma casa, uma vizinha e a escolha de abrir ou não o portão. Esta etapa serve para experimentar se a conversa e a decisão criam tensão.

Abra **index.html** no navegador. Não precisa instalar nada. Opcionalmente, execute `node server.cjs` e acesse <http://127.0.0.1:4173>.

## O que dá para fazer

1. Ouvir um aviso no rádio, se quiser.
2. Ir ao portão e conversar com Dona Celina.
3. Fazer uma pergunta ou decidir diretamente se deixa ela entrar.
4. Ler a consequência e jogar novamente.

Não há protocolos, recursos, caderno, salvamento, áudio ou campanha nesta etapa. O mistério fica em aberto. O cenário e o retrato foram reaproveitados da versão anterior.

## Código

- `index.html`: estrutura da cena.
- `css/game.css`: apresentação e adaptação a telas menores.
- `js/game.js`: classe `Visit` com o diálogo e classe `Game` com as interações.

JavaScript e CSS ficam separados. O jogo não usa dependências nem serviços externos.

## Versões guardadas

- `index(2).html`: protótipo original do usuário.
- `versions/three-nights/index.html`: versão maior feita anteriormente, com seus arquivos e documentação preservados.

Primeiro vamos avaliar esta cena. A próxima etapa pode ser ajustar a conversa ou acrescentar uma segunda visita, conforme o que funcionar ao jogar.

