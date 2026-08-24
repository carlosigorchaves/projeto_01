-- ============================================================
-- Controle de Gastos - Se Liga Instituto Social
-- Schema para Supabase (Postgres)
-- Rode isso inteiro no SQL Editor do seu projeto Supabase.
-- ============================================================

-- ---------- Perfis (ligados ao login do Supabase Auth) ----------
create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  email text not null,
  role text not null default 'user'   -- 'admin' | 'user' | 'revoked'
);

-- ---------- Contratos ----------
create table if not exists public.contracts (
  id text primary key,
  name text not null,
  active boolean not null default true,
  valid_until date
);

-- ---------- Categorias do Anexo V (por contrato) ----------
create table if not exists public.categories (
  id bigserial primary key,
  contract_id text not null,
  code int not null,
  name text not null,
  manual_limit numeric(14,2) not null default 0
);

-- ---------- Itens do Anexo V ----------
create table if not exists public.items (
  id bigserial primary key,
  contract_id text not null,
  category_code int not null,
  item_code text not null,
  name text not null,
  limit_value numeric(14,2) not null default 0
);

-- ---------- Lançamentos (entradas e saídas) ----------
create table if not exists public.transactions (
  id bigserial primary key,
  contract_id text not null,
  tx_date date not null,
  value numeric(14,2) not null,
  description text not null,
  direction text not null,          -- 'ENTRADA' ou 'SAIDA'
  label text,
  code text,
  manual_cat int,
  cat int,
  created_by text,
  created_at timestamptz not null default now()
);

-- ---------- Nomenclatura (tabela de-para de códigos) ----------
create table if not exists public.nomenclature (
  id bigserial primary key,
  from_code text not null,
  to_code text not null
);

-- ============================================================
-- Perfil automático + primeiro usuário vira administrador
-- ============================================================
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, name, email, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', split_part(new.email, '@', 1)),
    new.email,
    case when (select count(*) from public.profiles) = 0 then 'admin' else 'user' end
  );
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();

-- ============================================================
-- Função auxiliar para checar se o usuário logado é admin
-- (security definer evita recursão infinita nas policies)
-- ============================================================
create or replace function public.is_admin()
returns boolean
language sql
security definer set search_path = public
as $$
  select coalesce((select role from public.profiles where id = auth.uid()) = 'admin', false);
$$;

-- ============================================================
-- Row Level Security
-- ============================================================
alter table public.profiles enable row level security;
alter table public.contracts enable row level security;
alter table public.categories enable row level security;
alter table public.items enable row level security;
alter table public.transactions enable row level security;
alter table public.nomenclature enable row level security;

-- profiles: qualquer pessoa logada pode ver a lista (tela de Usuários);
-- só admin pode alterar o role de alguém.
drop policy if exists "profiles_select" on public.profiles;
create policy "profiles_select" on public.profiles for select
  using (auth.role() = 'authenticated');

drop policy if exists "profiles_update_admin_only" on public.profiles;
create policy "profiles_update_admin_only" on public.profiles for update
  using (public.is_admin());

-- demais tabelas: qualquer pessoa autenticada e não revogada pode ler/gravar
-- (é um sistema de uso interno em equipe, não multiempresa)
drop policy if exists "contracts_all" on public.contracts;
create policy "contracts_all" on public.contracts for all
  using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

drop policy if exists "categories_all" on public.categories;
create policy "categories_all" on public.categories for all
  using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

drop policy if exists "items_all" on public.items;
create policy "items_all" on public.items for all
  using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

drop policy if exists "transactions_all" on public.transactions;
create policy "transactions_all" on public.transactions for all
  using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

drop policy if exists "nomenclature_all" on public.nomenclature;
create policy "nomenclature_all" on public.nomenclature for all
  using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- ============================================================
