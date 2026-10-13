-- Estrutura inicial (já aplicada em 13/10/2026). Mantido aqui como registro.

create table public.perfis (
  user_id uuid primary key references auth.users on delete cascade,
  nome    text,
  papel   text not null default 'gestor' check (papel in ('admin', 'gestor'))
);
alter table public.perfis enable row level security;
create policy "ver o próprio perfil" on public.perfis
  for select to authenticated using (user_id = auth.uid());

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = '' as $$
  select exists (select 1 from public.perfis where user_id = auth.uid() and papel = 'admin')
$$;

create table public.registros (
  id             text primary key,
  tipo           text not null check (tipo in ('obra', 'servico', 'funcionario', 'lancamento', 'vale', 'config')),
  dados          jsonb not null,
  atualizado_em  timestamptz not null default now(),
  atualizado_por uuid default auth.uid()
);
create index registros_tipo_idx on public.registros (tipo);
alter table public.registros enable row level security;

create policy "quem tem perfil lê" on public.registros
  for select to authenticated
  using (exists (select 1 from public.perfis where user_id = auth.uid()));
create policy "admin insere" on public.registros
  for insert to authenticated with check (public.is_admin());
create policy "admin altera" on public.registros
  for update to authenticated using (public.is_admin()) with check (public.is_admin());
create policy "admin exclui" on public.registros
  for delete to authenticated using (public.is_admin());

create or replace function public.tocar_atualizado() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.atualizado_em := now();
  new.atualizado_por := auth.uid();
  return new;
end $$;
create trigger registros_tocar before update on public.registros
  for each row execute function public.tocar_atualizado();
