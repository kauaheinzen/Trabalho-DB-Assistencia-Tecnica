CREATE DATABASE IF NOT EXISTS assistencia_tecnica;
USE assistencia_tecnica;

-- ========
-- TABLES 
-- ========

CREATE TABLE IF NOT EXISTS cliente(
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    telefone VARCHAR(15),
    endereco VARCHAR(255)
);

CREATE TABLE IF NOT EXISTS funcionario(
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    cargo VARCHAR(50),
    email VARCHAR(100) UNIQUE NOT NULL,
    telefone VARCHAR(15)
);

CREATE TABLE IF NOT EXISTS peca(
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    descricao TEXT,
    quantidade_estoque INT NOT NULL DEFAULT 0 CHECK (quantidade_estoque >= 0),
    preco DECIMAL(10, 2) NOT NULL
);

CREATE TABLE IF NOT EXISTS equipamento(
    id INT AUTO_INCREMENT PRIMARY KEY,
    nome VARCHAR(100) NOT NULL,
    modelo VARCHAR(50),
    fabricante VARCHAR(100),
    ano_fabricacao YEAR
);

CREATE TABLE IF NOT EXISTS ordem_servico(
    id INT AUTO_INCREMENT PRIMARY KEY,
    cliente_id INT NOT NULL,
    funcionario_id INT NOT NULL,
    equipamento_id INT NOT NULL,
    data_abertura DATETIME DEFAULT CURRENT_TIMESTAMP,
    data_fechamento DATETIME NULL,
    status ENUM('aberta', 'em andamento', 'fechada', 'cancelada') DEFAULT 'aberta',
    FOREIGN KEY (cliente_id) REFERENCES cliente(id),
    FOREIGN KEY (funcionario_id) REFERENCES funcionario(id),
    FOREIGN KEY (equipamento_id) REFERENCES equipamento(id)
);

CREATE TABLE IF NOT EXISTS ordem_servico_peca(
    ordem_servico_id INT NOT NULL,
    peca_id INT NOT NULL,
    quantidade INT NOT NULL CHECK (quantidade > 0),
    PRIMARY KEY (ordem_servico_id, peca_id),
    FOREIGN KEY (ordem_servico_id) REFERENCES ordem_servico(id),
    FOREIGN KEY (peca_id) REFERENCES peca(id)
);

CREATE TABLE IF NOT EXISTS pagamento(
    id INT AUTO_INCREMENT PRIMARY KEY,
    ordem_servico_id INT NOT NULL,
    valor DECIMAL(10, 2) NOT NULL CHECK (valor >= 0),
    data_pagamento DATETIME DEFAULT CURRENT_TIMESTAMP,
    metodo_pagamento ENUM('dinheiro', 'cartao', 'pix') NOT NULL,
    situacao ENUM('pendente', 'pago', 'cancelado') DEFAULT 'pendente',
    FOREIGN KEY (ordem_servico_id) REFERENCES ordem_servico(id)
);

-- ============
-- PROCEDURES 
-- ============

DELIMITER $$
CREATE PROCEDURE inserir_cliente(
    IN p_nome VARCHAR(100),
    IN p_email VARCHAR(100),
    IN p_telefone VARCHAR(15),
    IN p_endereco VARCHAR(255)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM cliente WHERE email = p_email) THEN
        INSERT INTO cliente (nome, email, telefone, endereco)
        VALUES (p_nome, p_email, p_telefone, p_endereco);
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cliente com este email já existe.';
    END IF;

END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE inserir_funcionario(
    IN p_nome VARCHAR(100),
    IN p_cargo VARCHAR(50),
    IN p_email VARCHAR(100),
    IN p_telefone VARCHAR(15)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM funcionario WHERE email = p_email) THEN
        INSERT INTO funcionario (nome, cargo, email, telefone)
        VALUES (p_nome, p_cargo, p_email, p_telefone);
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Funcionário com este email já existe.';
    END IF;

END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE inserir_peca(
    IN p_nome VARCHAR(100),
    IN p_descricao TEXT,
    IN p_preco DECIMAL(10, 2)
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM peca WHERE nome = p_nome) THEN
        INSERT INTO peca (nome, descricao, preco)
        VALUES (p_nome, p_descricao, p_preco);
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Peça com este nome já existe.';
    END IF;