-- Dados iniciais (Instituto Bahia completo + 44 unidades vazias)
-- ============================================================
insert into public.contracts (id, name, active, valid_until) values
('instituto-bahia', 'Instituto Bahia', true, NULL),
('cethid', 'CETHID', true, NULL),
('colegio-militar-de-brasilia', 'COLEGIO MILITAR DE BRASILIA', true, NULL),
('colegio-pedro-ii-cpo-centro', 'COLEGIO PEDRO II - CPO CENTRO', true, NULL),
('colegio-pedro-ii-cpo-engenho-novo-i', 'COLEGIO PEDRO II - CPO ENGENHO NOVO I', true, NULL),
('colegio-pedro-ii-cpo-engenho-novo-ii', 'COLEGIO PEDRO II - CPO ENGENHO NOVO II', true, NULL),
('colegio-pedro-ii-cpo-reitoria', 'COLEGIO PEDRO II - CPO REITORIA', true, NULL),
('colegio-pedro-ii-cpo-sao-cristovao-i', 'COLEGIO PEDRO II - CPO SAO CRISTOVAO I', true, NULL),
('colegio-pedro-ii-cpo-sao-cristovao-ii', 'COLEGIO PEDRO II - CPO SAO CRISTOVAO II', true, NULL),
('colegio-pedro-ii-cpo-sao-cristovao-iii', 'COLEGIO PEDRO II - CPO SAO CRISTOVAO III', true, NULL),
('comando-da-aeronautica-gap-rj', 'COMANDO DA AERONAUTICA - GAP/RJ', true, NULL),
('comando-da-aeronautica-hca', 'COMANDO DA AERONAUTICA - HCA', true, NULL),
('ebserh-huap-apoio-administrativo', 'EBSERH HUAP - APOIO ADMINISTRATIVO', true, NULL),
('ebserh-huap-recepcao', 'EBSERH HUAP - RECEPÇAO', true, NULL),
('escola-superior-de-defesa', 'ESCOLA SUPERIOR DE DEFESA', true, NULL),
('fundacao-oswaldo-cruz-esnp-fiocruz', 'FUNDAÇAO OSWALDO CRUZ - ESNP/FIOCRUZ', true, NULL),
('fundacao-teatro-municipal-do-rio-de-janeiro', 'FUNDACAO TEATRO MUNICIPAL DO RIO DE JANEIRO', true, NULL),
('geral', 'GERAL', true, NULL),
('hmmq', 'HMMQ', true, NULL),
('hospital-central-do-exercito', 'HOSPITAL CENTRAL DO EXERCITO', true, NULL),
('hospital-de-guarnicao-de-natal', 'HOSPITAL DE GUARNICAO DE NATAL', true, NULL),
('hospital-geral-de-curitiba', 'HOSPITAL GERAL DE CURITIBA', true, NULL),
('hospital-geral-de-eunapolis', 'HOSPITAL GERAL DE EUNAPOLIS', true, NULL),
('hospital-geral-do-rio-de-janeiro', 'HOSPITAL GERAL DO RIO DE JANEIRO', true, NULL),
('hospital-municipal-desembargador-leal-junior', 'HOSPITAL MUNICIPAL DESEMBARGADOR LEAL JUNIOR', true, NULL),
('if-sertao-pernambucano-campus-floresta', 'IF SERTAO PERNAMBUCANO CAMPUS FLORESTA', true, NULL),
('incra-superintendencia-regional-rj', 'INCRA - SUPERINTENDENCIA REGIONAL RJ', true, NULL),
('inpe-inst-nacional-de-pesqui-espaciais', 'INPE - INST NACIONAL DE PESQUI ESPACIAIS', true, NULL),
('instituto-federal-fluminense-item-1', 'INSTITUTO FEDERAL FLUMINENSE - ITEM 1', true, NULL),
('instituto-federal-fluminense-item-2', 'INSTITUTO FEDERAL FLUMINENSE - ITEM 2', true, NULL),
('issl-br-ct-imagem', 'ISSL BR CT IMAGEM', true, NULL),
('issl-br-xavantes', 'ISSL BR XAVANTES', true, NULL),
('issl-brasilia', 'ISSL BRASILIA', true, NULL),
('issl-projeto-duque-de-caxias', 'ISSL PROJETO DUQUE DE CAXIAS', true, NULL),
('laboratorio-quimico-farmaceutico-do-exercito', 'LABORATORIO QUIMICO FARMACEUTICO DO EXERCITO', true, NULL),
('matriz', 'MATRIZ', true, NULL),
('ministerio-de-minas-e-energia', 'MINISTERIO DE MINAS E ENERGIA', true, NULL),
('odontoclinica-central-do-exercito', 'ODONTOCLINICA CENTRAL DO EXERCITO', true, NULL),
('projeto-brasil-esportes-v', 'PROJETO BRASIL + ESPORTES V', true, NULL),
('rioprevidencia-lt-i', 'RIOPREVIDENCIA LT I', true, NULL),
('rioprevidencia-lt-ii', 'RIOPREVIDENCIA LT II', true, NULL),
('super-de-policia-rodoviaria-federal-df', 'SUPER DE POLICIA RODOVIARIA FEDERAL/DF', true, NULL),
('super-de-policia-rodoviaria-federal-es', 'SUPER DE POLICIA RODOVIARIA FEDERAL/ES', true, NULL),
('universidade-federal-rural-do-semi-arido', 'UNIVERSIDADE FEDERAL RURAL DO SEMI-ARIDO', true, NULL),
('utfpr-univer-tecnol-federal-do-parana', 'UTFPR - UNIVER TECNOL FEDERAL DO PARANA', true, NULL);

