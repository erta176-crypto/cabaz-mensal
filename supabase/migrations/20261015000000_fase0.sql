-- Cabaz Mensal · Fase 0 · esquema inicial
-- Dinheiro em cêntimos inteiros, pesos em gramas inteiros, datas como date.
-- Todas as tabelas: id, user_id (dono), criado_em, atualizado_em; RLS só para o dono.

-- ---------------------------------------------------------------------------
-- Função de trigger comum
-- ---------------------------------------------------------------------------
create or replace function public.set_atualizado_em()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.atualizado_em := now();
  return new;
end;
$$;

-- ---------------------------------------------------------------------------
-- Tabelas
-- ---------------------------------------------------------------------------
create table public.lojas (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  slug text not null,
  nome text not null,
  cadeia text,
  local text,
  cor text,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  unique (user_id, slug)
);

create table public.categorias (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  nome text not null,
  ordem integer not null default 0,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  unique (user_id, nome)
);

create table public.artigos (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  nome text not null,
  categoria_id uuid references public.categorias (id) on delete set null,
  unidade text not null default 'un' check (unidade in ('un', 'kg')),
  ativo boolean not null default true,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

-- Desvio aprovado: o mesmo texto de talão pode apontar para a variante "un" e "kg"
-- do mesmo produto, por isso a chave única inclui o artigo.
create table public.aliases (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  artigo_id uuid not null references public.artigos (id) on delete cascade,
  loja_id uuid not null references public.lojas (id) on delete cascade,
  texto_talao text not null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  unique (user_id, loja_id, texto_talao, artigo_id)
);

create table public.registos_preco (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  artigo_id uuid not null references public.artigos (id) on delete cascade,
  loja_id uuid not null references public.lojas (id) on delete cascade,
  data date not null,
  preco_cent integer not null check (preco_cent >= 0),
  origem text not null check (origem in ('talao', 'manual', 'lista')),
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table public.itens_lista (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  loja_id uuid not null references public.lojas (id) on delete cascade,
  artigo_id uuid not null references public.artigos (id) on delete cascade,
  qtd_padrao numeric(10, 3) not null default 1 check (qtd_padrao > 0),
  incluido boolean not null default true,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  unique (user_id, loja_id, artigo_id)
);

create table public.compras (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  loja_id uuid not null references public.lojas (id) on delete restrict,
  local text,
  data date not null,
  total_cent integer not null,
  poupanca_cent integer not null default 0,
  origem text not null check (origem in ('manual', 'talao', 'importacao')),
  ficheiro text,
  rever boolean not null default false,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

create table public.linhas_compra (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  compra_id uuid not null references public.compras (id) on delete cascade,
  -- Se o artigo for eliminado, a linha do talão mantém-se (com texto_original).
  artigo_id uuid references public.artigos (id) on delete set null,
  texto_original text,
  quantidade integer,
  peso_g integer,
  preco_unit_cent integer,
  bruto_cent integer not null,
  desconto_cent integer not null default 0,
  pago_cent integer not null,
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Índices (consultas por loja, data e artigo; FKs; user_id para RLS)
-- ---------------------------------------------------------------------------
create index on public.categorias (user_id);
create index on public.artigos (user_id);
create index on public.artigos (categoria_id);
create index on public.aliases (artigo_id);
create index on public.aliases (loja_id);
create index on public.registos_preco (user_id);
create index on public.registos_preco (artigo_id, loja_id, data desc);
create index on public.registos_preco (loja_id);
create index on public.itens_lista (loja_id);
create index on public.itens_lista (artigo_id);
create index on public.compras (user_id);
create index on public.compras (loja_id, data desc);
create index on public.compras (data desc);
create index on public.linhas_compra (user_id);
create index on public.linhas_compra (compra_id);
create index on public.linhas_compra (artigo_id);

-- ---------------------------------------------------------------------------
-- Triggers atualizado_em e RLS
-- ---------------------------------------------------------------------------
do $$
declare
  t text;
begin
  foreach t in array array[
    'lojas', 'categorias', 'artigos', 'aliases', 'registos_preco',
    'itens_lista', 'compras', 'linhas_compra'
  ] loop
    execute format(
      'create trigger set_atualizado_em before update on public.%I
         for each row execute function public.set_atualizado_em()', t);
    execute format('alter table public.%I enable row level security', t);
    execute format(
      'create policy "%1$s_select_dono" on public.%1$I for select to authenticated
         using ((select auth.uid()) = user_id)', t);
    execute format(
      'create policy "%1$s_insert_dono" on public.%1$I for insert to authenticated
         with check ((select auth.uid()) = user_id)', t);
    execute format(
      'create policy "%1$s_update_dono" on public.%1$I for update to authenticated
         using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id)', t);
    execute format(
      'create policy "%1$s_delete_dono" on public.%1$I for delete to authenticated
         using ((select auth.uid()) = user_id)', t);
    execute format('revoke all on public.%I from anon', t);
  end loop;
end;
$$;

-- ---------------------------------------------------------------------------
-- View de verificação
-- ---------------------------------------------------------------------------
create view public.resumo_por_loja
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
group by l.id, l.slug, l.nome;

revoke all on public.resumo_por_loja from anon;

-- Preço mais recente de cada artigo em cada loja (ecrã Artigos e lojas).
create view public.precos_atuais
with (security_invoker = true)
as
select distinct on (artigo_id, loja_id)
  artigo_id,
  loja_id,
  preco_cent,
  data,
  origem
from public.registos_preco
order by artigo_id, loja_id, data desc, criado_em desc;

revoke all on public.precos_atuais from anon;

-- ---------------------------------------------------------------------------
-- Tempo real (ecrã Artigos e lojas)
-- ---------------------------------------------------------------------------
alter publication supabase_realtime
  add table public.lojas, public.categorias, public.artigos, public.registos_preco;

-- ---------------------------------------------------------------------------
-- RPC: apagar todos os dados do utilizador
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
end;
$$;

-- ---------------------------------------------------------------------------
-- RPC: importação tudo-ou-nada
-- O payload já vem normalizado do cliente (UUIDs gerados e FKs resolvidas).
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

  insert into public.artigos (id, nome, categoria_id, unidade, ativo)
  select id, nome, categoria_id, unidade, coalesce(ativo, true)
  from jsonb_to_recordset(payload -> 'artigos')
    as x(id uuid, nome text, categoria_id uuid, unidade text, ativo boolean);

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

revoke execute on function public.importar_seed(jsonb, boolean) from public, anon;
revoke execute on function public.apagar_todos_dados() from public, anon;
grant execute on function public.importar_seed(jsonb, boolean) to authenticated;
grant execute on function public.apagar_todos_dados() to authenticated;
