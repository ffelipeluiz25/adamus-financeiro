-- Encarregado também cadastra e edita obras e funcionários (sem acesso ao financeiro).
-- Excluir obra ou funcionário continua só com o admin.
-- Rodar uma vez no SQL Editor do Supabase.

drop policy if exists "encarregado insere lançamento" on public.registros;
drop policy if exists "encarregado altera lançamento" on public.registros;

create policy "encarregado insere" on public.registros
  for insert to authenticated
  with check (public.meu_papel() = 'encarregado' and tipo in ('lancamento', 'obra', 'funcionario'));
create policy "encarregado altera" on public.registros
  for update to authenticated
  using (public.meu_papel() = 'encarregado' and tipo in ('lancamento', 'obra', 'funcionario'))
  with check (public.meu_papel() = 'encarregado' and tipo in ('lancamento', 'obra', 'funcionario'));

-- O orçamento da obra (itens com preço) é financeiro: o encarregado não cria nem altera.
-- Obra nova feita por ele nasce sem orçamento; na edição, os itens antigos são mantidos.
create or replace function public.proteger_orcamento() returns trigger
language plpgsql set search_path = '' as $$
begin
  if new.tipo = 'obra' and public.meu_papel() = 'encarregado' then
    if tg_op = 'INSERT' then
      new.dados := jsonb_set(new.dados, '{itens}', '[]'::jsonb);
    else
      new.dados := jsonb_set(new.dados, '{itens}', coalesce(old.dados -> 'itens', '[]'::jsonb));
    end if;
  end if;
  return new;
end $$;
create trigger registros_proteger_orcamento before insert or update on public.registros
  for each row execute function public.proteger_orcamento();
