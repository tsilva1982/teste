# Configuração de acesso seguro — Prestação de Contas

O portal foi preparado para usar Google OAuth com Supabase Auth e proteger o arquivo financeiro em um bucket privado do Supabase Storage. O CSV não deve permanecer no repositório público do GitHub.

## 1. Criar um projeto Supabase

1. Crie um projeto no Supabase.
2. Abra **Project Settings → API** (ou **API Keys**).
3. Copie a **Project URL** e a **publishable key** (ou a chave legada `anon`).
4. Abra `supabase-config.js` e substitua os dois valores de exemplo.
5. Nunca use uma chave `service_role` ou `secret` no navegador ou no GitHub.

A publishable/anon key é identificadora do projeto, não é uma senha. A proteção efetiva é feita pelas políticas RLS instaladas no banco e no Storage. A aplicação usa o fluxo OAuth PKCE e mantém a sessão no navegador.

## 2. Instalar as políticas de segurança

1. No Supabase, abra **SQL Editor**.
2. Abra o arquivo `supabase_setup.sql` deste diretório.
3. Cole o conteúdo no SQL Editor e execute.
4. O script cria a lista privada de contas autorizadas, uma função de verificação e o bucket privado `prestacao-contas`.
5. A política permite somente leitura do objeto `lancamentos.csv) por contas autenticadas e autorizadas.

## 3. Autorizar os e-mails

No SQL Editor, execute o comando abaixo substituindo os exemplos pelos endereços Google que poderão acessar o portal:

```sql
insert into private.portal_access (email)
values
  ('seu.email@gmail.com'),
  ('pessoa.autorizada@gmail.com')
on conflict (email) do update set enabled = true;
```

Use letras minúsculas. Para revogar alguém:

```sql
update private.portal_access
set enabled = false
where email = 'pessoa.autorizada@gmail.com';
```

Não coloque essa lista no HTML ou no JavaScript público.

## 4. Configurar o login Google

1. No Google Cloud Console, configure a tela de consentimento OAuth e crie uma credencial OAuth do tipo **Web application**.
2. Em **Authorized JavaScript origins**, adicione a origem publicada do site, por exemplo:
   `https://tsilva1982.github.io`
3. Em **Authorized redirect URIs**, adicione o callback mostrado pelo Supabase em **Authentication → Providers → Google**. O formato é:
   `https://SEU-PROJETO.supabase.co/auth/v1/callback`
4. No Supabase, abra **Authentication → Providers → Google**, habilite Google e informe o Client ID e Client Secret do Google.
5. Em **Authentication → URL Configuration**, configure a Site URL como:
   `https://tsilva1982.github.io/teste/prestacao_contas/index.html`
   e inclua como Redirect URL:
   `https://tsilva1982.github.io/teste/prestacao_contas/**`
6. Se a tela de consentimento Google estiver em modo **Testing**, inclua cada conta autorizada também na lista de usuários de teste do Google.
7. Salve as configurações.

O Client Secret do Google deve ficar somente no painel do Supabase. Não o inclua no GitHub nem no JavaScript.

## 5. Colocar o CSV em armazenamento privado

1. No Supabase, abra **Storage**.
2. Localize o bucket privado `prestacao-contas` criado pelo SQL.
3. Faça upload do arquivo com o nome exato `lancamentos.csv`.
4. Preserve o cabeçalho e o formato esperado:

```csv
Data;Descrição;Categoria;Tipo;Valor
05/11/2026;Pagamento cuidador;Serviços;Despesa;2000,00
10/11/2026;Depósito mensal;Receita;Receita;1500,00
```

Atualize esse arquivo no Storage quando precisar renovar os lançamentos. Não envie dados financeiros reais ao repositório público do GitHub.

## 6. Publicação e testes

1. Habilite o GitHub Pages para o repositório e publique a partir da branch `main`.
2. Abra a página inicial e teste **Entrar com Google** com um e-mail autorizado.
3. Teste também com uma conta Google que não esteja na lista: ela poderá autenticar no Google, mas não poderá baixar o CSV nem visualizar os lançamentos.
4. Confirme que o CSV não abre por URL pública e que, após sair, o painel redireciona ao login.

## Arquitetura e limites

- O GitHub hospeda apenas arquivos de interface, instruções e configuração pública do cliente.
- O Supabase Auth autentica a conta Google.
- A lista de autorização fica em um schema privado do banco.
- O CSV fica em um bucket privado com política RLS.
- O navegador usa apenas a publishable/anon key. Nunca use a service_role/secret key no front-end.

A alteração dos arquivos do site não cria automaticamente um projeto Supabase, credenciais OAuth do Google nem autoriza os e-mails. Essas configurações precisam ser concluídas nos respectivos painéis.
