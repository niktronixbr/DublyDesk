# DublyDesk

Aplicativo mobile para gestão de escalas e finanças de profissionais de dublagem. Monorepo com Flutter app (`apps/app`) e API Node.js/Express (`apps/api`), PostgreSQL como banco de dados.

**Deploy:** API em `https://dublydesk.onrender.com` (Render). GitHub: `https://github.com/niktronixbr/DublyDesk`.

## Estrutura

```
apps/
  app/   ← Flutter (Dart) — mobile Android/iOS/Windows
  api/   ← Node.js/Express — REST API + PostgreSQL
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

## Variáveis de ambiente (apps/api/.env)

```env
PORT=3000
DATABASE_URL=postgresql://user:pass@host:5432/dublagem
JWT_SECRET=seu_segredo_jwt
FRONTEND_ORIGIN=*

# Email (reset de senha)
EMAIL_USER=email@gmail.com
EMAIL_PASS=senha_app_gmail

# Docker (sem DATABASE_URL)
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres
POSTGRES_DB=dublagem
```

## Rotas da API

| Método | Rota | Descrição |
|--------|------|-----------|
| POST | `/auth/register` | Cadastro |
| POST | `/auth/login` | Login → JWT |
| POST | `/auth/forgot-password` | Envia código de 6 dígitos |
| POST | `/auth/reset-password` | Redefine senha com código |
| GET | `/schedules` | Lista escalas (paginado, filtros) |
| POST | `/schedules` | Cria escala |
| PUT | `/schedules/:id` | Atualiza escala |
| DELETE | `/schedules/:id` | Remove escala |
| GET | `/schedules/summary` | Resumo financeiro |
| GET/POST | `/produtoras` | Produtoras do usuário |
| GET/POST | `/projetos` | Projetos do usuário |
| GET/POST | `/diretores` | Diretores do usuário |
| GET | `/health` | Health check |

Todas as rotas (exceto `/auth/*` e `/health`) requerem `Authorization: Bearer <token>`.

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

## Skills disponíveis

- `dublydesk-architecture` — mapa completo da estrutura do projeto
- `dublydesk-conventions` — padrões de código Flutter e Node.js
