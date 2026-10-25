-- Cabaz Mensal · Comparação de preços P0 · EAN no artigo e fonte do preço atual
-- Não altera dados existentes: os artigos atuais ficam com ean = null.

-- ---------------------------------------------------------------------------
-- EAN opcional (EAN-8, EAN-13 ou GTIN-14; o UPC-A chega já com 13 dígitos).
-- O dígito de controlo é validado na app. Sem índice único: dois dispositivos
-- sem rede podiam dar o mesmo EAN e um 23505 bloqueava a fila de sincronização.
-- ---------------------------------------------------------------------------
alter table public.artigos add column ean text;
alter table public.artigos add constraint artigos_ean_formato
  check (ean is null or ean ~ '^([0-9]{8}|[0-9]{13}|[0-9]{14})$');
create index artigos_user_id_ean_idx on public.artigos (user_id, ean) where ean is not null;

-- ---------------------------------------------------------------------------
-- Preço atual: "registado" (por mim) ou "online" (a partir do P1).
-- ---------------------------------------------------------------------------
create or replace view public.precos_atuais
with (security_invoker = true)
as
select distinct on (artigo_id, loja_id)
  artigo_id,
  loja_id,
  preco_cent,
  data,
  origem,
  'registado'::text as fonte
from public.registos_preco
where apagado_em is null
order by artigo_id, loja_id, data desc, criado_em desc;

-- ---------------------------------------------------------------------------
-- RPC importar_seed (cópia JSON): o artigo passa a trazer o ean (opcional).
-- ---------------------------------------------------------------------------
create or replace function public.importar_seed(payload jsonb, substituir boolean default false)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  ja_tem boolean;
begin
  if uid is null then
    raise exception 'SEM_SESSAO';
  end if;

  select exists (select 1 from public.lojas where user_id = uid)
      or exists (select 1 from public.artigos where user_id = uid)
      or exists (select 1 from public.compras where user_id = uid)
    into ja_tem;

  if ja_tem then
    if not substituir then
      raise exception 'JA_EXISTEM_DADOS';
    end if;
    perform public.apagar_todos_dados();
  end if;

  insert into public.lojas (id, slug, nome, cadeia, local, cor)
  select id, slug, nome, cadeia, local, cor
  from jsonb_to_recordset(payload -> 'lojas')
    as x(id uuid, slug text, nome text, cadeia text, local text, cor text);

  insert into public.categorias (id, nome, ordem)
  select id, nome, ordem
  from jsonb_to_recordset(payload -> 'categorias')
    as x(id uuid, nome text, ordem integer);

  insert into public.artigos (id, nome, categoria_id, unidade, ativo, ean)
  select id, nome, categoria_id, unidade, coalesce(ativo, true), ean
  from jsonb_to_recordset(payload -> 'artigos')
    as x(id uuid, nome text, categoria_id uuid, unidade text, ativo boolean, ean text);

  insert into public.aliases (id, artigo_id, loja_id, texto_talao)
  select id, artigo_id, loja_id, texto_talao
  from jsonb_to_recordset(payload -> 'aliases')
    as x(id uuid, artigo_id uuid, loja_id uuid, texto_talao text);

  insert into public.compras (id, loja_id, local, data, total_cent, poupanca_cent, origem, ficheiro, rever)
  select id, loja_id, local, data, total_cent, poupanca_cent, origem, ficheiro, rever
  from jsonb_to_recordset(payload -> 'compras')
    as x(id uuid, loja_id uuid, local text, data date, total_cent integer,
         poupanca_cent integer, origem text, ficheiro text, rever boolean);

  insert into public.linhas_compra (id, compra_id, artigo_id, texto_original, quantidade, peso_g,
                                    preco_unit_cent, bruto_cent, desconto_cent, pago_cent)
  select id, compra_id, artigo_id, texto_original, quantidade, peso_g,
         preco_unit_cent, bruto_cent, desconto_cent, pago_cent
  from jsonb_to_recordset(payload -> 'linhas_compra')
    as x(id uuid, compra_id uuid, artigo_id uuid, texto_original text, quantidade integer,
         peso_g integer, preco_unit_cent integer, bruto_cent integer, desconto_cent integer,
         pago_cent integer);

  insert into public.registos_preco (id, artigo_id, loja_id, data, preco_cent, origem)
  select id, artigo_id, loja_id, data, preco_cent, origem
  from jsonb_to_recordset(payload -> 'registos_preco')
    as x(id uuid, artigo_id uuid, loja_id uuid, data date, preco_cent integer, origem text);

  insert into public.itens_lista (id, loja_id, artigo_id, qtd_padrao, incluido)
  select id, loja_id, artigo_id, qtd_padrao, incluido
  from jsonb_to_recordset(payload -> 'itens_lista')
    as x(id uuid, loja_id uuid, artigo_id uuid, qtd_padrao numeric, incluido boolean);

  return jsonb_build_object(
    'lojas', (select count(*) from public.lojas where user_id = uid),
    'categorias', (select count(*) from public.categorias where user_id = uid),
    'artigos', (select count(*) from public.artigos where user_id = uid),
    'aliases', (select count(*) from public.aliases where user_id = uid),
    'compras', (select count(*) from public.compras where user_id = uid),
    'linhas_compra', (select count(*) from public.linhas_compra where user_id = uid),
    'registos_preco', (select count(*) from public.registos_preco where user_id = uid),
    'itens_lista', (select count(*) from public.itens_lista where user_id = uid),
    'compras_rever', (select count(*) from public.compras where user_id = uid and rever),
    'total_cent', (select coalesce(sum(total_cent), 0) from public.compras where user_id = uid)
  );
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC importar_lote (ficheiros): o artigo aceita ean; um lote sem ean (CSV,
-- XLSX) não apaga o ean que o artigo já tem.
-- ---------------------------------------------------------------------------
create or replace function public.importar_lote(payload jsonb)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  n_categorias integer;
  n_artigos integer;
  n_precos integer;
  n_compras integer;
  n_linhas integer;
  n_itens integer;
