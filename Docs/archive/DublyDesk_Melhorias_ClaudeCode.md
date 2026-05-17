# 🛠️ DublyDesk — Guia de Melhorias para Implementação
### VS Code + Claude Code — Versão pós-MVP

---

## Como usar este documento

Este arquivo é o **prompt-base de contexto** para o Claude Code.
Cole o conteúdo relevante de cada seção diretamente no terminal do Claude Code antes de iniciar cada tarefa.
A ordem das seções representa a **prioridade de implementação recomendada**.

---

## Contexto do projeto

```
App Flutter chamado DublyDesk para gestão de escalas de dublagem.
Backend: Node.js + Express. Banco: PostgreSQL no Render.
Autenticação JWT, controle financeiro, notificações locais.
MVP funcional. Foco desta fase: robustez, arquitetura e novas features.
```

---

## FASE 1 — Refatoração crítica (fazer primeiro)

### 1.1 Separar `main.dart` em camadas

**Problema:** `main.dart` concentra estado, CRUD, UI, filtros e busca — padrão God Widget.

**Nova estrutura de pastas:**

```
lib/
├── core/
│   ├── models/
│   │   ├── schedule_model.dart
│   │   └── user_model.dart
│   ├── services/
│   │   ├── api_service.dart        ← todas as chamadas HTTP centralizadas
│   │   ├── auth_service.dart       ← mantém, refatorar para usar api_service
│   │   └── notification_service.dart ← mantém
│   └── constants/
│       └── api_config.dart         ← mantém
├── features/
│   ├── auth/
│   │   ├── login_page.dart
│   │   └── register_page.dart
│   ├── schedules/
│   │   ├── schedule_list_page.dart ← extraído de main.dart
│   │   ├── schedule_form_page.dart ← criar/editar escala
│   │   └── schedule_card.dart      ← widget do card isolado
│   └── finance/
│       └── finance_page.dart       ← mantém, conectar a novo endpoint
└── shared/
    └── widgets/
        ├── loading_widget.dart
        └── error_widget.dart
```

**Prompt para Claude Code:**

```
Refatore o main.dart do projeto Flutter DublyDesk.
Extraia a lógica de estado e CRUD para um arquivo schedule_list_page.dart.
Crie um schedule_form_page.dart para criar e editar escalas.
Crie um schedule_card.dart com o widget do card isolado.
Crie um api_service.dart centralizando todas as chamadas HTTP (get, post, put, delete para /schedules).
O main.dart deve ficar apenas com: inicialização do app, verificação de sessão e roteamento.
Mantenha toda a lógica de negócio existente intacta.
```

---

### 1.2 Criar `api_service.dart` centralizado

**Problema:** chamadas HTTP espalhadas, sem tratamento de erro padronizado, sem interceptor para token expirado.

**Implementação esperada:**

```dart
// lib/core/services/api_service.dart

class ApiService {
  final String baseUrl = 'https://dublydesk.onrender.com';

  Future<Map<String, dynamic>> get(String endpoint, String token) async { }
  Future<Map<String, dynamic>> post(String endpoint, Map body, {String? token}) async { }
  Future<Map<String, dynamic>> put(String endpoint, Map body, String token) async { }
  Future<bool> delete(String endpoint, String token) async { }

  // Tratar 401 → limpar sessão e redirecionar para login
  void _handleUnauthorized(BuildContext context) { }
}
```

**Prompt para Claude Code:**

```
Crie o arquivo lib/core/services/api_service.dart no projeto Flutter DublyDesk.
Centralize todos os métodos HTTP (GET, POST, PUT, DELETE).
Adicione tratamento para status 401 (token expirado): limpar shared_preferences e redirecionar para login.
Adicione timeout de 15 segundos nas requisições para lidar com cold start do Render.
Adicione try/catch padronizado retornando Map com chaves 'success', 'data' e 'error'.
```

---

### 1.3 Criar `schedule_model.dart`

**Problema:** dados da escala são tratados como `Map<String, dynamic>` solto em todo o app.

