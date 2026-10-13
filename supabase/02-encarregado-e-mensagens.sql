-- Papel "encarregado" (só lança produção) + mensagens entre usuários.
-- Rodar uma vez no SQL Editor do Supabase.

-- ─── Papéis ───
alter table public.perfis drop constraint if exists perfis_papel_check;
alter table public.perfis add constraint perfis_papel_check
  check (papel in ('admin', 'gestor', 'encarregado'));

create or replace function public.meu_papel() returns text
language sql stable security definer set search_path = '' as $$
  select papel from public.perfis where user_id = auth.uid()
$$;

-- Todos com perfil veem a lista de usuários (para escolher com quem conversar)
drop policy if exists "ver o próprio perfil" on public.perfis;
create policy "quem tem perfil vê os perfis" on public.perfis
  for select to authenticated using (public.meu_papel() is not null);

-- Encarregado grava somente lançamentos de produção
create policy "encarregado insere lançamento" on public.registros
  for insert to authenticated
  with check (public.meu_papel() = 'encarregado' and tipo = 'lancamento');
create policy "encarregado altera lançamento" on public.registros
  for update to authenticated
  using (public.meu_papel() = 'encarregado' and tipo = 'lancamento')
  with check (public.meu_papel() = 'encarregado' and tipo = 'lancamento');
create policy "encarregado exclui lançamento" on public.registros
  for delete to authenticated
  using (public.meu_papel() = 'encarregado' and tipo = 'lancamento');

-- ─── Mensagens ───
create table public.mensagens (
  id        bigint generated always as identity primary key,
  de        uuid not null default auth.uid() references auth.users on delete cascade,
  para      uuid not null references auth.users on delete cascade,
  texto     text not null check (length(texto) between 1 and 20000),
  criada_em timestamptz not null default now(),
  lida_em   timestamptz
);
create index mensagens_para_idx on public.mensagens (para, id);
create index mensagens_de_idx   on public.mensagens (de, id);
alter table public.mensagens enable row level security;

create policy "ver minhas mensagens" on public.mensagens
  for select to authenticated using (de = auth.uid() or para = auth.uid());
create policy "enviar como eu mesmo" on public.mensagens
  for insert to authenticated
  with check (de = auth.uid() and public.meu_papel() is not null);
create policy "marcar como lida" on public.mensagens
  for update to authenticated using (para = auth.uid()) with check (para = auth.uid());

-- Quem recebe só pode mudar o "lida_em" (não altera texto nem remetente)
revoke update on public.mensagens from authenticated;
grant update (lida_em) on public.mensagens to authenticated;
