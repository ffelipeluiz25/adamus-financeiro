-- Tela "Meu Perfil": foto e nome (visíveis aos outros usuários, ex.: nas mensagens)
-- e dados pessoais (CPF, celular, nascimento) que só o próprio usuário e o admin enxergam.
-- Rodar uma vez no SQL Editor do Supabase.

-- ─── Foto e nome em "perfis" ───
alter table public.perfis add column if not exists foto text
  check (foto is null or length(foto) < 300000);          -- imagem já reduzida no navegador (~20 KB)

create policy "editar o próprio perfil" on public.perfis
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

-- O usuário só altera nome e foto; o papel continua sendo definido pelo admin no SQL
revoke update on public.perfis from authenticated;
grant update (nome, foto) on public.perfis to authenticated;

-- ─── Dados pessoais (LGPD: separados e restritos) ───
create table if not exists public.dados_pessoais (
  user_id       uuid primary key default auth.uid() references auth.users on delete cascade,
  cpf           text check (cpf is null or cpf ~ '^\d{3}\.\d{3}\.\d{3}-\d{2}$'),
  celular       text check (celular is null or length(celular) <= 20),
  nascimento    date,
  atualizado_em timestamptz not null default now()
);
alter table public.dados_pessoais enable row level security;

create policy "dono ou admin vê" on public.dados_pessoais
  for select to authenticated using (user_id = auth.uid() or public.meu_papel() = 'admin');
create policy "dono cadastra" on public.dados_pessoais
  for insert to authenticated with check (user_id = auth.uid());
create policy "dono altera" on public.dados_pessoais
  for update to authenticated using (user_id = auth.uid()) with check (user_id = auth.uid());

create or replace function public.tocar_dados_pessoais() returns trigger
language plpgsql set search_path = '' as $$
begin
  new.atualizado_em := now();
  return new;
end $$;
create trigger dados_pessoais_tocar before update on public.dados_pessoais
  for each row execute function public.tocar_dados_pessoais();