**Implementação esperada:**

```dart
// lib/core/models/schedule_model.dart

class ScheduleModel {
  final int id;
  final String projeto;
  final String produtora;
  final String? diretor;
  final DateTime data;
  final String horaInicio;
  final String horaFim;
  final double valorHora;
  final double valorTotal;
  final bool realizado;
  final DateTime createdAt;

  factory ScheduleModel.fromJson(Map<String, dynamic> json) { ... }
  Map<String, dynamic> toJson() { ... }
}
```

**Prompt para Claude Code:**

```
Crie o arquivo lib/core/models/schedule_model.dart no projeto Flutter DublyDesk.
O modelo deve ter todos os campos da tabela schedules do banco PostgreSQL:
id, projeto, produtora, diretor (nullable), data, horaInicio, horaFim,
valorHora, valorTotal, realizado, createdAt.
Implemente factory fromJson e método toJson.
Substitua todos os Map<String, dynamic> no schedule_list_page.dart pelo ScheduleModel.
```

---

## FASE 2 — Backend: segurança e endpoints que faltam

### 2.1 Adicionar rate limiting nas rotas de auth

**Problema:** sem rate limiting, as rotas `/auth/register` e `/auth/login` ficam vulneráveis a brute force.

**Dependência a instalar:**

```bash
npm install express-rate-limit
```

**Implementação esperada em `routes/auth.js`:**

```js
const rateLimit = require('express-rate-limit');

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 minutos
  max: 10,
  message: { error: 'Muitas tentativas. Tente novamente em 15 minutos.' }
});

router.post('/login', loginLimiter, async (req, res) => { ... });
router.post('/register', loginLimiter, async (req, res) => { ... });
```

**Prompt para Claude Code:**

```
No backend Node.js do DublyDesk, instale express-rate-limit e aplique nas rotas POST /auth/login e POST /auth/register.
Limite: 10 tentativas a cada 15 minutos por IP.
Mensagem de erro em português.
Não alterar nenhuma outra lógica existente.
```

---

### 2.2 Adicionar validação de dados no backend

**Problema:** validação existe só no Flutter. Dados inválidos podem chegar diretamente via API.

**Dependência a instalar:**

```bash
npm install express-validator
```

**Implementação esperada em `routes/schedules.js`:**

```js
const { body, validationResult } = require('express-validator');

const scheduleValidation = [
  body('projeto').trim().notEmpty().withMessage('Projeto é obrigatório'),
  body('produtora').trim().notEmpty().withMessage('Produtora é obrigatória'),
  body('data').isISO8601().withMessage('Data inválida'),
  body('hora_inicio').matches(/^\d{2}:\d{2}$/).withMessage('Hora início inválida'),
  body('hora_fim').matches(/^\d{2}:\d{2}$/).withMessage('Hora fim inválida'),
  body('valor_hora').isFloat({ min: 0.01 }).withMessage('Valor/hora inválido'),
];
```

**Prompt para Claude Code:**

```
No backend Node.js do DublyDesk, instale express-validator.
Adicione validação nos endpoints POST /schedules e PUT /schedules/:id com as regras:
- projeto: obrigatório, não vazio
- produtora: obrigatório, não vazio
- data: formato ISO8601 válido
- hora_inicio e hora_fim: formato HH:mm
- valor_hora: número positivo maior que zero
- hora_fim deve ser maior que hora_inicio (validação lógica)
Retornar status 400 com array de erros se a validação falhar.
```

---

### 2.3 Criar endpoint financeiro `/schedules/summary`

**Problema:** o cálculo financeiro é feito no Flutter somando registros locais. Dados fora de sincronia geram totais errados.

**Implementação esperada em `routes/schedules.js`:**