insert into public.categories (contract_id, code, name, manual_limit) values
('instituto-bahia', 1, 'Pessoal e Reflexos', 1202594.89),
('instituto-bahia', 2, 'Contratação Pessoa Jurídica', 1607035.38),
('instituto-bahia', 3, 'Itens de Consumo', 697850.0),
('instituto-bahia', 4, 'Prestação de Serviços', 1424229.0),
('instituto-bahia', 5, 'Despesas de Gestão', 289590.73),
('instituto-bahia', 6, 'Encargos e Glosas', 570500.0);

insert into public.items (contract_id, category_code, item_code, name, limit_value) values
('instituto-bahia', 1, '1.01', 'Despesas de pessoal (Salários, adicionais, benefícios, insalubridade, encargos)', 1005115.6),
('instituto-bahia', 1, '1.02', 'Provisionamento (13º salários, férias, multa FGTS e rescisões)', 197479.28),
('instituto-bahia', 1, '1.03', 'INSS empregador', 0.0),
('instituto-bahia', 2, '2.01', 'Remuneração Médica Assistencial', 1607035.38),
('instituto-bahia', 3, '3.01', 'Água (Embasa)', 40000.0),
('instituto-bahia', 3, '3.02', 'Locação de Estação de Tratamento de Esgoto / Esgotamento de fossas sépticas', 40000.0),
('instituto-bahia', 3, '3.03', 'Combustíveis (veículos e geradores)', 11000.0),
('instituto-bahia', 3, '3.04', 'Manutenção veicular (óleos, pneus, peças mecânicas)', 5000.0),
('instituto-bahia', 3, '3.05', 'Dietas Enterais e Parenterais', 18000.0),
('instituto-bahia', 3, '3.06', 'Energia Elétrica', 56000.0),
('instituto-bahia', 3, '3.07', 'Despesas de apoio ao colaborador (EPI, uniforme, crachás, materiais diversos)', 5500.0),
('instituto-bahia', 3, '3.08', 'Internet e Telefonia', 1500.0),
('instituto-bahia', 3, '3.09', 'Materiais de Escritório / Digitalização / Dispenser e Suportes, gráfica e identidade visual', 28500.0),
('instituto-bahia', 3, '3.10', 'Materiais Médico-Hospitalares de Uso Externo e Interno (Utilizável)', 75500.0),
('instituto-bahia', 3, '3.11', 'Medicamentos de Uso Interno (Utilizável)', 350000.0),
('instituto-bahia', 3, '3.12', 'Mobiliário e Itens Móveis para reposição', 3850.0),
('instituto-bahia', 3, '3.13', 'Órteses e Próteses', 28000.0),
('instituto-bahia', 3, '3.14', 'Usina de Gases Medicinais', 35000.0),
('instituto-bahia', 4, '4.01', 'Alimentação de Pacientes, Acompanhantes e Funcionários', 433750.0),
('instituto-bahia', 4, '4.02', 'Coleta e Tratamento de Lixo Infectante', 16550.0),
('instituto-bahia', 4, '4.03', 'Controle de Vetores e Pragas / Limpeza de Caixa d''água / Dedetização', 2500.0),
('instituto-bahia', 4, '4.04', 'Exames Clínicos Laboratoriais e Anatomopatológicos', 250000.0),
('instituto-bahia', 4, '4.05', 'Exames Diagnósticos (Exames de Ressonância e Rx)', 25000.0),
('instituto-bahia', 4, '4.06', 'Exames Diagnósticos (Métodos Endoscópicos - Colonoscopia, Endoscopia)', 15000.0),
('instituto-bahia', 4, '4.07', 'Higienização, Limpeza e Jardinagem', 35750.0),
('instituto-bahia', 4, '4.08', 'Hotelaria e Lavanderia', 25500.0),
('instituto-bahia', 4, '4.09', 'Locação de Equipamentos Administrativos (Impressoras e PCs)', 30000.0),
('instituto-bahia', 4, '4.10', 'Locação de Equipamentos Assistenciais e de Acessibilidade', 22884.0),
('instituto-bahia', 4, '4.11', 'Locação de Veículos Administrativos', 23400.0),
('instituto-bahia', 4, '4.12', 'Locação, Manutenção, Instalação e Monitoramento de CFTV', 39800.0),
('instituto-bahia', 4, '4.13', 'Locação de Equipamentos Médicos, Cirúrgicos e Hospitalares', 82000.0),
('instituto-bahia', 4, '4.14', 'Serviço de Tratamento de Feridas Complexas', 90000.0),
('instituto-bahia', 4, '4.15', 'Gestão e Manutenção de Equipamentos e Engenharia Clínica', 46000.0),
('instituto-bahia', 4, '4.16', 'Manutenção de Móveis e Marcenaria', 9500.0),
('instituto-bahia', 4, '4.17', 'Manutenção de Sistema de Climatização', 15200.0),
('instituto-bahia', 4, '4.18', 'Manutenção de Sistemas de Combate a Incêndio', 10500.0),
('instituto-bahia', 4, '4.19', 'Gestão e Infraestrutura de Tecnologias de Informação e Comunicação (TIC)', 11500.0),
('instituto-bahia', 4, '4.20', 'Manutenção Predial, Elétrica, Hidráulica e de Geradores', 81000.0),
('instituto-bahia', 4, '4.21', 'Manutenção de Elevadores', 5000.0),
('instituto-bahia', 4, '4.22', 'Medicina do Trabalho, Saúde Ocupacional, PPRA, PCMSO', 4200.0),
('instituto-bahia', 4, '4.23', 'Programa de Proteção Radiológica e Dosimetria', 1470.0),
('instituto-bahia', 4, '4.24', 'Software de Gestão Hospitalar, Prestação de Contas / Auditoria, Prontuário Eletrônico', 22465.0),
('instituto-bahia', 4, '4.25', 'Software e Equipamentos de Ponto Biométrico', 3500.0),
('instituto-bahia', 4, '4.26', 'Transporte de Pacientes', 15500.0),
('instituto-bahia', 4, '4.27', 'Treinamentos e Capacitações', 53260.0),
('instituto-bahia', 4, '4.28', 'Vigilância e Segurança Patrimonial', 53000.0),
('instituto-bahia', 5, '5.1', 'Serviços de contabilidade e controle financeiro, departamento jurídico, logística de compras centralizada, remuneração de dirigentes, deslocamentos de equipes de supervisão, TI corporativa, auditorias internas e ações sociais', 289590.73),
('instituto-bahia', 6, '6.1', 'Encargos sobre a Nota Fiscal - ISS', 184500.0),
('instituto-bahia', 6, '6.2', 'Glosas equipe médica e demais funcionários', 386000.0);

