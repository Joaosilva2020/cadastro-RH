-- =====================================================================
--  SISTEMA RH  (MySQL 8.0.16+ | Workbench)
--  AVISO: apaga e recria o banco empresa_rh (o mesmo do .env).
--  Rode o arquivo INTEIRO de uma vez.
-- =====================================================================
DROP DATABASE IF EXISTS empresa_rh;
CREATE DATABASE empresa_rh CHARACTER SET utf8mb4;
USE empresa_rh;

-- ---------- TABELAS (NOT NULL / UNIQUE / CHECK em cada coluna) ----------
CREATE TABLE departamentos (
    id_departamento   INT AUTO_INCREMENT PRIMARY KEY,
    nome_departamento VARCHAR(100) NOT NULL UNIQUE,
    CHECK (CHAR_LENGTH(TRIM(nome_departamento)) >= 3)
);

CREATE TABLE funcionarios (
    id_funcionario  INT AUTO_INCREMENT PRIMARY KEY,
    nome            VARCHAR(150)  NOT NULL,
    cargo           VARCHAR(100)  NOT NULL,
    salario         DECIMAL(10,2) NOT NULL,
    data_admissao   DATE          NOT NULL,
    id_departamento INT           NOT NULL,
    FOREIGN KEY (id_departamento) REFERENCES departamentos(id_departamento),
    CHECK (CHAR_LENGTH(TRIM(nome)) >= 3),
    CHECK (CHAR_LENGTH(TRIM(cargo)) >= 2),
    CHECK (salario > 0)
);

CREATE TABLE pagamento_bonus (
    id_pagamento   INT AUTO_INCREMENT PRIMARY KEY,
    id_funcionario INT           NOT NULL,
    data_pagamento DATE          NOT NULL,
    valor_bonus    DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (id_funcionario) REFERENCES funcionarios(id_funcionario),
    CHECK (valor_bonus >= 0)
);

CREATE TABLE auditoria_salario (
    id_funcionario INT           NOT NULL,
    salario_antigo DECIMAL(10,2) NOT NULL,
    salario_novo   DECIMAL(10,2) NOT NULL,
    data_alteracao DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
);

-- ---------- FUNCTION, TRIGGER E PROCEDURES ----------
DELIMITER $$

-- FUNCTION: menos de 5 anos = 5% | 5 a 10 anos = 10% | mais de 10 = 15%
CREATE FUNCTION calcular_bonus(p_salario DECIMAL(10,2), p_anos INT)
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    DECLARE v_pct DECIMAL(4,2);
    IF p_anos < 5 THEN
        SET v_pct = 0.05;
    ELSEIF p_anos <= 10 THEN
        SET v_pct = 0.10;
    ELSE
        SET v_pct = 0.15;
    END IF;
    RETURN ROUND(p_salario * v_pct, 2);
END$$

-- TRIGGER: toda mudança de salário vai para a auditoria
CREATE TRIGGER trg_auditoria_salario
AFTER UPDATE ON funcionarios
FOR EACH ROW
BEGIN
    IF OLD.salario <> NEW.salario THEN
        INSERT INTO auditoria_salario (id_funcionario, salario_antigo, salario_novo)
        VALUES (NEW.id_funcionario, OLD.salario, NEW.salario);
    END IF;
END$$

-- PROCEDURE: bônus de um funcionário
CREATE PROCEDURE sp_mostrar_bonus(IN p_id INT)
BEGIN
    SELECT nome, salario,
           TIMESTAMPDIFF(YEAR, data_admissao, CURDATE()) AS anos,
           calcular_bonus(salario, TIMESTAMPDIFF(YEAR, data_admissao, CURDATE())) AS bonus
    FROM funcionarios
    WHERE id_funcionario = p_id;
END$$

-- PROCEDURE com CURSOR: paga o bônus de todos. Erro = ROLLBACK, certo = COMMIT
CREATE PROCEDURE sp_pagar_bonus_todos()
BEGIN
    DECLARE v_id  INT;
    DECLARE v_sal DECIMAL(10,2);
    DECLARE v_dt  DATE;
    DECLARE v_fim INT DEFAULT 0;
    DECLARE cur CURSOR FOR
        SELECT id_funcionario, salario, data_admissao FROM funcionarios;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET v_fim = 1;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SELECT 'ERRO: nada foi gravado (ROLLBACK)' AS resultado;
    END;

    START TRANSACTION;
    OPEN cur;
    leitura: LOOP
        FETCH cur INTO v_id, v_sal, v_dt;
        IF v_fim = 1 THEN
            LEAVE leitura;
        END IF;
        INSERT INTO pagamento_bonus (id_funcionario, data_pagamento, valor_bonus)
        VALUES (v_id, CURDATE(), calcular_bonus(v_sal, TIMESTAMPDIFF(YEAR, v_dt, CURDATE())));
    END LOOP;
    CLOSE cur;
    COMMIT;
    SELECT 'Bonus pagos (COMMIT)' AS resultado;