```js
// GET /schedules/summary
router.get('/summary', authMiddleware, async (req, res) => {
  const userId = req.user.id;
  const result = await db.query(`
    SELECT
      COUNT(*) FILTER (WHERE realizado = true)  AS count_realizado,
      COUNT(*) FILTER (WHERE realizado = false) AS count_pendente,
      COALESCE(SUM(valor_total) FILTER (WHERE realizado = true), 0) AS total_realizado,
      COALESCE(SUM(valor_total) FILTER (WHERE realizado = false), 0) AS total_pendente
    FROM schedules
    WHERE user_id = $1
  `, [userId]);
  res.json(result.rows[0]);
});
```

**Prompt para Claude Code:**

```
No backend Node.js do DublyDesk, adicione o endpoint GET /schedules/summary.
Ele deve retornar para o usuário autenticado:
- count_realizado: quantidade de escalas realizadas
- count_pendente: quantidade de escalas pendentes
- total_realizado: soma de valor_total das escalas realizadas
- total_pendente: soma de valor_total das escalas pendentes
Usar a query SQL com FILTER (WHERE ...) para calcular no banco.
Proteger com o middleware de autenticação JWT existente.
```

---

### 2.4 Adicionar paginação no `GET /schedules`

**Problema:** sem paginação, a rota retorna todos os registros do usuário de uma vez.

**Implementação esperada:**

```js
// GET /schedules?page=1&limit=20&produtora=X&realizado=true
router.get('/', authMiddleware, async (req, res) => {
  const { page = 1, limit = 20, produtora, realizado } = req.query;
  const offset = (page - 1) * limit;

  // construir query dinâmica com filtros opcionais
  // retornar: { data: [...], total, page, totalPages }
});
```

**Prompt para Claude Code:**

```
No backend Node.js do DublyDesk, adicione paginação na rota GET /schedules.
Parâmetros via query string: page (padrão 1), limit (padrão 20).
Manter os filtros existentes: produtora e realizado.
Retornar objeto com: { data: [...escalas], total, page, totalPages }.
Atualizar o Flutter para consumir a nova resposta paginada.
```

---

### 2.5 Implementar refresh token

**Problema:** quando o JWT expira, o usuário perde a sessão sem aviso e precisa fazer login manual.

**Dependências:**

```bash
npm install uuid
```

**Implementação esperada:**

```js
// Nova tabela no banco
CREATE TABLE refresh_tokens (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token TEXT NOT NULL UNIQUE,
  expires_at TIMESTAMP NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

// Nova rota
POST /auth/refresh
// Body: { refreshToken }
// Retorna: { token (novo JWT), refreshToken (rotacionado) }

POST /auth/logout
// Invalida o refresh token no banco
```

**Prompt para Claude Code:**

```
No backend Node.js do DublyDesk, implemente refresh token:
1. Criar a tabela refresh_tokens no PostgreSQL (adicionar em db.js na função createTables).
2. No POST /auth/login, gerar e retornar também um refreshToken (UUID, validade 30 dias).
3. Criar POST /auth/refresh que valida o refreshToken, gera novo JWT e rotaciona o refreshToken.
4. Criar POST /auth/logout que invalida o refreshToken no banco.
5. No Flutter, salvar o refreshToken no shared_preferences.
6. No api_service.dart, interceptar erro 401 e tentar renovar o token automaticamente antes de redirecionar para login.
```

---

## FASE 3 — Banco de dados: performance e estrutura

### 3.1 Adicionar índices ao PostgreSQL

**Problema:** queries na tabela `schedules` sem índices ficam lentas conforme o volume cresce.

**Script SQL:**

```sql
-- Índice principal: todas as queries filtram por user_id
CREATE INDEX IF NOT EXISTS idx_schedules_user_id
  ON schedules(user_id);

-- Índice para filtro e ordenação por data
CREATE INDEX IF NOT EXISTS idx_schedules_data
  ON schedules(data DESC);

-- Índice composto para o endpoint /summary e filtros de financeiro
CREATE INDEX IF NOT EXISTS idx_schedules_user_realizado
  ON schedules(user_id, realizado);

-- Índice para busca por produtora
CREATE INDEX IF NOT EXISTS idx_schedules_produtora
  ON schedules(user_id, produtora);
```

**Prompt para Claude Code:**