END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE inserir_equipamento(
    IN p_nome VARCHAR(100),
    IN p_modelo VARCHAR(50),
    IN p_fabricante VARCHAR(100),
    IN p_ano_fabricacao YEAR
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM equipamento WHERE nome = p_nome AND modelo = p_modelo) THEN
        INSERT INTO equipamento (nome, modelo, fabricante, ano_fabricacao)
        VALUES (p_nome, p_modelo, p_fabricante, p_ano_fabricacao);
    ELSE
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Equipamento com este nome e modelo já existe.';
    END IF;

END$$
DELIMITER ; 

DELIMITER $$
CREATE PROCEDURE inserir_ordem_servico(
    IN p_cliente_id INT,
    IN p_funcionario_id INT,
    IN p_equipamento_id INT,
    IN p_status ENUM('aberta', 'em andamento', 'fechada', 'cancelada')
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM cliente WHERE id = p_cliente_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Cliente não encontrado.';
    END IF;
    
    IF NOT EXISTS (SELECT 1 FROM funcionario WHERE id = p_funcionario_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Funcionário não encontrado.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM equipamento WHERE id = p_equipamento_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Equipamento não encontrado.';
    END IF;

    INSERT INTO ordem_servico (cliente_id, funcionario_id, equipamento_id, status)
    VALUES (p_cliente_id, p_funcionario_id, p_equipamento_id, p_status);

END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE mudar_status_ordem_servico(
    IN p_ordem_servico_id INT,
    IN p_novo_status ENUM('aberta', 'em andamento', 'fechada', 'cancelada')
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM ordem_servico WHERE id = p_ordem_servico_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ordem de serviço não encontrada.';
    END IF;

    UPDATE ordem_servico SET status = p_novo_status WHERE id = p_ordem_servico_id;
END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE inserir_ordem_servico_peca(
    IN p_ordem_servico_id INT,
    IN p_peca_id INT,
    IN p_quantidade INT
)
BEGIN
    IF p_quantidade <= 0 or (SELECT quantidade_estoque FROM peca WHERE id = p_peca_id) < p_quantidade THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Quantidade deve ser maior que zero e menor ou igual ao estoque disponível.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM ordem_servico WHERE id = p_ordem_servico_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ordem de serviço não encontrada.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM peca WHERE id = p_peca_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Peça não encontrada.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM ordem_servico_peca WHERE ordem_servico_id = p_ordem_servico_id AND peca_id = p_peca_id) THEN
        INSERT INTO ordem_servico_peca (ordem_servico_id, peca_id, quantidade) VALUES (p_ordem_servico_id, p_peca_id, p_quantidade);
        UPDATE peca SET quantidade_estoque = quantidade_estoque - p_quantidade WHERE id = p_peca_id;
    ELSE
        UPDATE ordem_servico_peca SET quantidade = quantidade + p_quantidade WHERE ordem_servico_id = p_ordem_servico_id AND peca_id = p_peca_id;
    END IF;

END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE inserir_pagamento(
    IN p_ordem_servico_id INT,
    IN p_valor DECIMAL(10, 2),
    IN p_metodo_pagamento ENUM('dinheiro', 'cartao', 'pix'),
    IN p_situacao ENUM('pendente', 'pago', 'cancelado')
)
BEGIN
    IF p_valor < 0 THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Valor do pagamento não pode ser negativo.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM ordem_servico WHERE id = p_ordem_servico_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Ordem de serviço não encontrada.';
    END IF;

    INSERT INTO pagamento (ordem_servico_id, valor, metodo_pagamento, situacao)
    VALUES (p_ordem_servico_id, p_valor, p_metodo_pagamento, p_situacao);
END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE mudar_status_pagamento(
    IN p_pagamento_id INT,
    IN p_nova_situacao ENUM('pendente', 'pago', 'cancelado')
)
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pagamento WHERE id = p_pagamento_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Pagamento não encontrado.';
    END IF;

    UPDATE pagamento SET situacao = p_nova_situacao WHERE id = p_pagamento_id;
END$$
DELIMITER ;