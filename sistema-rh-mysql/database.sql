-- =====================================================================
--  CADASTRO-RH :: SCRIPT PARA APRESENTAÇÃO EM AULA  (MySQL 8.0.16+)
--
--  ATENÇÃO: roda em MySQL (Workbench ou terminal). NÃO roda no TiDB Cloud,
--  que não suporta FUNCTION, PROCEDURE, TRIGGER nem CURSOR.
--  Usa um banco separado (empresa_rh_aula) para não mexer no seu real.
--
--  ORDEM DO SCRIPT
--    1. Tabelas com condições em cada coluna (NOT NULL, CHECK, UNIQUE)
--    2. Trigger (validação + auditoria)
--    3. Função calcular_bonus (IF / ELSEIF / ELSE / SET / RETURN)
--    4. Procedures (CALL + CURSOR + COMMIT/ROLLBACK)
--    5. Dados de exemplo
--    6. Consultas: agregação e os 3 JOINs
--    7. Execução das rotinas
--    8. Transações: SAVEPOINT, ROLLBACK, COMMIT
-- =====================================================================

DROP DATABASE IF EXISTS empresa_rh_aula;
CREATE DATABASE empresa_rh_aula CHARACTER SET utf8mb4;
USE empresa_rh_aula;


-- =====================================================================
-- 1. TABELAS COM CONDIÇÕES EM CADA COLUNA
--    NOT NULL = obrigatório | UNIQUE = não repete | CHECK = regra
-- =====================================================================

CREATE TABLE departamentos (
    id_departamento   INT AUTO_INCREMENT PRIMARY KEY,
    nome_departamento VARCHAR(100) NOT NULL UNIQUE,
    -- regra: nome com pelo menos 3 letras
    CONSTRAINT chk_depto_nome CHECK (CHAR_LENGTH(TRIM(nome_departamento)) >= 3)
);

CREATE TABLE funcionarios (
    id_funcionario  INT AUTO_INCREMENT PRIMARY KEY,
    nome            VARCHAR(150)  NOT NULL,
    cargo           VARCHAR(100)  NOT NULL,
    salario         DECIMAL(10,2) NOT NULL,
    data_admissao   DATE          NOT NULL,
    id_departamento INT           NOT NULL,
    FOREIGN KEY (id_departamento) REFERENCES departamentos(id_departamento),
    -- regra: nome com pelo menos 3 letras
    CONSTRAINT chk_func_nome  CHECK (CHAR_LENGTH(TRIM(nome)) >= 3),
    -- regra: cargo não pode ser vazio
    CONSTRAINT chk_func_cargo CHECK (CHAR_LENGTH(TRIM(cargo)) >= 2),
    -- regra: salário precisa ser maior que zero
    CONSTRAINT chk_func_salario CHECK (salario > 0)
    -- data_admissao não pode ser no futuro: validado no TRIGGER (seção 2),
    -- porque CHECK não aceita CURDATE().
);

CREATE TABLE pagamento_bonus (
    id_pagamento   INT AUTO_INCREMENT PRIMARY KEY,
    id_funcionario INT           NOT NULL,
    data_pagamento DATE          NOT NULL,
    valor_bonus    DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (id_funcionario) REFERENCES funcionarios(id_funcionario),
    -- regra: bônus não pode ser negativo
    CONSTRAINT chk_bonus_valor CHECK (valor_bonus >= 0)
);

-- Tabela que guarda o histórico de mudanças de salário (usada pelo trigger)
CREATE TABLE auditoria_salario (
    id_auditoria    INT AUTO_INCREMENT PRIMARY KEY,
    id_funcionario  INT           NOT NULL,
    salario_antigo  DECIMAL(10,2) NOT NULL,
    salario_novo    DECIMAL(10,2) NOT NULL,
    data_alteracao  DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
);


-- =====================================================================
-- 2. TRIGGERS (rodam sozinhos quando algo acontece na tabela)
-- =====================================================================
DELIMITER $$

-- 2.1 ANTES de inserir funcionário: bloqueia data de admissão no futuro
CREATE TRIGGER trg_valida_admissao
BEFORE INSERT ON funcionarios
FOR EACH ROW
BEGIN
    IF NEW.data_admissao > CURDATE() THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Data de admissao nao pode ser no futuro.';
    END IF;
END$$

-- 2.2 DEPOIS de alterar funcionário: se o salário mudou, grava na auditoria
CREATE TRIGGER trg_auditoria_salario
AFTER UPDATE ON funcionarios
FOR EACH ROW
BEGIN
    IF OLD.salario <> NEW.salario THEN
        INSERT INTO auditoria_salario (id_funcionario, salario_antigo, salario_novo)
        VALUES (NEW.id_funcionario, OLD.salario, NEW.salario);
    END IF;
