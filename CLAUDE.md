# DublyDesk

Aplicativo mobile para gestão de escalas e finanças de profissionais de dublagem. Monorepo com Flutter app (`apps/app`), API Node.js/Express (`apps/api`) e site institucional Next.js (`apps/web`), PostgreSQL como banco de dados.

**Deploy:**
- API em `https://api.dublydesk.com` (VPS Hostinger via EasyPanel)
- Site em `https://dublydesk.com` (Vercel — landing + termos + privacidade)
- GitHub: `https://github.com/niktronixbr/DublyDesk`

## Estrutura

```
apps/
  app/   ← Flutter (Dart) — mobile Android/iOS/Windows
  api/   ← Node.js/Express — REST API + PostgreSQL
  web/   ← Next.js 16 + Tailwind v4 — landing + páginas legais
```

## Rodar localmente

### API
```bash
cd apps/api
cp .env.example .env   # configurar variáveis
npm install
node server.js         # sobe na porta 3000
```

### Flutter app
```bash
cd apps/app
flutter pub get
flutter run            # escolher dispositivo
```

### Site Next.js
```bash
cd apps/web
npm install
npm run dev            # sobe em http://localhost:3000
```

### Com Docker (API + banco)
```bash
# Na raiz do projeto
docker compose up      # sobe PostgreSQL + API
```

## Stack

| Camada | Tecnologia |
|--------|-----------|
| Mobile | Flutter 3.11+, Dart |
| State | StatefulWidget + ThemeService (ChangeNotifier) |
| HTTP | `http` package |
| Local storage | `shared_preferences` |
| Notificações | `flutter_local_notifications` |
| Calendário | `table_calendar` |
| Gráficos | `fl_chart` |
| Localização | `intl`, pt_BR |
| API | Node.js + Express 4 |
| Auth | JWT (7 dias) + bcryptjs |
| Banco | PostgreSQL (pg pool) |
| Email | Nodemailer |
| Rate limiting | express-rate-limit |
| Validação | express-validator |
| Site institucional | Next.js 16 (App Router) + Tailwind v4 + TypeScript |
| Site hosting | Vercel (free tier, deploy automático via Git) |
| Email do domínio | Cloudflare Email Routing (contato@ + dpo@ → Gmail) |

## Variáveis de ambiente (apps/api/.env)

```env
PORT=3000
DATABASE_URL=postgresql://user:pass@host:5432/dublagem
JWT_SECRET=seu_segredo_jwt
FRONTEND_ORIGIN=*

# Email SMTP (reset de senha) — variáveis usadas pelo código
SMTP_HOST=smtp.gmail.com
SMTP_PORT=587
SMTP_USER=email@gmail.com
SMTP_PASS=senha_app_gmail

# Docker (sem DATABASE_URL)
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=dublagem

# Stripe (cobrança web)
STRIPE_SECRET_KEY=sk_...
STRIPE_WEBHOOK_SECRET=whsec_...
STRIPE_PRICE_MONTHLY=price_...
STRIPE_PRICE_ANNUAL=price_...
FRONTEND_WEB_URL=https://app.dublydesk.com

# Google Play (billing Android)
PLAY_PACKAGE_NAME=br.com.dublydesk.app
PLAY_SERVICE_ACCOUNT_PATH=./.secrets/play-service-account.json
```

## Rotas da API

| Método | Rota | Descrição |
|--------|------|-----------|
| POST | `/auth/register` | Cadastro |
| POST | `/auth/login` | Login → JWT |
| POST | `/auth/forgot-password` | Envia código de 6 dígitos |
| POST | `/auth/reset-password` | Redefine senha com código |
| POST | `/auth/change-password` | Altera senha (requer JWT + senha atual) |
| GET | `/schedules` | Lista escalas (paginado, filtros) |
| POST | `/schedules` | Cria escala |
| PUT | `/schedules/:id` | Atualiza escala |
| DELETE | `/schedules/:id` | Remove escala |
| GET | `/schedules/summary` | Resumo financeiro |
| GET/POST | `/produtoras` | Produtoras do usuário |
| GET/POST | `/projetos` | Projetos do usuário |
| GET/POST | `/diretores` | Diretores do usuário |
| GET | `/me/entitlements` | Estado da assinatura Pro |
| POST | `/billing/stripe/checkout` | Cria Stripe Checkout Session (web) |
| POST | `/billing/stripe/webhook` | Recebe eventos Stripe (HMAC) |
| POST | `/billing/stripe/portal` | Cria Stripe Customer Portal Session |
| POST | `/billing/play/verify` | Valida purchaseToken Android |
| POST | `/billing/restore` | Re-valida compras Play do usuário |
| POST | `/receipts/generate` | Gera PDF de recibo (Pro) |
| POST | `/receipts/:id/send-email` | Envia recibo por email (Pro) |
| GET | `/receipts/pending` | Lista escalas a receber + total |
| PATCH | `/schedules/:id/payment` | Atualiza status de pagamento |
| GET | `/health` | Health check |

Todas as rotas (exceto `/auth/register`, `/auth/login`, `/auth/forgot-password`, `/auth/reset-password` e `/health`) requerem `Authorization: Bearer <token>`.

## Banco de dados

Tabelas criadas automaticamente pelo `server.js` na inicialização:
- `users` — autenticação
- `schedules` — escalas com dados financeiros
- `projetos`, `produtoras`, `diretores` — entidades por usuário
- `password_resets` — tokens de recuperação com expiração

## Convenções de commit

```
feat:  nova funcionalidade
fix:   correção de bug
chore: tarefas de manutenção (deps, build, config)
refactor: refatoração sem mudança de comportamento
style: formatação, lint
docs:  documentação
```

## Site institucional (apps/web)

Next.js 16 com App Router + Tailwind v4. Hospedado em `https://dublydesk.com` (Vercel). Rotas:

- `/` — landing placeholder ("em breve no Google Play")
- `/termos` — Termos de Uso (qualificação PJ Niktronix, foro Osasco/SP)
- `/privacidade` — Política de Privacidade LGPD (controlador, encarregado dpo@, bases legais)

Emails do domínio via Cloudflare Email Routing (gratuito): `contato@dublydesk.com` e `dpo@dublydesk.com` encaminham pra `niktronix.br@gmail.com`.

Guia completo de DNS + Vercel + Cloudflare: [Docs/website-setup.md](Docs/website-setup.md).

## Skills disponíveis

- `dublydesk-architecture` — mapa completo da estrutura do projeto
- `dublydesk-conventions` — padrões de código Flutter e Node.js
