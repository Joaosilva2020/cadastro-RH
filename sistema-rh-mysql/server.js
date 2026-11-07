require("dotenv").config();
const express = require("express");
const path = require("path");
const mysql = require("mysql2/promise");
const cors = require("cors");

const app = express();
const port = Number(process.env.PORT || 3000);

const allowedOrigins = (process.env.CORS_ORIGIN || "")
  .split(",")
  .map((origin) => origin.trim())
  .filter(Boolean);

if (allowedOrigins.length) app.use(cors({ origin: allowedOrigins }));
app.use(express.json());
app.use(express.static(path.join(__dirname, "public")));

const dbConfigMissing = ["DB_HOST", "DB_NAME", "DB_USER", "DB_PASSWORD"]
  .filter((key) => !process.env[key]);
const db = dbConfigMissing.length ? null : mysql.createPool({
  host: process.env.DB_HOST,
  port: Number(process.env.DB_PORT || 3306),
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  ...(process.env.DB_SSL === "true" ? { ssl: {} } : {}),
  waitForConnections: true,
  connectionLimit: 10,
  connectTimeout: 10000,
  dateStrings: true
});

app.use("/api", (req, res, next) => {
  if (db || req.path === "/health") return next();
  res.status(503).json({
    erro: "O MySQL ainda não está configurado no servidor.",
    missing: dbConfigMissing
  });
});

// Diagnóstico: separa falha do servidor de falha na conexão com o MySQL.
app.get("/api/health", async (_req, res) => {
  if (!db) {
    return res.status(503).json({
      status: "error",
      database: "not_configured",
      missing: dbConfigMissing
    });
  }
  try {
    await db.query("SELECT 1");
    res.json({ status: "ok", database: "connected" });
  } catch (error) {
    console.error("Falha no teste de conexão MySQL:", error.code || error.message);
    res.status(503).json({
      status: "error",
      database: "disconnected",
      code: error.code || "DB_CONNECTION_ERROR"
    });
  }
});

app.get("/api/departamentos", async (_req, res) => {
  try {
    const [rows] = await db.query("SELECT * FROM departamentos ORDER BY nome_departamento");
    res.json(rows);
  } catch (error) {
    const code = error.code || "DB_QUERY_ERROR";
    console.error("Erro ao buscar departamentos:", code);
    res.status(500).json({
      erro: code === "ENOTFOUND"
        ? "O endereço MySQL em DB_HOST não foi encontrado. Confira o host configurado."
        : "Erro ao buscar departamentos. Confira a conexão, o usuário e o banco.",
      code
    });
  }
});