END$$

DELIMITER ;

-- ---------- VIEW (usada pela tela do sistema) ----------
CREATE VIEW vw_bonus_funcionarios AS
SELECT f.id_funcionario, f.nome, f.cargo,
       d.nome_departamento AS departamento,
       f.salario, f.data_admissao,
       TIMESTAMPDIFF(YEAR, f.data_admissao, CURDATE()) AS anos_de_servico,
       calcular_bonus(f.salario, TIMESTAMPDIFF(YEAR, f.data_admissao, CURDATE())) AS bonus_previsto
FROM funcionarios f
INNER JOIN departamentos d ON f.id_departamento = d.id_departamento;

-- ---------- DADOS DE EXEMPLO (Vendas fica sem funcionário de propósito) ----------
INSERT INTO departamentos (nome_departamento) VALUES
    ('Recursos Humanos'), ('Tecnologia da Informação'), ('Financeiro'), ('Vendas');

INSERT INTO funcionarios (nome, cargo, salario, data_admissao, id_departamento) VALUES
    ('Ana Souza',    'Gerente de RH',  9000.00, '2012-03-15', 1),
    ('Bruno Lima',   'Desenvolvedor',  7000.00, '2019-07-01', 2),
    ('Carla Mendes', 'Analista de TI', 6000.00, '2023-02-10', 2),
    ('Diego Ramos',  'Contador',       5500.00, '2016-09-20', 3);

-- ---------- AGREGAÇÃO: COUNT, SUM, AVG, MAX, MIN ----------
SELECT COUNT(*) AS qtd, SUM(salario) AS soma, AVG(salario) AS media,
       MAX(salario) AS maior, MIN(salario) AS menor
FROM funcionarios;

SELECT d.nome_departamento, COUNT(f.id_funcionario) AS qtd, SUM(f.salario) AS soma
FROM departamentos d
LEFT JOIN funcionarios f ON f.id_departamento = d.id_departamento
GROUP BY d.id_departamento, d.nome_departamento;

-- ---------- OS 3 JOINs ----------
-- INNER: só quem tem par nas duas tabelas (Vendas não aparece)
SELECT f.nome, d.nome_departamento
FROM funcionarios f
INNER JOIN departamentos d ON f.id_departamento = d.id_departamento;

-- LEFT: todos os departamentos (Vendas aparece com NULL)
SELECT d.nome_departamento, f.nome
FROM departamentos d
LEFT JOIN funcionarios f ON f.id_departamento = d.id_departamento;

-- RIGHT: mesma ideia ao contrário (a tabela da direita manda)
SELECT f.nome, d.nome_departamento
FROM funcionarios f
RIGHT JOIN departamentos d ON f.id_departamento = d.id_departamento;

-- ---------- CALL ----------
CALL sp_mostrar_bonus(1);
-- CALL sp_pagar_bonus_todos();   -- (cursor) descomente na apresentação

-- ---------- TRANSAÇÕES: SAVEPOINT, ROLLBACK, COMMIT ----------
START TRANSACTION;
    UPDATE funcionarios SET salario = salario + 500 WHERE id_funcionario = 1;  -- certo
    SAVEPOINT p1;
    UPDATE funcionarios SET salario = 1 WHERE id_funcionario = 1;              -- erro!
    ROLLBACK TO SAVEPOINT p1;                                                  -- desfaz só o erro
COMMIT;
SELECT nome, salario FROM funcionarios WHERE id_funcionario = 1;              -- 9500

START TRANSACTION;
    DELETE FROM funcionarios WHERE id_funcionario = 4;                         -- apaga "sem querer"
    SELECT COUNT(*) AS dentro_da_transacao FROM funcionarios;                  -- 3
ROLLBACK;                                                                      -- volta atrás
SELECT COUNT(*) AS depois_do_rollback FROM funcionarios;                       -- 4

SELECT * FROM auditoria_salario;                                               -- trigger: 9000 -> 9500