begin
  if uid is null then
    raise exception 'SEM_SESSAO';
  end if;

  insert into public.categorias (id, nome, ordem)
  select id, nome, ordem
  from jsonb_to_recordset(coalesce(payload -> 'categorias', '[]'))
    as x(id uuid, nome text, ordem integer)
  on conflict (id) do update
    set nome = excluded.nome, ordem = excluded.ordem, apagado_em = null;
  get diagnostics n_categorias = row_count;

  insert into public.artigos (id, nome, categoria_id, unidade, ativo, ean)
  select id, nome, categoria_id, unidade, coalesce(ativo, true), ean
  from jsonb_to_recordset(coalesce(payload -> 'artigos', '[]'))
    as x(id uuid, nome text, categoria_id uuid, unidade text, ativo boolean, ean text)
  on conflict (id) do update
    set nome = excluded.nome,
        categoria_id = excluded.categoria_id,
        unidade = excluded.unidade,
        ativo = excluded.ativo,
        ean = coalesce(excluded.ean, public.artigos.ean),
        apagado_em = null;
  get diagnostics n_artigos = row_count;

  insert into public.compras (id, loja_id, local, data, total_cent, poupanca_cent, origem, ficheiro, rever)
  select id, loja_id, local, data, total_cent, coalesce(poupanca_cent, 0), 'importacao', ficheiro,
         coalesce(rever, false)
  from jsonb_to_recordset(coalesce(payload -> 'compras', '[]'))
    as x(id uuid, loja_id uuid, local text, data date, total_cent integer,
         poupanca_cent integer, ficheiro text, rever boolean)
  on conflict (id) do nothing;
  get diagnostics n_compras = row_count;

  insert into public.linhas_compra (id, compra_id, artigo_id, texto_original, quantidade, peso_g,
                                    preco_unit_cent, bruto_cent, desconto_cent, pago_cent)
  select id, compra_id, artigo_id, texto_original, quantidade, peso_g,
         preco_unit_cent, bruto_cent, coalesce(desconto_cent, 0), pago_cent
  from jsonb_to_recordset(coalesce(payload -> 'linhas', '[]'))
    as x(id uuid, compra_id uuid, artigo_id uuid, texto_original text, quantidade integer,
         peso_g integer, preco_unit_cent integer, bruto_cent integer, desconto_cent integer,
         pago_cent integer)
  on conflict (id) do nothing;
  get diagnostics n_linhas = row_count;

  insert into public.registos_preco (id, artigo_id, loja_id, data, preco_cent, origem)
  select id, artigo_id, loja_id, data, preco_cent, origem
  from jsonb_to_recordset(coalesce(payload -> 'precos', '[]'))
    as x(id uuid, artigo_id uuid, loja_id uuid, data date, preco_cent integer, origem text)
  on conflict (id) do nothing;
  get diagnostics n_precos = row_count;

  insert into public.itens_lista (loja_id, artigo_id, qtd_padrao, qtd, incluido, comprado)
  select loja_id, artigo_id, qtd_padrao, coalesce(qtd, qtd_padrao), coalesce(incluido, true),
         coalesce(comprado, false)
  from jsonb_to_recordset(coalesce(payload -> 'itens', '[]'))
    as x(loja_id uuid, artigo_id uuid, qtd_padrao numeric, qtd numeric, incluido boolean,
         comprado boolean)
  on conflict (user_id, loja_id, artigo_id) do update
    set qtd_padrao = excluded.qtd_padrao,
        qtd = excluded.qtd,
        incluido = excluded.incluido,
        comprado = excluded.comprado,
        apagado_em = null;
  get diagnostics n_itens = row_count;

  return jsonb_build_object(
    'categorias', n_categorias,
    'artigos', n_artigos,
    'precos', n_precos,
    'compras', n_compras,
    'linhas', n_linhas,
    'itens', n_itens
  );
end;
$$;