```
No arquivo db.js do backend DublyDesk, adicione os 4 índices SQL abaixo na função createTables(),
após a criação das tabelas:
- idx_schedules_user_id em schedules(user_id)
- idx_schedules_data em schedules(data DESC)
- idx_schedules_user_realizado em schedules(user_id, realizado)
- idx_schedules_produtora em schedules(user_id, produtora)
Usar CREATE INDEX IF NOT EXISTS para não falhar em banco já existente.
```

---

### 3.2 Criar tabela de produtoras

**Problema:** produtoras são texto livre, permitindo duplicatas como "Globo" e "globo". Dificulta filtros e relatórios.

**Script SQL:**

```sql
CREATE TABLE IF NOT EXISTS produtoras (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  nome TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  UNIQUE(user_id, nome)
);
```

**Novas rotas necessárias:**

```
GET  /produtoras         → lista produtoras do usuário
POST /produtoras         → cria nova produtora
```

**Prompt para Claude Code:**

```
No backend Node.js do DublyDesk:
1. Adicionar a tabela produtoras em db.js (user_id, nome, UNIQUE por usuário).
2. Criar routes/produtoras.js com GET /produtoras e POST /produtoras (protegidos por JWT).
3. Registrar as rotas no server.js.
No Flutter:
4. Ao abrir o formulário de escala, buscar a lista de produtoras do usuário via GET /produtoras.
5. Exibir um Autocomplete ou DropdownButtonFormField com as produtoras existentes.
6. Se o usuário digitar uma nova, criar automaticamente via POST /produtoras ao salvar a escala.
```

---

### 3.3 Adicionar campo `observacao` na tabela `schedules`

**Problema:** não há campo para anotações livres por escala (ex: "levar texto impresso", "sessão remota").

**Script SQL:**

```sql
ALTER TABLE schedules
  ADD COLUMN IF NOT EXISTS observacao TEXT;
```

**Prompt para Claude Code:**

```
No banco PostgreSQL do DublyDesk, adicione a coluna observacao (TEXT, nullable) na tabela schedules.
Adicionar o ALTER TABLE em db.js de forma segura com IF NOT EXISTS via bloco try/catch separado.
Atualizar o ScheduleModel no Flutter para incluir o campo observacao (nullable String).
Adicionar campo opcional de observações no formulário de criação/edição de escala.
Exibir observação no card da escala se não estiver vazia.
```

---

## FASE 4 — UX e experiência do usuário

### 4.1 Tela de loading para cold start do Render

**Problema:** Render free tier tem cold start de 20–30 segundos. O app parece travado sem feedback.

**Implementação esperada:**

```dart
// No api_service.dart, timeout de 30s e estado de loading específico

// Widget de loading com mensagem contextual
class ColdStartLoadingWidget extends StatefulWidget {
  // Mostra spinner normal nos primeiros 3s
  // Após 3s sem resposta, exibe: "Conectando ao servidor..."
  // Após 10s, exibe: "O servidor está acordando, aguarde..."
  // Após 20s, exibe: "Isso pode levar até 30 segundos na primeira vez."
}
```

**Prompt para Claude Code:**

```
No app Flutter DublyDesk, crie um widget ColdStartLoadingWidget em lib/shared/widgets/.
Comportamento:
- 0 a 3s: spinner simples
- 3 a 10s: spinner + "Conectando ao servidor..."
- 10 a 20s: spinner + "O servidor está acordando, aguarde..."
- acima de 20s: spinner + "Isso pode levar até 30 segundos na primeira vez."
Usar este widget na tela de login e na tela principal durante o carregamento inicial.
Implementar com Timer e setState para trocar as mensagens automaticamente.
```

---

### 4.2 Cache local básico (offline-first)

**Problema:** se o Render estiver em cold start ou sem internet, o app mostra tela vazia.

**Implementação esperada:**

