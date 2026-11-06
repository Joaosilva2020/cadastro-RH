const $ = (id) => document.getElementById(id);
const form = $("form-funcionario");
const lista = $("lista-funcionarios");
const pagamentos = $("lista-pagamentos");
const mensagem = $("mensagem");

function avisar(texto, tipo = "") {
  mensagem.textContent = texto;
  mensagem.className = tipo;
}
function dinheiro(valor) {
  return Number(valor).toLocaleString("pt-BR", { style: "currency", currency: "BRL" });
}
function dataBR(data) {
  if (!data) return "-";
  const partes = String(data).slice(0, 10).split("-");
  return partes.length === 3 ? `${partes[2]}/${partes[1]}/${partes[0]}` : data;
}

async function carregarDepartamentos() {
  const resposta = await fetch("/api/departamentos");
  const dados = await resposta.json();
  if (!resposta.ok) throw new Error(dados.erro);
  $("departamento").innerHTML = '<option value="">Selecione um departamento</option>';
  dados.forEach(d => {
    const option = document.createElement("option");
    option.value = d.id_departamento;
    option.textContent = d.nome_departamento;
    $("departamento").appendChild(option);
  });
}

async function carregarFuncionarios() {
  try {
    const resposta = await fetch("/api/funcionarios");
    const pessoas = await resposta.json();
    if (!resposta.ok) throw new Error(pessoas.erro);
    lista.innerHTML = "";
    if (!pessoas.length) {
      lista.innerHTML = '<tr><td colspan="7" class="vazio">Nenhum funcionário cadastrado.</td></tr>';
      return;
    }
    pessoas.forEach(p => {
      const tr = document.createElement("tr");
      [p.nome, p.cargo, p.departamento, dinheiro(p.salario), p.anos_de_servico, dinheiro(p.bonus_previsto)].forEach(v => {
        const td = document.createElement("td"); td.textContent = v; tr.appendChild(td);
      });
      const td = document.createElement("td");
      const editar = document.createElement("button");
      editar.textContent = "Editar"; editar.className = "editar";
      editar.addEventListener("click", () => editarFuncionario(p));
      const bonus = document.createElement("button");
      bonus.textContent = "Gerar bônus"; bonus.className = "bonus";
      bonus.addEventListener("click", () => gerarBonus(p.id_funcionario, p.nome));
      const excluir = document.createElement("button");
      excluir.textContent = "Excluir"; excluir.className = "excluir";
      excluir.addEventListener("click", () => excluirFuncionario(p.id_funcionario, p.nome));
      td.append(editar, bonus, excluir); tr.appendChild(td); lista.appendChild(tr);
    });
  } catch (e) {
    lista.innerHTML = '<tr><td colspan="7" class="vazio">Erro ao carregar funcionários.</td></tr>';
    avisar(e.message, "erro");
  }
}

async function carregarPagamentos() {
  try {
    const resposta = await fetch("/api/pagamentos");
    const dados = await resposta.json();
    if (!resposta.ok) throw new Error(dados.erro);
    pagamentos.innerHTML = "";
    if (!dados.length) {
      pagamentos.innerHTML = '<tr><td colspan="4" class="vazio">Nenhum bônus registrado ainda.</td></tr>';
      return;
    }
    dados.forEach(p => {
      const tr = document.createElement("tr");
      [p.id_pagamento, p.funcionario, dataBR(p.data_pagamento), dinheiro(p.valor_bonus)].forEach(v => {
        const td = document.createElement("td"); td.textContent = v; tr.appendChild(td);
      });
      pagamentos.appendChild(tr);
    });
  } catch (e) {
    pagamentos.innerHTML = '<tr><td colspan="4" class="vazio">Erro ao carregar pagamentos.</td></tr>';
  }
}

function editarFuncionario(p) {
  $("id-funcionario").value = p.id_funcionario;
  $("nome").value = p.nome;
  $("cargo").value = p.cargo;
  $("salario").value = p.salario;
  $("data-admissao").value = String(p.data_admissao).slice(0, 10);
  $("departamento").value = p.id_departamento;
  $("titulo-form").textContent = "Editar funcionário";
  $("btn-salvar").textContent = "Salvar alterações";
  $("btn-cancelar").classList.remove("oculto");
  $("nome").focus();
}

function limparFormulario() {
  form.reset();
  $("id-funcionario").value = "";
  $("titulo-form").textContent = "Cadastrar funcionário";
  $("btn-salvar").textContent = "Cadastrar funcionário";
  $("btn-cancelar").classList.add("oculto");
}

form.addEventListener("submit", async (e) => {
  e.preventDefault();
  const id = $("id-funcionario").value;
  const dados = {
    nome: $("nome").value,
    cargo: $("cargo").value,
    salario: $("salario").value,
    data_admissao: $("data-admissao").value,
    id_departamento: $("departamento").value
  };
  const botao = $("btn-salvar");
  botao.disabled = true;
  try {
    const resposta = await fetch(id ? `/api/funcionarios/${id}` : "/api/funcionarios", {
      method: id ? "PUT" : "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify(dados)
    });
    const retorno = await resposta.json();
    if (!resposta.ok) throw new Error(retorno.erro);
    limparFormulario();
    avisar(retorno.mensagem, "sucesso");
    await carregarFuncionarios();
  } catch (e) { avisar(e.message, "erro"); }
  finally { botao.disabled = false; }
});

async function gerarBonus(id, nome) {
  if (!confirm(`Registrar o bônus de ${nome}?`)) return;
  try {
    const resposta = await fetch(`/api/bonus/${id}`, { method: "POST" });
    const dados = await resposta.json();
    if (!resposta.ok) throw new Error(dados.erro);
    avisar(dados.mensagem, "sucesso");
    await carregarPagamentos();
  } catch (e) { avisar(e.message, "erro"); }
}

async function excluirFuncionario(id, nome) {
  if (!confirm(`Excluir ${nome}? Se houver pagamento registrado, o banco impedirá a exclusão.`)) return;
  try {
    const resposta = await fetch(`/api/funcionarios/${id}`, { method: "DELETE" });
    const dados = await resposta.json();
    if (!resposta.ok) throw new Error(dados.erro);
    avisar(dados.mensagem, "sucesso");
    await carregarFuncionarios();
  } catch (e) { avisar(e.message, "erro"); }
}

$("btn-cancelar").addEventListener("click", limparFormulario);
$("btn-atualizar").addEventListener("click", async () => {
  await carregarFuncionarios(); await carregarPagamentos();
});

(async function iniciar() {
  try {
    await carregarDepartamentos();
    await carregarFuncionarios();
    await carregarPagamentos();
  } catch (e) {
    avisar("Não foi possível conectar. Confira a configuração do MySQL e execute database.sql.", "erro");
  }
})();