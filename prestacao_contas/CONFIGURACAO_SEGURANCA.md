# Configuração de acesso seguro — Prestação de Contas

O portal usa Google OAuth com Supabase Auth e mantém o arquivo financeiro em um bucket privado do Supabase Storage. O CSV não deve ficar no repositório público do GitHub.

## 1. Projeto e cliente

- Project URL: `https://tuevfnvcesorjpkhtbzi.supabase.co`
- Publishable key: configurada em `supabase-config.js`
- A aplicação usa OAuth PKCE.
- Nunca inclua uma chave `service_role` ou `sb_secret` no navegador ou no GitHub.

## 2. Segurança aplicada e verificada em 16/11/2026

A correção foi aplicada ao projeto Supabase e revalidada:

- RLS está habilitado em `private.portal_access`.
- `anon`, `authenticated` e `public` não possuem leitura direta da lista de autorização.
- A função `private.is_portal_user()` exige `auth.uid()`, rejeita sessões anônimas e compara o e-mail autenticado com a lista habilitada.
- A função pode ser executada por `authenticated`, mas não por `anon`.
- Sem uma sessão, a função retorna `false`.
- O bucket `prestacao-contas` está privado.
- A política de Storage permite somente SELECT do objeto `lancamentos.csv` por usuários autenticados aprovados.

O Security Advisor mantém um aviso informativo porque a tabela de autorização não tem política própria de SELECT. Isso é intencional: a lista não deve ser lida diretamente pelo navegador. Também foi sinalizado que a proteção contra senhas vazadas está desativada; é recomendável ativá-la caso o projeto use autenticação por senha. Esse aviso não impediu o teste de Google OAuth.

## 3. Lista de pessoas autorizadas

Há três registros habilitados. A validação de formato detectou que um deles contém dois sinais `@`, indicando provável duplicação do sufixo do domínio. Esse endereço não corresponde ao endereço normal do usuário de teste Google que aparece no Console. Por isso, a pessoa correspondente pode autenticar no Google, mas não passar pela autorização do portal.

Confira os três e-mails no SQL Editor. Para corrigir o registro com erro, substitua o exemplo pelo e-mail exato da pessoa que já deve ter acesso:

```sql
update private.portal_access
set email = 'email.correto@gmail.com'
where email = 'email.com.sufixo.duplicado@gmail.com@gmail.com';
```

Não execute o exemplo sem confirmar o endereço correto. Para adicionar uma pessoa nova, use:

```sql
insert into private.portal_access (email)
values ('nova.pessoa@gmail.com')
on conflict (email) do update set enabled = true;
```

Para revogar o acesso:

```sql
update private.portal_access
set enabled = false
where email = 'pessoa@gmail.com';
```

## 4. Google OAuth

O login Google foi efetivamente utilizado: o Supabase registra uma identidade Google e a sessão aberta no painel mostra uma conta autenticada. O Google Auth Platform está em modo **Testing**, com três usuários de teste cadastrados; somente esses testadores podem concluir o fluxo enquanto esse modo permanecer ativo.

- Callback do Supabase: `https://tuevfnvcesorjpkhtbzi.supabase.co/auth/v1/callback`
- Origem autorizada do site: `https://tsilva1982.github.io`
- Site URL sugerida no Supabase: `https://tsilva1982.github.io/teste/prestacao_contas/index.html`
- Redirect URL: `https://tsilva1982.github.io/teste/prestacao_contas/**`

O Client Secret deve permanecer apenas no painel do Supabase. Não o inclua no GitHub ou nesta documentação.

## 5. Arquivo financeiro no Storage

- Bucket: `prestacao-contas` (privado)
- Objeto esperado: `lancamentos.csv`
- Objeto encontrado no reteste: presente, com aproximadamente 80.690 bytes.

O navegador autenticado conseguiu baixar o objeto, mas a aplicação rejeitou todas as linhas na validação. O formato esperado pelo painel é:

```csv
Data;Descrição;Categoria;Tipo;Valor
05/11/2026;Pagamento cuidador;Serviços;Despesa;2000,00
10/11/2026;Depósito mensal;Receita;Receita;1500,00
```

Os valores de `Tipo` aceitos são `Receita` ou `Despesa`; as datas podem estar em `DD/MM/AAAA` ou `AAAA-MM-DD`. Verifique se o arquivo atualmente no bucket tem esses campos e valores. Um CSV com cabeçalho `Data;Descrição;Categoria;Tipo;Valor` foi encontrado na Biblioteca e passou no parser local com 341 registros válidos, mas ainda não foi confirmado como o mesmo arquivo armazenado no bucket.

Substitua o objeto no Storage mantendo o nome exato `lancamentos.csv`. Não coloque dados financeiros reais no repositório público.

## 6. Resultado do reteste

- **Site GitHub Pages:** abre o painel.
- **Google OAuth:** validado com uma conta Google.
- **Sessão e usuário:** validados no navegador.
- **Download no Storage:** funcionou para a conta atualmente autenticada.
- **Autorização no Storage:** a consulta do objeto passou; ainda falta testar uma conta não autorizada.
- **Leitura dos lançamentos:** pendente, pois o arquivo atual não passou na validação do formato.
- **Lista de autorização:** três registros ativos; um precisa ser corrigido após confirmar o endereço certo.

## Arquitetura

- GitHub Pages hospeda apenas a interface.
- Supabase Auth autentica as contas Google.
- `private.portal_access` mantém a lista de autorização.
- Supabase Storage guarda o CSV em bucket privado.
- O navegador utiliza somente a publishable key, nunca uma chave secreta.