insert into public.transactions (contract_id, tx_date, value, description, direction, label, code, manual_cat, cat) values
('instituto-bahia', '2026-08-06', 2495900.0, 'REPASSE BAHIA ', 'ENTRADA', NULL, NULL, NULL, NULL),
('instituto-bahia', '2026-08-06', 400000.0, 'REPASSE BAHIA ', 'ENTRADA', NULL, NULL, NULL, NULL),
('instituto-bahia', '2026-08-06', 553395.05, 'FOLHA CLT PARTE 1', 'SAIDA', 'RH CLT', '1.01', NULL, 1),
('instituto-bahia', '2026-08-06', 110.5, 'TARIFA ', 'SAIDA', 'Despesa de Gestão', '5', NULL, 5),
('instituto-bahia', '2026-08-07', 15011.82, 'FOLHA CLT PARTE 2', 'SAIDA', 'RH CLT', '1.01', NULL, 1),
('instituto-bahia', '2026-08-07', 307894.5, 'ALIMENTAÇÃO ', 'SAIDA', 'Serviço', '4.01', NULL, 4),
('instituto-bahia', '2026-08-07', 4500.0, 'CLIMATIZAÇÃO ', 'SAIDA', 'Serviço', '4.17', NULL, 4),
('instituto-bahia', '2026-08-07', 6906.56, 'RADIOLOGIA ', 'SAIDA', 'Serviço', NULL, NULL, 4),
('instituto-bahia', '2026-08-07', 37800.0, 'FORTE VIGILANCIA ', 'SAIDA', 'Serviço', NULL, NULL, 4),
('instituto-bahia', '2026-08-07', 754967.05, 'SUPER FARMA ', 'SAIDA', 'Consumo ', NULL, NULL, 3),
('instituto-bahia', '2026-08-07', 40000.0, 'MANAH SERVIÇOS MÉDICOS ', 'SAIDA', 'RH MÉDICO ', NULL, NULL, 2),
('instituto-bahia', '2026-08-07', 18381.6, 'MANUTENÇÃO ', 'SAIDA', 'Serviço', NULL, NULL, 4),
('instituto-bahia', '2026-08-07', 12280.64, 'INTEEC', 'SAIDA', 'Serviço', NULL, NULL, 4),
('instituto-bahia', '2026-08-07', 13972.5, 'NORDESTE AMBIENTAL - RESIDUOS ', 'SAIDA', 'Serviço', NULL, NULL, 4),
('instituto-bahia', '2026-08-07', 124987.2, 'LABORATORIO - EUNALAB ', 'SAIDA', 'Serviço', NULL, NULL, 4),
('instituto-bahia', '2026-08-07', 55194.62, 'FOLHA CLT PARTE 3', 'SAIDA', 'RH CLT', NULL, NULL, 1),
('instituto-bahia', '2026-08-07', 5000.0, 'CREDITO POSTO DE GASOLINA ', 'SAIDA', 'Consumo ', NULL, NULL, 3),
('instituto-bahia', '2026-08-07', 3526.45, 'SALDO DEVEDOR  POSTO DE GASOLINA ', 'SAIDA', 'Consumo ', NULL, NULL, 3),
('instituto-bahia', '2026-08-07', 1686.69, 'PG CLT ROBSOJN PARTE 4', 'SAIDA', 'RH CLT', NULL, NULL, 1),
('instituto-bahia', '2026-08-07', 940284.82, 'POUPANÇA BAHIA ', 'SAIDA', NULL, NULL, NULL, NULL),
('instituto-bahia', '2026-08-10', 940284.82, 'VOLTA PARA CORRENTE ', 'ENTRADA', NULL, NULL, NULL, NULL),
('instituto-bahia', '2026-08-10', 327157.68, 'FOLHA DOS MÉDICOS PARTE 1', 'SAIDA', 'RH MÉDICO ', NULL, NULL, 2),
('instituto-bahia', '2026-08-10', 1451.33, 'PASSAGEM DR HILDA ', 'SAIDA', 'Despesa de Gestão', NULL, NULL, 5),
('instituto-bahia', '2026-08-10', 85140.12, 'DESPESAS BAHIA RATEIO ', 'SAIDA', 'consumo e despesa de gestão ', NULL, NULL, NULL),
('instituto-bahia', '2026-08-10', 8.5, 'TARIFA ', 'SAIDA', 'consumo e despesa de gestão ', NULL, NULL, 5),
('instituto-bahia', '2026-08-10', 12900.0, 'ALUGUEL DOS CARROS ', 'SAIDA', 'Locação de Veiculos ADM ', NULL, NULL, 4),
('instituto-bahia', '2026-08-10', 8.5, 'TARIFA ', 'SAIDA', 'consumo e despesa de gestão ', NULL, NULL, 5),
('instituto-bahia', '2026-08-10', 22745.84, 'OPME ', 'SAIDA', 'consumo', NULL, NULL, 3),
('instituto-bahia', '2026-08-10', 8.5, 'TARIFA ', 'SAIDA', 'Despesa de Gestão', NULL, NULL, 5),
('instituto-bahia', '2026-08-10', 15499.34, 'ENTRADA ELAINE ', 'ENTRADA', NULL, NULL, NULL, NULL),
('instituto-bahia', '2026-08-11', 506389.19, 'TRANF POUPANÇA', 'SAIDA', NULL, NULL, NULL, NULL),
('instituto-bahia', '2026-08-11', 2.5, 'TARIFA ', 'SAIDA', 'Despesa de Gestão', NULL, NULL, 5),
('instituto-bahia', '2026-08-11', 506386.69, 'ENTRADA ', 'ENTRADA', NULL, NULL, NULL, NULL),
('instituto-bahia', '2026-08-11', 189455.14, 'PAGAMENTO MÉDICOS PARTE 2', 'SAIDA', 'RH MÉDICO ', NULL, NULL, 2),
('instituto-bahia', '2026-08-11', 6761.27, 'PAGAMENTO CLT PARTE 4', 'SAIDA', 'RH CLT', NULL, NULL, 1),
('instituto-bahia', '2026-08-11', 1200.0, 'CARRO PIPA', 'SAIDA', 'consumo', NULL, NULL, 3),
('instituto-bahia', '2026-08-11', 6509.99, 'IMPRESSORAS', 'SAIDA', 'Serviço', NULL, NULL, 4),
('instituto-bahia', '2026-08-11', 19800.0, 'USINA DE OXIGENIO', 'SAIDA', 'Consumo', NULL, NULL, 3),
('instituto-bahia', '2026-08-11', 2700.0, 'MANUTENÇÃO DE GERADORES', 'SAIDA', 'Serviço', NULL, NULL, 4),
('instituto-bahia', '2026-08-11', 4252.2, 'PRISCILLA ADM', 'SAIDA', 'Despesa de Gestão', NULL, NULL, 5),
('instituto-bahia', '2026-08-11', 20000.0, 'KENYA JURIDICO', 'SAIDA', 'Despesa de Gestão', NULL, NULL, 5),
('instituto-bahia', '2026-08-11', 15000.0, 'CONTABILIDADE', 'SAIDA', 'Despesa de Gestão', NULL, NULL, 5),
('instituto-bahia', '2026-08-11', 15499.34, 'DR. ELLAINE SANTOS', 'SAIDA', 'RH MÉDICO ', NULL, NULL, 2),
('instituto-bahia', '2026-08-11', 225208.75, 'TRANSF POUPANÇA ', 'SAIDA', NULL, NULL, NULL, NULL),
('instituto-bahia', '2026-08-11', 2.5, 'TARIFA ', 'SAIDA', 'Despesa de Gestão', NULL, NULL, 5),
('instituto-bahia', '2026-08-12', 225206.25, 'ENTRADA ISSL', 'ENTRADA', NULL, NULL, NULL, NULL),
('instituto-bahia', '2026-08-12', 157520.47, 'PAGAMENTO MÉDICOS PARTE 3', 'SAIDA', 'RH MÉDICO ', NULL, NULL, 2),
('instituto-bahia', '2026-08-12', 1122.35, 'PASTILHAS DE FREIO AMBULANCIA ', 'SAIDA', 'CONSUMO', NULL, NULL, 3),
('instituto-bahia', '2026-08-13', 30909.36, 'PAGAMENTO MÉDICOS PARTE 4', 'SAIDA', 'RH MÉDICO ', NULL, NULL, 2),
('instituto-bahia', '2026-08-17', 2.27, 'JUROS', 'ENTRADA', 'Despesa de Gestão', NULL, NULL, NULL),
('instituto-bahia', '2026-08-18', 4.81, 'JUROS', 'ENTRADA', 'Despesa de Gestão', NULL, NULL, NULL),
('instituto-bahia', '2026-08-18', 6105.5, 'APARTAMENTO * OCEANIA ', 'SAIDA', 'Despesa de Gestão', NULL, NULL, 5),
('instituto-bahia', '2026-08-18', 2064.7, 'PAGAMENTO MEDICO PARTE 4- FLAVIO FIGUEREDO ', 'SAIDA', 'RH MÉDICO ', NULL, NULL, 2),
('instituto-bahia', '2026-08-18', 2064.7, 'PAGAMENTO MEDICO PARTE 4- FLAVIO FIGUEREDO ', 'SAIDA', 'RH MÉDICO ', NULL, NULL, 2),
('instituto-bahia', '2026-08-19', 3.73, 'juros ', 'ENTRADA', NULL, NULL, NULL, NULL);
