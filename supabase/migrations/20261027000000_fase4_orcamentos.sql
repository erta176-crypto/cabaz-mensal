-- Cabaz Mensal · Fase 4 · orçamento mensal (total e por categoria)

-- ---------------------------------------------------------------------------
-- Tabela: um valor por mês e categoria (categoria_id null = total do mês)
-- ---------------------------------------------------------------------------
create table public.orcamentos (
  -- Id determinístico, calculado no cliente (uuid v5 de user, mês e categoria).
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  mes date not null check (extract(day from mes) = 1),
  -- null = orçamento total do mês.
  categoria_id uuid references public.categorias (id) on delete cascade,
  valor_cent integer not null check (valor_cent >= 0),
  criado_em timestamptz not null default now(),
  atualizado_em timestamptz not null default now(),
  apagado_em timestamptz,
  constraint orcamentos_unico unique nulls not distinct (user_id, mes, categoria_id)
);

create trigger set_atualizado_em before update on public.orcamentos
  for each row execute function public.set_atualizado_em();

alter table public.orcamentos enable row level security;

create policy orcamentos_select_dono on public.orcamentos for select to authenticated
  using ((select auth.uid()) = user_id);
create policy orcamentos_insert_dono on public.orcamentos for insert to authenticated
  with check ((select auth.uid()) = user_id);
create policy orcamentos_update_dono on public.orcamentos for update to authenticated
  using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id);
create policy orcamentos_delete_dono on public.orcamentos for delete to authenticated
  using ((select auth.uid()) = user_id);

revoke all on public.orcamentos from anon;

create index on public.orcamentos (user_id, atualizado_em);
create index on public.orcamentos (categoria_id);

-- ---------------------------------------------------------------------------
-- Apagar todos os dados passa a apagar também os orçamentos
-- (mesmo corpo de 20261015120000_fase1a.sql + orcamentos)
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
  delete from public.orcamentos where user_id = uid;
  delete from public.artigos where user_id = uid;
  delete from public.categorias where user_id = uid;
  delete from public.lojas where user_id = uid;

  insert into public.preferencias (user_id, reiniciado_em)
  values (uid, now())
  on conflict (user_id) do update set reiniciado_em = excluded.reiniciado_em;
end;
$$;
