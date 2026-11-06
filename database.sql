-- SISTEMA DE RECURSOS HUMANOS - MYSQL
-- Execute este arquivo no MySQL Workbench ou no phpMyAdmin.

CREATE DATABASE IF NOT EXISTS empresa_rh;
USE empresa_rh;

-- 1. TABELA DEPARTAMENTOS
CREATE TABLE IF NOT EXISTS departamentos (
    id_departamento INT AUTO_INCREMENT PRIMARY KEY,
    nome_departamento VARCHAR(100) NOT NULL
);

-- 2. TABELA FUNCIONARIOS
CREATE TABLE IF NOT EXISTS funcionarios (
    id_funcionario INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(150) NOT NULL,
    cargo VARCHAR(100) NOT NULL,
    salario DECIMAL(10,2) NOT NULL,
    data_admissao DATE NOT NULL,
    id_departamento INT NOT NULL,
    FOREIGN KEY (id_departamento)
        REFERENCES departamentos(id_departamento)
);

-- 3. TABELA DE PAGAMENTO DE BONUS
CREATE TABLE IF NOT EXISTS pagamento_bonus (
    id_pagamento INT AUTO_INCREMENT PRIMARY KEY,
    id_funcionario INT NOT NULL,
    data_pagamento DATE NOT NULL,
    valor_bonus DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (id_funcionario)
        REFERENCES funcionarios(id_funcionario)
);

-- 4. DADOS INICIAIS
INSERT INTO departamentos (nome_departamento) VALUES
('Recursos Humanos'),
('Tecnologia da Informação'),
('Financeiro'),
('Vendas');

INSERT INTO funcionarios
(nome, cargo, salario, data_admissao, id_departamento) VALUES
('Ana Souza', 'Analista de RH', 3000.00, '2024-01-15', 1),
('Carlos Lima', 'Desenvolvedor', 5000.00, '2018-03-10', 2),
('Mariana Alves', 'Assistente Financeiro', 2800.00, '2019-06-20', 3),
('Pedro Santos', 'Vendedor', 3500.00, '2012-02-01', 4);

-- 5. FUNCTION: calcula o bonus e devolve o valor
DROP FUNCTION IF EXISTS calcular_bonus;
DELIMITER $$
CREATE FUNCTION calcular_bonus(
    p_salario DECIMAL(10,2),
    p_anos_de_servico INT
)
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    DECLARE v_bonus DECIMAL(10,2);

    IF p_anos_de_servico < 5 THEN
        SET v_bonus = p_salario * 0.05;
    ELSEIF p_anos_de_servico <= 10 THEN
        SET v_bonus = p_salario * 0.10;
    ELSE
        SET v_bonus = p_salario * 0.15;
    END IF;

    RETURN v_bonus;
END $$
DELIMITER ;

-- 6. PROCEDURE: registra o bonus de um funcionário
DROP PROCEDURE IF EXISTS gerar_bonus;
DELIMITER $$
CREATE PROCEDURE gerar_bonus(IN p_id_funcionario INT)
BEGIN
    INSERT INTO pagamento_bonus (id_funcionario, data_pagamento, valor_bonus)
    SELECT
        id_funcionario,
        CURDATE(),
        calcular_bonus(
            salario,
            TIMESTAMPDIFF(YEAR, data_admissao, CURDATE())
        )
    FROM funcionarios
    WHERE id_funcionario = p_id_funcionario;
END $$
DELIMITER ;

-- 7. VIEW: relatório com funcionário e departamento
CREATE OR REPLACE VIEW vw_bonus_funcionarios AS
SELECT
    f.id_funcionario,
    f.nome,
    f.cargo,
    d.nome_departamento AS departamento,
    f.salario,
    f.data_admissao,
    TIMESTAMPDIFF(YEAR, f.data_admissao, CURDATE()) AS anos_de_servico,
    calcular_bonus(
        f.salario,
        TIMESTAMPDIFF(YEAR, f.data_admissao, CURDATE())
    ) AS bonus_previsto
FROM funcionarios AS f
INNER JOIN departamentos AS d
    ON f.id_departamento = d.id_departamento;

-- 8. CONSULTAS PARA DEMONSTRAR OS COMANDOS
SELECT * FROM departamentos;
SELECT * FROM funcionarios;
SELECT * FROM funcionarios WHERE id_departamento = 2;
SELECT calcular_bonus(5000.00, 3) AS bonus_de_exemplo;
SELECT * FROM vw_bonus_funcionarios;

-- Para registrar um pagamento, execute uma chamada por funcionário:
-- CALL gerar_bonus(1);
-- CALL gerar_bonus(2);

-- Para consultar pagamentos que já foram registrados:
SELECT
    p.id_pagamento,
    f.nome AS funcionario,
    p.data_pagamento,
    p.valor_bonus
FROM pagamento_bonus AS p
INNER JOIN funcionarios AS f
    ON p.id_funcionario = f.id_funcionario;
