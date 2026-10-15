-- Cabaz Mensal · Fase 1A · lista do mês, Concluir compra e sincronização sem rede
-- Não altera dados existentes (só acrescenta colunas com valores por omissão).

-- ---------------------------------------------------------------------------
-- Eliminações que se propagam: apagado_em nas tabelas guardadas em cache
-- ---------------------------------------------------------------------------
alter table public.lojas add column apagado_em timestamptz;
alter table public.categorias add column apagado_em timestamptz;
alter table public.artigos add column apagado_em timestamptz;
alter table public.aliases add column apagado_em timestamptz;
alter table public.itens_lista add column apagado_em timestamptz;
alter table public.registos_preco add column apagado_em timestamptz;

-- Nomes únicos só entre os registos ativos: criar outra vez uma categoria ou
-- loja com o nome de uma apagada não pode dar erro 23505.
alter table public.lojas drop constraint lojas_user_id_slug_key;
create unique index lojas_user_id_slug_ativas
  on public.lojas (user_id, slug) where apagado_em is null;
alter table public.categorias drop constraint categorias_user_id_nome_key;
create unique index categorias_user_id_nome_ativas
  on public.categorias (user_id, nome) where apagado_em is null;

-- Loja com compras não se elimina: arquiva-se.
alter table public.lojas add column arquivada boolean not null default false;

-- ---------------------------------------------------------------------------
-- Lista do mês
-- ---------------------------------------------------------------------------
-- qtd = quantidade desta compra. O Postgres não deixa o default apontar para
-- outra coluna: o repositório preenche-a com qtd_padrao ao incluir o artigo, e
-- um trigger faz o mesmo quando ela não vem (ex.: importar_seed da Fase 0).
alter table public.itens_lista
  add column comprado boolean not null default false,
  add column qtd numeric(10, 3) check (qtd > 0),
  add column ordem integer not null default 0;

update public.itens_lista set qtd = qtd_padrao;
alter table public.itens_lista alter column qtd set not null;

create or replace function public.itens_lista_qtd_inicial()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.qtd is null then
    new.qtd := new.qtd_padrao;
  end if;
  return new;
end;
$$;

create trigger itens_lista_qtd_inicial before insert on public.itens_lista
  for each row execute function public.itens_lista_qtd_inicial();

-- ---------------------------------------------------------------------------
-- Compras feitas com "Concluir compra"
-- ---------------------------------------------------------------------------
alter table public.compras drop constraint compras_origem_check;
alter table public.compras add constraint compras_origem_check
  check (origem in ('manual', 'talao', 'importacao', 'lista'));

