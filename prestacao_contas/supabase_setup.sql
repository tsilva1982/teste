-- PORTAL DE PRESTAÇÃO DE CONTAS — CONFIGURAÇÃO SEGURA
-- Execute este arquivo no SQL Editor do projeto Supabase.
-- Depois, substitua os e-mails de exemplo pelos endereços Google autorizados.

begin;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create table if not exists private.portal_access (
  email text primary key,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  constraint portal_access_email_lowercase check (email = lower(btrim(email)))
);

-- A lista de autorização nunca pode ser consultada diretamente pelo navegador.
revoke all on table private.portal_access from public, anon, authenticated;

create or replace function private.is_portal_user()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from private.portal_access as access_list
    where access_list.enabled = true
      and access_list.email = lower(coalesce((select auth.jwt() ->> 'email'), ''))
  );
$$;

revoke all on function private.is_portal_user() from public, anon, authenticated;
grant usage on schema private to authenticated;
grant execute on function private.is_portal_user() to authenticated;

-- Cria (ou mantém) o bucket como PRIVADO.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values ('prestacao-contas', 'prestacao-contas', false, 5242880, array['text/csv', 'application/vnd.ms-excel'])
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- O papel autenticado pode consultar metadados/objetos; a política RLS abaixo limita o arquivo.
grant select on storage.objects to authenticated;

drop policy if exists "Approved users can read the financial statement CSV" on storage.objects;

create policy "Approved users can read the financial statement CSV"
on storage.objects
for select
to authenticated
using (
  bucket_id = 'prestacao-contas'
  and name = 'lancamentos.csv'
  and (select private.is_portal_user())
);

commit;

-- AUTORIZAR CONTAS GOOGLE:
-- Execute um INSERT por conta, usando o e-mail exato usado no Google.
-- Exemplo:
-- insert into private.portal_access (email)
-- values ('seu.email@gmail.com'), ('pessoa.autorizada@gmail.com')
-- on conflict (email) do update set enabled = true;

-- REVOGAR ACESSO:
-- update private.portal_access set enabled = false where email = 'email@gmail.com';