```dart
// No api_service.dart ou schedule_list_page.dart

Future<List<ScheduleModel>> getSchedules() async {
  try {
    final response = await http.get(...).timeout(Duration(seconds: 30));
    final schedules = // parse response
    await _saveToLocalCache(schedules); // salvar no shared_preferences
    return schedules;
  } catch (e) {
    final cached = await _loadFromLocalCache();
    if (cached.isNotEmpty) {
      // mostrar banner: "Exibindo dados offline"
      return cached;
    }
    rethrow;
  }
}
```

**Prompt para Claude Code:**

```
No Flutter DublyDesk, implemente cache local básico para escalas:
1. Após cada GET /schedules bem-sucedido, salvar a lista serializada em shared_preferences com chave 'schedules_cache'.
2. Se a requisição falhar (timeout ou sem internet), carregar do cache e exibir banner amarelo: "Você está offline — exibindo dados salvos".
3. Ao voltar online (próxima ação do usuário), sincronizar automaticamente.
4. Limpar o cache no logout.
```

---

### 4.3 Recuperação de senha

**Problema:** sem recuperação de senha não é possível publicar na Play Store com qualidade.

**Backend — novas rotas:**

```
POST /auth/forgot-password  → recebe email, gera token, envia email
POST /auth/reset-password   → recebe token + nova senha, atualiza banco
```

**Nova tabela:**

```sql
CREATE TABLE IF NOT EXISTS password_resets (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  token TEXT NOT NULL UNIQUE,
  expires_at TIMESTAMP NOT NULL,
  used BOOLEAN DEFAULT false,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

**Dependências:**

```bash
npm install nodemailer crypto
```

**Prompt para Claude Code:**

```
No backend Node.js do DublyDesk, implemente recuperação de senha:
1. Criar tabela password_resets em db.js (user_id, token, expires_at, used).
2. Criar POST /auth/forgot-password: receber email, gerar token seguro com crypto.randomBytes(32).toString('hex'), salvar no banco com validade de 1 hora, enviar email com nodemailer usando variáveis de ambiente SMTP_HOST, SMTP_USER, SMTP_PASS.
3. Criar POST /auth/reset-password: validar token (não expirado, não usado), atualizar senha com bcrypt, marcar token como usado.
No Flutter:
4. Adicionar link "Esqueci minha senha" na login_page.
5. Criar forgot_password_page.dart com campo de email e feedback de envio.
6. Criar reset_password_page.dart com campos de nova senha e confirmação.
```

---

### 4.4 Melhorar tela financeira com métricas

**Problema:** a tela financeira atual só mostra o total realizado. Falta contexto comparativo.

**Novos dados a exibir (consumindo o endpoint `/schedules/summary`):**

```dart
// Cards de métricas na finance_page.dart:
// - Total realizado (R$)
// - Total pendente (R$)
// - Quantidade de escalas realizadas
// - Quantidade de escalas pendentes
// - Média por escala realizada
// - Mês atual vs mês anterior (se disponível)
```

**Prompt para Claude Code:**

```
Atualize o finance_page.dart do Flutter DublyDesk para consumir o endpoint GET /schedules/summary.
Exibir 4 cards de métricas: total realizado, total pendente, quantidade realizada, quantidade pendente.
Calcular e exibir: média por escala realizada = total_realizado / count_realizado.
Manter o tema dark premium existente.
Adicionar pull-to-refresh na tela financeira.
Exibir skeleton loading enquanto os dados carregam.
```

---

### 4.5 Configurações de lembrete por escala

**Problema:** todos recebem os mesmos lembretes fixos (30min, 5min, horário). Não há personalização.

**Implementação esperada:**

```dart
// No formulário de escala, nova seção "Lembretes":
// Checkbox: 1 hora antes
// Checkbox: 30 minutos antes (padrão: marcado)
// Checkbox: 5 minutos antes (padrão: marcado)
// Checkbox: no horário exato (padrão: marcado)

// Salvar preferências junto com a escala (campo JSON ou colunas booleanas)
```

**Novo campo no banco:**

```sql
ALTER TABLE schedules
  ADD COLUMN IF NOT EXISTS lembretes JSONB DEFAULT '{"60min": false, "30min": true, "5min": true, "exato": true}';