-- ---------------------------------------------------------------------------
-- Preferências (gestos, escolhas da Lista), sincronizadas entre dispositivos
-- ---------------------------------------------------------------------------
create table public.preferencias (
  user_id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  dados jsonb not null default '{}'::jsonb,
  -- Muda quando os dados são apagados a sério (Apagar tudo / importar a
  -- substituir): os dispositivos limpam a cache local e voltam a puxar tudo.
  reiniciado_em timestamptz,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create trigger set_atualizado_em before update on public.preferencias
  for each row execute function public.set_atualizado_em();

alter table public.preferencias enable row level security;

create policy preferencias_select_dono on public.preferencias for select to authenticated
  using ((select auth.uid()) = user_id);
create policy preferencias_insert_dono on public.preferencias for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy preferencias_update_dono on public.preferencias for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy preferencias_delete_dono on public.preferencias for delete to authenticated
  using ((select auth.uid()) = user_id);

revoke all on public.preferencias from anon;

-- ---------------------------------------------------------------------------
-- Índices para a sincronização incremental (atualizado_em > cursor)
-- ---------------------------------------------------------------------------
create index on public.lojas (user_id, atualizado_em);
create index on public.categorias (user_id, atualizado_em);
create index on public.artigos (user_id, atualizado_em);
create index on public.aliases (user_id, atualizado_em);
create index on public.itens_lista (user_id, atualizado_em);
create index on public.registos_preco (user_id, atualizado_em);
create index on public.compras (user_id, atualizado_em);

-- ---------------------------------------------------------------------------
-- Views: passam a ignorar o que está apagado
-- ---------------------------------------------------------------------------
create or replace view public.resumo_por_loja
with (security_invoker = true)
as
select
  l.id as loja_id,
  l.slug,
  l.nome,
  count(c.id)::integer as n_compras,
  coalesce(sum(c.total_cent), 0)::bigint as total_cent
from public.lojas l
left join public.compras c on c.loja_id = l.id
where l.apagado_em is null
group by l.id, l.slug, l.nome;

create or replace view public.precos_atuais
with (security_invoker = true)
as
select distinct on (artigo_id, loja_id)
  artigo_id,
  loja_id,
  preco_cent,
  data,
  origem
from public.registos_preco
where apagado_em is null
order by artigo_id, loja_id, data desc, criado_em desc;

-- ---------------------------------------------------------------------------
-- Tempo real
-- ---------------------------------------------------------------------------
alter publication supabase_realtime
  add table public.aliases, public.itens_lista, public.compras,
            public.linhas_compra, public.preferencias;

-- ---------------------------------------------------------------------------
-- Apagar todos os dados: passa a avisar os dispositivos (reiniciado_em)
-- ---------------------------------------------------------------------------
create or replace function public.apagar_todos_dados()
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
begin
  if uid is null then
    raise exception 'SEM_SESSAO';
  end if;
  delete from public.linhas_compra where user_id = uid;
  delete from public.compras where user_id = uid;
  delete from public.registos_preco where user_id = uid;
  delete from public.itens_lista where user_id = uid;
  delete from public.aliases where user_id = uid;
  delete from public.artigos where user_id = uid;
  delete from public.categorias where user_id = uid;
  delete from public.lojas where user_id = uid;

  insert into public.preferencias (user_id, reiniciado_em)
  values (uid, now())
  on conflict (user_id) do update set reiniciado_em = excluded.reiniciado_em;
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: Concluir compra (idempotente: os ids vêm do cliente)
-- payload = { compra: {...}, linhas: [...], precos: [...], itens: [{loja_id, artigo_id}] }
-- ---------------------------------------------------------------------------
create or replace function public.concluir_compra(payload jsonb)
returns jsonb
language plpgsql
security invoker
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  c jsonb := payload -> 'compra';
  nova uuid;
begin
  if uid is null then
    raise exception 'SEM_SESSAO';
  end if;

  insert into public.compras (id, loja_id, local, data, total_cent, poupanca_cent, origem, rever)
  values (
    (c ->> 'id')::uuid,
    (c ->> 'loja_id')::uuid,
    c ->> 'local',
    (c ->> 'data')::date,
    (c ->> 'total_cent')::integer,
    coalesce((c ->> 'poupanca_cent')::integer, 0),
    'lista',
    coalesce((c ->> 'rever')::boolean, false)
  )
  on conflict (id) do nothing
  returning id into nova;

  -- Pedido repetido (ex.: a resposta perdeu-se sem rede): nada a fazer.
  if nova is null then
    return jsonb_build_object('compra_id', c ->> 'id', 'repetida', true);
  end if;

  insert into public.linhas_compra (id, compra_id, artigo_id, texto_original, quantidade, peso_g,
                                    preco_unit_cent, bruto_cent, desconto_cent, pago_cent)
  select id, nova, artigo_id, texto_original, quantidade, peso_g,
         preco_unit_cent, bruto_cent, coalesce(desconto_cent, 0), pago_cent
  from jsonb_to_recordset(payload -> 'linhas')
    as x(id uuid, artigo_id uuid, texto_original text, quantidade integer, peso_g integer,
         preco_unit_cent integer, bruto_cent integer, desconto_cent integer, pago_cent integer)
  on conflict (id) do nothing;

  insert into public.registos_preco (id, artigo_id, loja_id, data, preco_cent, origem)
  select id, artigo_id, loja_id, data, preco_cent, 'manual'
  from jsonb_to_recordset(payload -> 'precos')
    as x(id uuid, artigo_id uuid, loja_id uuid, data date, preco_cent integer)
  on conflict (id) do nothing;

  update public.itens_lista i
  set comprado = false, qtd = i.qtd_padrao
  from jsonb_to_recordset(payload -> 'itens') as x(loja_id uuid, artigo_id uuid)
  where i.user_id = uid and i.loja_id = x.loja_id and i.artigo_id = x.artigo_id;

  return jsonb_build_object('compra_id', nova, 'repetida', false);
end;
$$;

revoke execute on function public.concluir_compra(jsonb) from public, anon;
grant execute on function public.concluir_compra(jsonb) to authenticated;
