-- PORTAL DE PRESTAÇÃO DE CONTAS — HARDENING E POLÍTICAS DE ACESSO
-- Projeto: tuevfnvcesorjpkhtbzi
--
-- REVISÃO IMPORTANTE:
-- A inspeção do projeto encontrou private.portal_access com RLS desabilitado.
-- Este script habilita RLS sem criar política de leitura direta para o navegador.
-- A lista de autorização deve continuar inacessível diretamente; a função abaixo
-- só retorna true quando há um usuário autenticado e seu e-mail está autorizado.
--
-- Revise este script antes de executá-lo no SQL Editor do projeto correto.

begin;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;
grant usage on schema private to authenticated;

create table if not exists private.portal_access (
  email text primary key,
  enabled boolean not null default true,
  created_at timestamptz not null default now(),
  constraint portal_access_email_lowercase check (email = lower(btrim(email)))
);

-- A tabela de autorização não terá políticas de acesso direto.
-- Sem políticas RLS e sem GRANT de tabela, clientes não podem ler a allowlist.
alter table private.portal_access enable row level security;
revoke all on table private.portal_access from public, anon, authenticated;

-- SECURITY DEFINER é usado somente para consultar a allowlist privada.
-- A função exige identidade autenticada e rejeita usuários anônimos.
create or replace function private.is_portal_user()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    (select auth.uid()) is not null
    and coalesce((select (auth.jwt() ->> 'is_anonymous')::boolean), false) = false
    and exists (
      select 1
      from private.portal_access as access_list
      where access_list.enabled = true
        and access_list.email = lower(coalesce((select auth.jwt() ->> 'email'), ''))
    );
$$;

revoke all on function private.is_portal_user() from public, anon, authenticated;
grant execute on function private.is_portal_user() to authenticated;

-- Cria ou mantém o bucket como PRIVADO.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'prestacao-contas',
  'prestacao-contas',
  false,
  5242880,
  array['text/csv', 'application/vnd.ms-excel']
)
on conflict (id) do update
set public = false,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

-- A permissão SQL permite a consulta; a política RLS limita o objeto e o usuário.
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
-- Execute no SQL Editor depois de substituir pelos e-mails Google corretos.
-- insert into private.portal_access (email)
-- values ('conta1@gmail.com'), ('conta2@gmail.com')
-- on conflict (email) do update set enabled = true;

-- REVOGAR ACESSO:
-- update private.portal_access set enabled = false
-- where email = 'conta@gmail.com';

-- TESTES BÁSICOS APÓS A EXECUÇÃO:
-- 1) RLS deve estar ligado:
-- select relrowsecurity from pg_class where oid = 'private.portal_access'::regclass;
-- 2) acesso direto à tabela deve continuar sem GRANT:
-- select has_table_privilege('authenticated','private.portal_access','select');
-- 3) sem sessão de usuário, a função deve retornar false:
-- select private.is_portal_user();
-- 4) confira se o bucket permanece privado:
-- select public from storage.buckets where id = 'prestacao-contas';