```

**Prompt para Claude Code:**

```
No DublyDesk, adicione personalização de lembretes por escala:
Backend: adicionar coluna lembretes (JSONB) na tabela schedules com default {"60min":false,"30min":true,"5min":true,"exato":true}.
Flutter: adicionar seção "Lembretes" no formulário de escala com 4 checkboxes.
Atualizar o notification_service.dart para agendar apenas os lembretes selecionados.
Atualizar o ScheduleModel para incluir o campo lembretes.
Manter compatibilidade com escalas antigas (sem o campo) usando o default true para 30min, 5min e exato.
```

---

## FASE 5 — Publicação na Play Store

### 5.1 Preparar o app para release

**Checklist de preparação:**

```bash
# 1. Gerar keystore (fazer UMA VEZ e guardar em local seguro)
keytool -genkey -v -keystore ~/dublydesk-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias dublydesk

# 2. Configurar assinatura em android/key.properties
storePassword=SUA_SENHA
keyPassword=SUA_SENHA
keyAlias=dublydesk
storeFile=/caminho/para/dublydesk-release.jks

# 3. Gerar AAB (formato exigido pela Play Store)
flutter build appbundle --release

# 4. Verificar tamanho e permissões
```

**Prompt para Claude Code:**

```
No projeto Flutter DublyDesk, prepare o app para publicação na Play Store:
1. Atualizar android/app/build.gradle.kts com a configuração de signingConfigs para release usando key.properties.
2. Mudar applicationId de "com.example.dublydesk" para um ID único (ex: "br.com.dublydesk.app").
3. Verificar e atualizar versionCode e versionName no pubspec.yaml.
4. Adicionar ícone do app em todos os tamanhos necessários (usar flutter_launcher_icons).
5. Verificar se todas as permissões no AndroidManifest.xml têm justificativa válida para o review da Play Store.
6. Gerar o arquivo AAB com flutter build appbundle --release.
```

---

### 5.2 Atualizar `applicationId`

**Problema:** o ID atual `com.example.dublydesk` é um placeholder. A Play Store rejeita apps com `com.example`.

**Arquivo:** `android/app/build.gradle.kts`

```kotlin
defaultConfig {
    applicationId = "br.com.dublydesk.app"  // ← atualizar
    ...
}
```

---

### 5.3 Adicionar tela de onboarding

**Problema:** novos usuários chegam direto no login sem entender o app.

**Prompt para Claude Code:**

```
Crie uma tela de onboarding no Flutter DublyDesk com 3 slides:
1. "Gerencie suas escalas" — ícone de calendário, descrição breve.
2. "Controle seu financeiro" — ícone de cifrão, descrição breve.
3. "Lembretes automáticos" — ícone de sino, descrição breve.
Exibir apenas na primeira abertura do app (verificar flag no shared_preferences).
Botão "Começar" no último slide redireciona para login.
Manter tema dark premium existente.
```

---

## FASE 6 — Melhorias de médio prazo

### 6.1 Dashboard financeiro com filtro por período

**Prompt para Claude Code:**

```
Na finance_page.dart do DublyDesk, adicione filtro de período:
- Seletor de mês/ano com DatePicker
- Exibir métricas filtradas pelo período selecionado
- Adicionar parâmetros de query na rota GET /schedules/summary: ?mes=4&ano=2026
- Backend: filtrar por EXTRACT(MONTH FROM data) e EXTRACT(YEAR FROM data)
```

---

### 6.2 Exportação de relatório em PDF

**Dependência Flutter:**

```yaml
dependencies:
  pdf: ^3.11.0
  printing: ^5.12.0
