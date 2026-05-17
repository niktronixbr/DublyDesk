# DublyDesk

Aplicativo mobile para gestão de escalas e finanças de profissionais de dublagem. Monorepo com Flutter app (Android/iOS/Windows) e API REST em Node.js/Express com PostgreSQL.

**Produção:** `https://api.dublydesk.com`

## Estrutura

```
apps/
  app/   ← Flutter app (Dart, multiplataforma)
  api/   ← API REST Node.js/Express
```

## Stack

| Camada | Tecnologia |
|--------|-----------|
| Mobile | Flutter 3.11+ / Dart |
| State | StatefulWidget + ChangeNotifier |
| HTTP | `http` package |
| Local storage | `shared_preferences` |
| Notificações | `flutter_local_notifications` |
| Calendário | `table_calendar` |
| Gráficos | `fl_chart` |
| API | Node.js + Express 4 |
| Auth | JWT (7 dias) + bcryptjs |
| Banco | PostgreSQL (pg pool) |
| Email | Nodemailer |

## Rodar localmente

### API
```bash
cd apps/api
cp .env.example .env   # configurar JWT_SECRET, DATABASE_URL, SMTP_*
npm install
node server.js         # porta 3000
```

### Flutter app
```bash
cd apps/app
flutter pub get
flutter run            # escolher dispositivo
```

### Tudo junto via Docker (API + Postgres)
```bash
docker compose up      # na raiz do monorepo
```

## Deploy

Produção em VPS Hostinger orquestrada pelo EasyPanel:
- `dublydesk-api` (Node.js, porta 3000) servido via `api.dublydesk.com`
- `dublydesk-db` (PostgreSQL)
- TLS Let's Encrypt automático via Caddy interno do EasyPanel

## Documentação

- [CLAUDE.md](./CLAUDE.md) — guia de uso pra assistentes IA, com mapa de rotas e variáveis de ambiente
- [Docs/superpowers/](./Docs/superpowers/) — specs e planos de features (detecção de conflito de horário, etc)

## Convenções

Commits seguem [Conventional Commits](https://www.conventionalcommits.org/): `feat:`, `fix:`, `chore:`, `refactor:`, `style:`, `docs:`, `test:`.

## Domínio

`dublydesk.com` (registrado via Hostinger). Subdomínios:
- `api.dublydesk.com` — API em produção
- `app.dublydesk.com` — reservado pro futuro PWA web
- `dublydesk.com` / `www` — landing page futura