app.get("/api/funcionarios", async (_req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT f.id_funcionario, f.nome, f.cargo, f.salario,
             DATE_FORMAT(f.data_admissao, '%Y-%m-%d') AS data_admissao,
             f.id_departamento, d.nome_departamento AS departamento,
             TIMESTAMPDIFF(YEAR, f.data_admissao, CURDATE()) AS anos_de_servico,
             CASE
               WHEN TIMESTAMPDIFF(YEAR, f.data_admissao, CURDATE()) < 5 THEN f.salario * 0.05
               WHEN TIMESTAMPDIFF(YEAR, f.data_admissao, CURDATE()) <= 10 THEN f.salario * 0.10
               ELSE f.salario * 0.15
             END AS bonus_previsto
      FROM funcionarios AS f
      INNER JOIN departamentos AS d ON f.id_departamento = d.id_departamento
      ORDER BY f.id_funcionario DESC
    `);
    res.json(rows);
  } catch (error) {
    console.error("Erro ao listar funcionários:", error.code || error.message);
    res.status(500).json({ erro: "Erro ao listar funcionários. Verifique se o schema database.sql foi criado." });
  }
});

app.post("/api/funcionarios", async (req, res) => {
  const { nome, cargo, salario, data_admissao, id_departamento } = req.body;
  if (!nome || !cargo || !salario || !data_admissao || !id_departamento || Number(salario) <= 0) {
    return res.status(400).json({ erro: "Preencha todos os campos com valores válidos." });
  }
  try {
    const [result] = await db.execute(
      "INSERT INTO funcionarios (nome, cargo, salario, data_admissao, id_departamento) VALUES (?, ?, ?, ?, ?)",
      [nome.trim(), cargo.trim(), salario, data_admissao, id_departamento]
    );
    res.status(201).json({ mensagem: "Funcionário cadastrado.", id: result.insertId });
  } catch (error) {
    console.error("Erro ao cadastrar funcionário:", error.code || error.message);
    res.status(500).json({ erro: "Não foi possível cadastrar o funcionário." });
  }
});

app.put("/api/funcionarios/:id", async (req, res) => {
  const { nome, cargo, salario, data_admissao, id_departamento } = req.body;
  if (!nome || !cargo || !salario || !data_admissao || !id_departamento || Number(salario) <= 0) {
    return res.status(400).json({ erro: "Preencha todos os campos com valores válidos." });
  }
  try {
    const [result] = await db.execute(
      "UPDATE funcionarios SET nome=?, cargo=?, salario=?, data_admissao=?, id_departamento=? WHERE id_funcionario=?",
      [nome.trim(), cargo.trim(), salario, data_admissao, id_departamento, req.params.id]
    );
    if (!result.affectedRows) return res.status(404).json({ erro: "Funcionário não encontrado." });
    res.json({ mensagem: "Funcionário atualizado." });
  } catch (error) {
    console.error("Erro ao atualizar funcionário:", error.code || error.message);
    res.status(500).json({ erro: "Não foi possível atualizar." });
  }
});

app.delete("/api/funcionarios/:id", async (req, res) => {
  try {
    const [result] = await db.execute(
      "DELETE FROM funcionarios WHERE id_funcionario = ?",
      [req.params.id]
    );
    if (!result.affectedRows) return res.status(404).json({ erro: "Funcionário não encontrado." });
    res.json({ mensagem: "Funcionário excluído." });
  } catch (error) {
    if (error.code === "ER_ROW_IS_REFERENCED_2") {
      return res.status(409).json({ erro: "Esse funcionário já tem pagamentos registrados e não pode ser excluído." });
    }
    console.error("Erro ao excluir funcionário:", error.code || error.message);
    res.status(500).json({ erro: "Não foi possível excluir." });
  }
});

app.post("/api/bonus/:id", async (req, res) => {
  try {
    const [result] = await db.execute(`
      INSERT INTO pagamento_bonus (id_funcionario, data_pagamento, valor_bonus)
      SELECT f.id_funcionario, CURDATE(),
             CASE
               WHEN TIMESTAMPDIFF(YEAR, f.data_admissao, CURDATE()) < 5 THEN f.salario * 0.05
               WHEN TIMESTAMPDIFF(YEAR, f.data_admissao, CURDATE()) <= 10 THEN f.salario * 0.10
               ELSE f.salario * 0.15
             END
      FROM funcionarios AS f
      WHERE f.id_funcionario = ?
    `, [req.params.id]);
    if (!result.affectedRows) return res.status(404).json({ erro: "Funcionário não encontrado." });
    res.json({ mensagem: "Bônus registrado com sucesso." });
  } catch (error) {
    console.error("Erro ao gerar bônus:", error.code || error.message);
    res.status(500).json({ erro: "Não foi possível registrar o bônus." });
  }
});

app.get("/api/pagamentos", async (_req, res) => {
  try {
    const [rows] = await db.query(`
      SELECT p.id_pagamento, f.nome AS funcionario, p.data_pagamento, p.valor_bonus
      FROM pagamento_bonus AS p
      INNER JOIN funcionarios AS f ON p.id_funcionario = f.id_funcionario
      ORDER BY p.id_pagamento DESC
    `);
    res.json(rows);
  } catch (error) {
    console.error("Erro ao consultar pagamentos:", error.code || error.message);
    res.status(500).json({ erro: "Erro ao consultar pagamentos." });
  }
});

app.listen(port, "0.0.0.0", () => {
  console.log(`Sistema RH iniciado na porta ${port}`);
});
