-- Cabaz Mensal · Fase 1B · importar ficheiros (lote numa transação) e sincronização
-- Não altera dados existentes.

-- ---------------------------------------------------------------------------
-- Índices únicos completos (a 1A usou índices parciais "where apagado_em is
-- null", que o upsert com onConflict não consegue usar). Reativar uma loja ou
-- categoria apagada é sempre um upsert na mesma linha, com o mesmo id.
-- ---------------------------------------------------------------------------
drop index public.lojas_user_id_slug_ativas;
alter table public.lojas add constraint lojas_user_id_slug_key unique (user_id, slug);

drop index public.categorias_user_id_nome_ativas;
alter table public.categorias add constraint categorias_user_id_nome_key unique (user_id, nome);

-- ---------------------------------------------------------------------------
-- Hora do servidor: a sincronização usa-a para o cursor não ficar parado.
-- ---------------------------------------------------------------------------
create or replace function public.agora()
returns timestamptz
language sql
stable
set search_path = ''
as $$
  select now();
$$;

revoke execute on function public.agora() from public, anon;
grant execute on function public.agora() to authenticated;

-- ---------------------------------------------------------------------------
-- RPC: importar um lote (artigos e preços, compras e linhas, lista) numa só
-- transação. Os ids vêm do cliente; o que já existe é reativado na mesma linha.
-- payload = { categorias, artigos, precos, compras, linhas, itens }
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

  insert into public.artigos (id, nome, categoria_id, unidade, ativo)
  select id, nome, categoria_id, unidade, coalesce(ativo, true)
  from jsonb_to_recordset(coalesce(payload -> 'artigos', '[]'))
    as x(id uuid, nome text, categoria_id uuid, unidade text, ativo boolean)
  on conflict (id) do update
    set nome = excluded.nome,
        categoria_id = excluded.categoria_id,
        unidade = excluded.unidade,
        ativo = excluded.ativo,
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

revoke execute on function public.importar_lote(jsonb) from public, anon;
grant execute on function public.importar_lote(jsonb) to authenticated;