```

**Prompt para Claude Code:**

```
No Flutter DublyDesk, adicione exportação de relatório PDF na tela financeira:
Usar os pacotes pdf e printing.
O relatório deve conter: cabeçalho com nome do usuário e período, tabela com todas as escalas realizadas (projeto, produtora, data, valor), total realizado no rodapé.
Adicionar botão "Exportar PDF" na finance_page.dart.
Usar share_plus para compartilhar o arquivo gerado.
```

---

### 6.3 Migrar backend para Railway ou Fly.io

**Problema:** Render free tier tem cold start de 20–30s e pode ser descontinuado.

**Comparativo:**

| Plataforma | Cold start | Free tier | Deploy |
|---|---|---|---|
| Render (atual) | 20–30s | Sim (com limitações) | Git push |
| Railway | Sem cold start | $5 crédito/mês | Git push |
| Fly.io | Sem cold start | 3 VMs pequenas | flyctl deploy |
| Supabase (só DB) | N/A | PostgreSQL gratuito | Dashboard |

**Recomendação:** manter Render para o backend e migrar o PostgreSQL para **Supabase** (mais estável, interface visual, backups automáticos).

**Prompt para Claude Code:**

```
Migre o banco PostgreSQL do DublyDesk do Render para o Supabase:
1. Exportar schema e dados do banco atual com pg_dump.
2. Importar no Supabase via SQL Editor.
3. Atualizar a variável de ambiente DATABASE_URL no Render com a connection string do Supabase.
4. Testar todas as rotas após a migração.
5. Configurar connection pooling no Supabase para suportar o plano gratuito.
```

---

## Prompt mestre para iniciar sessão no Claude Code

Cole este prompt no início de cada sessão de trabalho:

```
Estou desenvolvendo o DublyDesk, um app Flutter para gestão de escalas de dublagem.
Stack: Flutter (Android), Node.js + Express, PostgreSQL no Render.
Autenticação JWT, CRUD de escalas, controle financeiro, notificações locais com flutter_local_notifications.
O MVP já está funcional. Estou na fase de melhorias de arquitetura e novas features.

Estrutura atual do Flutter:
lib/main.dart, login_page.dart, register_page.dart, finance_page.dart,
notification_service.dart, auth_service.dart, api_config.dart

Estrutura atual do backend:
backend/server.js, db.js, routes/auth.js, routes/schedules.js, middleware/auth.js

Base URL: https://dublydesk.onrender.com

Prioridade atual: [DESCREVER A TAREFA DA FASE ATUAL]

Regras importantes:
- Não quebrar funcionalidades existentes
- Manter o tema dark premium do app
- Usar o padrão de código já existente no projeto
- Testar sempre no Android físico antes de considerar concluído
```

---

## Resumo das prioridades

| Fase | Item | Impacto | Esforço |
|---|---|---|---|
| 1 | Refatorar `main.dart` | 🔴 Crítico | Alto |
| 1 | Criar `api_service.dart` | 🔴 Crítico | Médio |
| 1 | Criar `schedule_model.dart` | 🔴 Crítico | Baixo |
| 2 | Rate limiting no backend | 🔴 Crítico | Baixo |
| 2 | Validação de dados no backend | 🟠 Alto | Baixo |
| 2 | Endpoint `/schedules/summary` | 🟠 Alto | Baixo |
| 2 | Paginação no `GET /schedules` | 🟠 Alto | Médio |
| 2 | Refresh token | 🟠 Alto | Alto |
| 3 | Índices no PostgreSQL | 🟠 Alto | Baixo |
| 3 | Tabela de produtoras | 🟡 Médio | Médio |
| 3 | Campo `observacao` | 🟡 Médio | Baixo |
| 4 | Loading para cold start | 🟠 Alto | Baixo |
| 4 | Cache local básico | 🟠 Alto | Médio |
| 4 | Recuperação de senha | 🟠 Alto | Alto |
| 4 | Tela financeira com métricas | 🟡 Médio | Médio |
| 4 | Personalização de lembretes | 🟡 Médio | Médio |
| 5 | Preparar para Play Store | 🔴 Crítico (pré-launch) | Alto |
| 6 | Exportação de PDF | 🟡 Médio | Médio |
| 6 | Migrar DB para Supabase | 🟡 Médio | Alto |

---

*Documento gerado em 18/04/2026 — DublyDesk pós-MVP*
