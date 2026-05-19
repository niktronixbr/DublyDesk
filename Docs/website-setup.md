# Setup do website dublydesk.com

Guia passo-a-passo pra colocar o site (`apps/web/`) no ar em `dublydesk.com` + configurar emails do domínio. Tudo gratuito.

**Pré-requisitos:**
- Conta GitHub (já tem — repo `niktronixbr/DublyDesk`)
- Domínio `dublydesk.com` registrado (já tem, na Hostinger)
- Caixa de email pessoal pra receber forwards (`niktronix.br@gmail.com`)

**Tempo estimado:** ~40 min na primeira vez.

---

## Parte 1 — Deploy do site no Vercel (~10 min)

### 1.1 Criar conta Vercel

Acesse [vercel.com/signup](https://vercel.com/signup) e cadastre-se com GitHub. O free tier (Hobby Plan) cobre o uso de páginas legais + landing com folga (100GB bandwidth/mês, build minutes ilimitados pra projetos pessoais).

### 1.2 Importar o repo

1. Dashboard Vercel → **Add New** → **Project**
2. Escolha **Import Git Repository** e selecione `niktronixbr/DublyDesk`
3. Na tela de configuração:
   - **Framework Preset**: Next.js (autodetectado)
   - **Root Directory**: clique em **Edit** e selecione `apps/web`
   - **Build Command**: deixe o default (`npm run build`)
   - **Output Directory**: deixe o default
   - **Install Command**: deixe o default
4. **Deploy**

O primeiro deploy gera uma URL tipo `dubly-desk-xxxx.vercel.app`. Acesse pra confirmar que funciona.

### 1.3 Conectar o domínio dublydesk.com

1. No projeto Vercel → **Settings** → **Domains**
2. Adicionar `dublydesk.com` e `www.dublydesk.com`
3. Vercel vai mostrar os registros DNS que precisam ser configurados — **deixe essa tela aberta**, vamos voltar nela depois do Cloudflare.

> **Importante:** **não** aponte `api.dublydesk.com` pro Vercel — esse subdomínio continua na VPS Hostinger via EasyPanel.

---

## Parte 2 — Mover DNS pra Cloudflare (~15 min)

A Cloudflare é necessária pra ter Email Routing gratuito. Mover o DNS também acelera o site (CDN) e permite controle granular.

### 2.1 Criar conta Cloudflare

[dash.cloudflare.com/sign-up](https://dash.cloudflare.com/sign-up) — gratuito, sem cartão.

### 2.2 Adicionar o site

1. Dashboard Cloudflare → **+ Add a Site**
2. Digite `dublydesk.com` → **Continue**
3. Plano: **Free** → **Continue**
4. Cloudflare faz scan dos registros DNS atuais. Confira se todos os registros importantes foram detectados (especialmente os de `api.dublydesk.com`).

### 2.3 Trocar nameservers na Hostinger

A Cloudflare vai mostrar 2 nameservers tipo `xxx.ns.cloudflare.com` e `yyy.ns.cloudflare.com`. Anote.

1. Acesse o painel da Hostinger
2. **Domínios** → `dublydesk.com` → **Nameservers**
3. Mude de **Hostinger nameservers** pra **Custom nameservers**
4. Cole os 2 nameservers do Cloudflare e salve

A propagação leva de 10 minutos a algumas horas. A Cloudflare envia email quando o domínio está ativo.

### 2.4 Configurar DNS no Cloudflare

No Cloudflare → **DNS** → **Records**, garanta que tenha:

| Type | Name | Value | Proxy |
|------|------|-------|-------|
| A | `api` | `177.7.33.130` (IP da VPS Hostinger) | **DNS only** (cinza) |
| CNAME | `@` | `cname.vercel-dns.com` | DNS only |
| CNAME | `www` | `cname.vercel-dns.com` | DNS only |

> **Por que "DNS only" e não "Proxied"?**
> - Em `api.dublydesk.com`: o EasyPanel gerencia SSL — Cloudflare proxy interferiria.
> - Em `@`/`www`: o Vercel já tem CDN próprio.

Apague registros antigos que apontavam pro Hostinger nos slots `@` e `www`, se existirem.

### 2.5 Validar no Vercel

Volte na tela do Vercel (Settings → Domains). Após propagação, os domínios `dublydesk.com` e `www.dublydesk.com` aparecem como **Valid Configuration** com SSL ativo automaticamente.

Acesse `https://dublydesk.com` e `https://dublydesk.com/termos` pra confirmar.

---

## Parte 3 — Email Routing (~10 min)

### 3.1 Habilitar Email Routing

1. Cloudflare → projeto `dublydesk.com` → **Email** → **Email Routing**
2. Clique em **Get started**
3. Cloudflare adiciona automaticamente os MX records e o SPF necessários. Aceite.

### 3.2 Criar destination address

1. Aba **Destination addresses** → **Add destination address**
2. Email: `niktronix.br@gmail.com`
3. Cloudflare envia email de verificação — clique no link recebido no Gmail.

### 3.3 Criar custom addresses

Aba **Routing rules** → **Create address**:

**Endereço 1:**
- Custom address: `contato`
- Action: **Send to**
- Destination: `niktronix.br@gmail.com`

**Endereço 2:**
- Custom address: `dpo`
- Action: **Send to**
- Destination: `niktronix.br@gmail.com`

Ative ambos.

### 3.4 Testar

Mande um email de outra conta pra `contato@dublydesk.com` e `dpo@dublydesk.com`. Devem cair no Gmail em segundos.

---

## Parte 4 — Validações finais

- [ ] `https://dublydesk.com` carrega a landing
- [ ] `https://dublydesk.com/termos` mostra os Termos de Uso
- [ ] `https://dublydesk.com/privacidade` mostra a Política de Privacidade
- [ ] SSL/HTTPS funcionando (cadeado no navegador)
- [ ] `https://www.dublydesk.com` redireciona pra `https://dublydesk.com` (Vercel faz isso automaticamente quando você adiciona o www)
- [ ] `https://api.dublydesk.com/health` ainda retorna `{"ok": true}` (API não quebrou)
- [ ] Email pra `contato@dublydesk.com` chega no Gmail
- [ ] Email pra `dpo@dublydesk.com` chega no Gmail
- [ ] SPF/DKIM/DMARC ativos (Cloudflare configura automaticamente)

---

## Próximos passos pós-publicação

Com o site no ar, você desbloqueia:

1. **Submissão no Google Play Console** — links de Termos e Privacidade são obrigatórios na ficha do app
2. **Stripe live mode** — exige Política de Privacidade pública pra validar a conta
3. **Internal testing track na Play** — preparar o app pra release com applicationId correto (`br.com.dublydesk.app` — ainda precisa trocar)

---

## Manutenção contínua

- **Atualizar Termos ou Privacidade**: edite os arquivos em `apps/web/app/termos/page.tsx` ou `app/privacidade/page.tsx`, commit + push. Vercel faz deploy automático. Lembre de atualizar a constante `ULTIMA_ATUALIZACAO` no topo de cada página.
- **Preview de mudanças**: cada PR no GitHub gera uma URL de preview no Vercel. Útil pra revisar textos antes de mergear pra main.
- **Logs e analytics**: Vercel → projeto → **Logs** e **Analytics**. Free tier inclui Web Analytics básico — vale ativar.

---

## Custos recorrentes

| Serviço | Plano | Custo |
|---------|-------|-------|
| Domínio `dublydesk.com` | Hostinger registrar | ~R$50/ano (já pago) |
| Vercel | Hobby | R$ 0 |
| Cloudflare DNS + Email Routing | Free | R$ 0 |
| **Total adicional** | | **R$ 0/mês** |
