# Sistema de Recursos Humanos — MySQL

Projeto acadêmico simples para demonstrar cadastro de funcionários e cálculo/registro de bônus.

## O que o sistema faz
- Cadastra, lista, edita e exclui funcionários.
- Mostra o departamento de cada funcionário.
- Calcula o bônus previsto com uma FUNCTION.
- Registra o pagamento usando uma PROCEDURE.
- Exibe o histórico de pagamentos.

## Tecnologias
HTML, CSS, JavaScript, Node.js, Express e MySQL.

## 1. Pré-requisitos
Instale Node.js, MySQL (ou XAMPP com MySQL/MariaDB) e Visual Studio Code.

## 2. Criar banco e tabelas
Abra o MySQL Workbench ou phpMyAdmin e execute o arquivo `database.sql` inteiro.
Ele cria o banco `empresa_rh`, as tabelas, os dados de exemplo, a FUNCTION, a PROCEDURE e a VIEW.

Se estiver usando phpMyAdmin, selecione a aba SQL, cole o conteúdo e execute.
Se estiver usando Workbench, abra o arquivo e clique no raio para executar.

## 3. Configurar conexão
Copie `.env.example`, crie uma cópia chamada `.env` e informe os dados da sua instalação MySQL.
Exemplo comum do XAMPP:
- DB_HOST=localhost
- DB_PORT=3306
- DB_NAME=empresa_rh
- DB_USER=root
- DB_PASSWORD= (deixe vazio se seu MySQL não tiver senha)

Não publique o arquivo `.env` com sua senha.

## 4. Instalar dependências
Abra o terminal do VS Code na pasta do projeto:

```bash
npm install
```

## 5. Executar

```bash
npm start
```

Abra no navegador: http://localhost:3000

## 6. Explicação simples dos comandos da aula

| Comando | Para que serve neste projeto |
|---|---|
| CREATE DATABASE | Cria o banco empresa_rh. |
| USE | Escolhe o banco que será usado. |
| CREATE TABLE | Cria as tabelas. |
| AUTO_INCREMENT | Gera o próximo número de ID automaticamente. |
| PRIMARY KEY | Identifica cada registro sem repetir. |
| FOREIGN KEY | Liga uma tabela a outra. |
| INSERT INTO | Insere dados. |
| SELECT | Consulta dados. |
| WHERE | Filtra registros por uma condição. |
| FUNCTION | Calcula o valor do bônus e devolve o resultado. |
| DECLARE | Cria uma variável dentro da função. |
| IF / ELSEIF / ELSE | Escolhe a porcentagem do bônus. |
| SET | Guarda o resultado na variável. |
| RETURN | Devolve o valor calculado pela função. |
| PROCEDURE | Executa ações para registrar o pagamento. |
| CALL | Executa a procedure. |
| CURDATE() | Retorna a data atual. |
| TIMESTAMPDIFF() | Calcula os anos completos entre admissão e hoje. |
| VIEW / CREATE VIEW | Salva uma consulta com nome para usar como relatório. |
| INNER JOIN | Junta registros relacionados de duas tabelas. |
| ON | Informa qual coluna liga as tabelas. |
| AS | Dá um apelido a uma tabela ou coluna. |
| DECIMAL | Armazena valores numéricos com casas decimais, como salário. |
| VARCHAR | Armazena textos de tamanho variável. |
| DATE | Armazena uma data. |

## 7. Como explicar a FUNCTION
A função recebe o salário e os anos de trabalho.
- Se trabalhou menos de 5 anos, calcula 5%.
- Se trabalhou de 5 até 10 anos, calcula 10%.
- Se trabalhou mais de 10 anos, calcula 15%.
Ela retorna o valor do bônus, mas não grava pagamento.

## 8. Como explicar a PROCEDURE
A procedure recebe o ID do funcionário.
Ela procura esse funcionário, calcula quantos anos completos ele trabalha, usa a FUNCTION para calcular o bônus e registra o pagamento na tabela `pagamento_bonus`.

## 9. Diferença entre FUNCTION, PROCEDURE e VIEW
- FUNCTION: faz um cálculo e devolve um valor.
- PROCEDURE: executa uma tarefa; neste caso, grava o pagamento.
- VIEW: é uma consulta salva para facilitar a visualização dos dados.

## 10. Atenção para a apresentação
A regra de bônus é apenas um exemplo didático. Cada clique em “Gerar bônus” registra um novo pagamento. Portanto, não clique várias vezes no mesmo funcionário durante a demonstração, pois o sistema não impede pagamentos repetidos.