END$$

DELIMITER ;


-- =====================================================================
-- 3. FUNÇÃO calcular_bonus  (IF, ELSEIF, ELSE, SET, RETURN)
--    Mesma regra da sua view:
--      menos de 5 anos  -> 5%
--      de 5 a 10 anos   -> 10%
--      mais de 10 anos  -> 15%
-- =====================================================================
DELIMITER $$

CREATE FUNCTION calcular_bonus(p_salario DECIMAL(10,2), p_anos INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    DECLARE v_percentual DECIMAL(4,2);

    IF p_anos < 5 THEN
        SET v_percentual = 0.05;
    ELSEIF p_anos <= 10 THEN
        SET v_percentual = 0.10;
    ELSE
        SET v_percentual = 0.15;
    END IF;

    RETURN ROUND(p_salario * v_percentual, 2);
END$$

DELIMITER ;


-- =====================================================================
-- 4. PROCEDURES
-- =====================================================================
DELIMITER $$

-- 4.1 Procedure simples: mostra o bônus de UM funcionário (usa a função)
CREATE PROCEDURE sp_mostrar_bonus(IN p_id INT)
BEGIN
    SELECT
        nome,
        salario,
        TIMESTAMPDIFF(YEAR, data_admissao, CURDATE()) AS anos_de_servico,
        calcular_bonus(salario, TIMESTAMPDIFF(YEAR, data_admissao, CURDATE())) AS bonus
    FROM funcionarios
    WHERE id_funcionario = p_id;
END$$

-- 4.2 Procedure com CURSOR: percorre TODOS os funcionários, um por um,
--     e registra o bônus de cada um em pagamento_bonus.
--     Se der erro em qualquer um, ROLLBACK desfaz tudo. Se der certo, COMMIT.
CREATE PROCEDURE sp_pagar_bonus_todos()
BEGIN
    DECLARE v_id       INT;
    DECLARE v_salario  DECIMAL(10,2);
    DECLARE v_admissao DATE;
    DECLARE v_bonus    DECIMAL(10,2);
    DECLARE v_total    INT DEFAULT 0;
    DECLARE v_fim      INT DEFAULT 0;   -- vira 1 quando acabam as linhas

    -- o cursor: a lista de funcionários que será percorrida
    DECLARE cur_func CURSOR FOR
        SELECT id_funcionario, salario, data_admissao FROM funcionarios;

    -- quando o cursor chega ao fim, marca v_fim = 1
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_fim = 1;

    -- se acontecer qualquer erro: desfaz tudo
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'ERRO: nada foi gravado (ROLLBACK)' AS resultado;
    END;

    START TRANSACTION;
    OPEN cur_func;

    leitura: LOOP
        FETCH cur_func INTO v_id, v_salario, v_admissao;   -- pega o próximo

        IF v_fim = 1 THEN
            LEAVE leitura;                                  -- acabou
        END IF;

        SET v_bonus = calcular_bonus(v_salario,
                          TIMESTAMPDIFF(YEAR, v_admissao, CURDATE()));

        INSERT INTO pagamento_bonus (id_funcionario, data_pagamento, valor_bonus)
        VALUES (v_id, CURDATE(), v_bonus);

        SET v_total = v_total + 1;
    END LOOP;

    CLOSE cur_func;
    COMMIT;

    SELECT CONCAT(v_total, ' bonus registrados (COMMIT)') AS resultado;
END$$

DELIMITER ;


-- =====================================================================
-- 5. DADOS DE EXEMPLO
--    (o departamento "Vendas" fica SEM funcionários de propósito,
--     para mostrar a diferença entre os JOINs)
-- =====================================================================
INSERT INTO departamentos (nome_departamento) VALUES
    ('Recursos Humanos'),          -- id 1
    ('Tecnologia da Informação'),  -- id 2
    ('Financeiro'),                -- id 3
    ('Vendas');                    -- id 4

INSERT INTO funcionarios (nome, cargo, salario, data_admissao, id_departamento) VALUES
    ('Ana Souza',    'Gerente de RH',  9000.00, '2012-03-15', 1),
    ('Bruno Lima',   'Desenvolvedor',  7000.00, '2019-07-01', 2),
    ('Carla Mendes', 'Analista de TI', 6000.00, '2023-02-10', 2),
    ('Diego Ramos',  'Contador',       5500.00, '2016-09-20', 3),
    ('Elisa Prado',  'Analista Fin.',  4500.00, '2024-01-08', 3);


-- =====================================================================
-- 6. CONSULTAS
-- =====================================================================

-- 6.1 FUNÇÕES DE AGREGAÇÃO (um resumo da empresa inteira)
SELECT
    COUNT(*)     AS quantidade_funcionarios,
    SUM(salario) AS soma_dos_salarios,
    AVG(salario) AS media_salarial,
    MAX(salario) AS maior_salario,
    MIN(salario) AS menor_salario
FROM funcionarios;

-- 6.2 Agregação por departamento (GROUP BY)
SELECT
    d.nome_departamento,
    COUNT(f.id_funcionario) AS quantidade,
    SUM(f.salario)          AS soma_salarios,
    AVG(f.salario)          AS media_salarial
FROM departamentos d
LEFT JOIN funcionarios f ON f.id_departamento = d.id_departamento
GROUP BY d.id_departamento, d.nome_departamento;

-- 6.3 INNER JOIN: só mostra quem tem par nas DUAS tabelas
--     (funcionários com seus departamentos; "Vendas" NÃO aparece)
SELECT f.nome, f.cargo, d.nome_departamento
FROM funcionarios f
INNER JOIN departamentos d ON f.id_departamento = d.id_departamento;

-- 6.4 LEFT JOIN: tudo da tabela da ESQUERDA, mesmo sem par
--     (todos os departamentos; "Vendas" aparece com nome = NULL)
SELECT d.nome_departamento, f.nome AS funcionario
FROM departamentos d
LEFT JOIN funcionarios f ON f.id_departamento = d.id_departamento;

-- 6.5 RIGHT JOIN: tudo da tabela da DIREITA, mesmo sem par
--     (todos os funcionários; quem ainda não recebeu bônus aparece com NULL)
SELECT f.nome, p.data_pagamento, p.valor_bonus
FROM pagamento_bonus p
RIGHT JOIN funcionarios f ON p.id_funcionario = f.id_funcionario;


-- =====================================================================
-- 7. EXECUÇÃO DAS ROTINAS
-- =====================================================================

-- 7.1 CALL: chama a procedure para o funcionário 1
CALL sp_mostrar_bonus(1);

-- 7.2 CALL: procedure com CURSOR paga o bônus de todos
CALL sp_pagar_bonus_todos();

-- 7.3 Conferir os pagamentos
SELECT p.id_pagamento, f.nome, p.data_pagamento, p.valor_bonus
FROM pagamento_bonus p
INNER JOIN funcionarios f ON p.id_funcionario = f.id_funcionario;

-- 7.4 Agora o RIGHT JOIN da 6.5 mostraria todos com bônus preenchido
SELECT f.nome, p.data_pagamento, p.valor_bonus
FROM pagamento_bonus p
RIGHT JOIN funcionarios f ON p.id_funcionario = f.id_funcionario;


-- =====================================================================
-- 8. TRANSAÇÕES: SAVEPOINT, ROLLBACK, COMMIT
-- =====================================================================

-- 8.1 Reajuste em etapas, com ponto de retorno (SAVEPOINT)
START TRANSACTION;

    UPDATE funcionarios SET salario = ROUND(salario * 1.10, 2)
    WHERE id_departamento = 2;                 -- +10% em Tecnologia (certo)
    SAVEPOINT depois_da_ti;                    -- marca um ponto seguro

    UPDATE funcionarios SET salario = ROUND(salario * 2, 2)
    WHERE id_departamento = 3;                 -- +100% no Financeiro (ERRO!)

    ROLLBACK TO SAVEPOINT depois_da_ti;        -- desfaz só o erro

COMMIT;                                        -- confirma o que ficou

SELECT nome, salario FROM funcionarios;        -- só a TI foi reajustada

-- 8.2 ROLLBACK total: apaga tudo "sem querer" e volta atrás
START TRANSACTION;
    DELETE FROM pagamento_bonus;
    SELECT COUNT(*) AS pagamentos_dentro_da_transacao FROM pagamento_bonus;  -- 0
ROLLBACK;
SELECT COUNT(*) AS pagamentos_depois_do_rollback FROM pagamento_bonus;       -- 5

-- 8.3 O TRIGGER de auditoria registrou o reajuste da seção 8.1
SELECT * FROM auditoria_salario;


-- =====================================================================
-- 9. TESTES DE ERRO (opcional: descomente UM por vez para mostrar
--    as condições funcionando; cada um deve dar erro de propósito)
-- =====================================================================
-- INSERT INTO funcionarios (nome, cargo, salario, data_admissao, id_departamento)
-- VALUES ('Teste', 'Dev', -100, '2020-01-01', 1);          -- viola CHECK do salário

-- INSERT INTO funcionarios (nome, cargo, salario, data_admissao, id_departamento)
-- VALUES ('Futuro', 'Dev', 3000, '2099-01-01', 1);         -- barrado pelo TRIGGER

-- INSERT INTO departamentos (nome_departamento) VALUES ('Vendas');  -- viola UNIQUE

-- =====================================================================
-- FIM
-- =====================================================================