# Conflict Detection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Impedir que escalas e compromissos sejam agendados em horários sobrepostos, com validação tanto no servidor (autoritativa) quanto no cliente (feedback imediato).

**Architecture:** A API valida conflito via query SQL atômica antes de cada INSERT/UPDATE, retornando 409. O cliente mantém a verificação local existente (`_temConflito`) e já trata erros não-2xx corretamente via `ApiService._handle`. A abertura do formulário pela home page é corrigida para passar o cache de escalas.

**Tech Stack:** Node.js/Express + PostgreSQL (pg pool) no servidor; Flutter/Dart com `ScheduleCacheService` (SharedPreferences) no cliente.

**Spec:** `docs/superpowers/specs/2026-05-14-conflict-detection-design.md`

---

## Arquivos modificados

| Arquivo | Mudança |
|---------|---------|
| `apps/api/routes/schedules.js` | Adicionar `verificarConflito()` + chamadas em POST e PUT |
| `apps/app/lib/home_page.dart` | `_abrirNovo()` carrega cache; adicionar import |
| `apps/app/lib/features/schedules/schedule_form_page.dart` | Atualizar mensagem do SnackBar em `_temConflito` |

---

## Task 1: API — função `verificarConflito` + check no POST

**Files:**
- Modify: `apps/api/routes/schedules.js`

### Contexto

O arquivo `schedules.js` define rotas CRUD para a tabela `schedules`. A tabela tem colunas `user_id`, `data` (DATE), `hora_inicio` (TEXT, formato `HH:mm`), `hora_fim` (TEXT, formato `HH:mm`). Toda escala e todo compromisso ficam na mesma tabela — o campo `tipo` distingue (`'trabalho'` ou `'compromisso'`).

O algoritmo de sobreposição de intervalos: dois intervalos [A, B) e [C, D) se sobrepõem se e somente se `A < D AND C < B`. Em SQL: `hora_inicio < $horaFim AND hora_fim > $horaInicio`.

- [ ] **Step 1: Adicionar `verificarConflito` após `const router = express.Router()`**

Abra `apps/api/routes/schedules.js`. Após a linha `const router = express.Router();` (linha 6), insira a função:

```js
async function verificarConflito(userId, dateStr, horaInicio, horaFim, excludeId = null) {
  const result = await pool.query(
    `SELECT id FROM schedules
     WHERE user_id = $1
       AND data::date = $2::date
       AND ($3::int IS NULL OR id != $3::int)
       AND hora_inicio < $4
       AND hora_fim   > $5
     LIMIT 1`,
    [userId, dateStr, excludeId, horaFim, horaInicio]
  );
  return result.rowCount > 0;
}
```

- [ ] **Step 2: Chamar `verificarConflito` no POST antes do INSERT**

No handler `router.post('/', ...)` (começa por volta da linha 159), após as linhas que calculam `tipoFinal`, `remuneradoFinal`, `valorHoraFinal`, `valorTotalFinal`, `produtoraFinal` e antes do `try {`, adicione a chamada. O bloco `try` atual ficará:

```js
try {
    const conflito = await verificarConflito(
      req.user.id,
      data.substring(0, 10),
      hora_inicio,
      hora_fim
    );
    if (conflito) {
      return res.status(409).json({
        error: 'Horário indisponível — já existe um agendamento nesse período.',
      });
    }

    const result = await pool.query(
      // ... INSERT existente, sem alteração
```

- [ ] **Step 3: Verificar manualmente — criar conflito via curl**

Com a API rodando localmente (`node apps/api/server.js`), obtenha um token fazendo login:

```bash
TOKEN=$(curl -s -X POST http://localhost:3000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"seu@email.com","password":"suasenha"}' | node -e "process.stdin.resume();let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>console.log(JSON.parse(d).token))")
```

Crie o primeiro agendamento (deve retornar 200):

```bash
curl -s -X POST http://localhost:3000/schedules \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"projeto":"Teste A","produtora":"Unidub","data":"2026-06-01","hora_inicio":"10:00","hora_fim":"12:00","valor_total":100,"realizado":false}' | node -e "process.stdin.resume();let d='';process.stdin.on('data',c=>d+=c);process.stdin.on('end',()=>console.log(JSON.parse(d).id))"
```

Tente criar um segundo que se sobrepõe (deve retornar 409):

```bash
curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:3000/schedules \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"projeto":"Teste B","produtora":"Unidub","data":"2026-06-01","hora_inicio":"11:00","hora_fim":"13:00","valor_total":100,"realizado":false}'
```

Resultado esperado: `409`

Tente criar um que NÃO se sobrepõe (deve retornar 200):

```bash
curl -s -o /dev/null -w "%{http_code}" -X POST http://localhost:3000/schedules \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"projeto":"Teste C","produtora":"Unidub","data":"2026-06-01","hora_inicio":"12:00","hora_fim":"14:00","valor_total":100,"realizado":false}'
```

Resultado esperado: `200`

- [ ] **Step 4: Commit**

```bash
git add apps/api/routes/schedules.js
git commit -m "feat(api): verificar conflito de horário no POST /schedules"
```

---

## Task 2: API — check de conflito no PUT

**Files:**
- Modify: `apps/api/routes/schedules.js`

### Contexto

O `PUT /schedules/:id` faz update parcial — qualquer subconjunto dos campos pode chegar no body. O conflito só precisa ser verificado se algum campo temporal (`data`, `hora_inicio`, `hora_fim`) for alterado. Se algum deles vier no body mas os outros não, é preciso buscar os valores atuais do banco para montar o intervalo completo.

A coluna `data` no banco é do tipo `DATE`. O driver `pg` retorna objetos `Date` do JavaScript para colunas DATE. Use `.toISOString().substring(0, 10)` para obter a string `YYYY-MM-DD`.

- [ ] **Step 1: Adicionar bloco de verificação de conflito no PUT**

No handler `router.put('/:id', ...)`, dentro do bloco `try {`, **antes** das linhas que montam `camposPermitidos` e `entradas`, insira:

```js
    const temCampoTemporal = ['data', 'hora_inicio', 'hora_fim']
      .some((k) => req.body[k] !== undefined);

    if (temCampoTemporal) {
      let d  = req.body.data;
      let hi = req.body.hora_inicio;
      let hf = req.body.hora_fim;

      if (!d || !hi || !hf) {
        const cur = await pool.query(
          'SELECT data, hora_inicio, hora_fim FROM schedules WHERE id = $1 AND user_id = $2',
          [id, req.user.id]
        );
        if (cur.rowCount === 0) {
          return res.status(404).json({ error: 'Escala não encontrada' });
        }
        const row = cur.rows[0];
        d  = d  ?? row.data.toISOString().substring(0, 10);
        hi = hi ?? row.hora_inicio;
        hf = hf ?? row.hora_fim;
      }

      const conflito = await verificarConflito(
        req.user.id,
        d.substring(0, 10),
        hi,
        hf,
        parseInt(id)
      );
      if (conflito) {
        return res.status(409).json({
          error: 'Horário indisponível — já existe um agendamento nesse período.',
        });
      }
    }
```

O resto do handler (montagem de `camposPermitidos`, `entradas`, `sets`, `query`) permanece sem alteração.

- [ ] **Step 2: Verificar manualmente — editar com conflito**

Usando os IDs criados na Task 1 (assuma `ID_A` para Teste A e `ID_C` para Teste C — ambos salvos em datas diferentes ou horários distintos). Tente mover Teste C para sobrepor Teste A:

```bash
curl -s -o /dev/null -w "%{http_code}" -X PUT http://localhost:3000/schedules/$ID_C \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"hora_inicio":"10:30","hora_fim":"11:30"}'
```

Resultado esperado: `409`

Edição sem campo temporal (apenas projeto) deve passar:

```bash
curl -s -o /dev/null -w "%{http_code}" -X PUT http://localhost:3000/schedules/$ID_C \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{"projeto":"Teste C editado"}'
```

Resultado esperado: `200`

- [ ] **Step 3: Commit**

```bash
git add apps/api/routes/schedules.js
git commit -m "feat(api): verificar conflito de horário no PUT /schedules/:id"
```

---

## Task 3: Flutter — corrigir `home_page.dart`

**Files:**
- Modify: `apps/app/lib/home_page.dart`

### Contexto

`home_page.dart` abre `ScheduleFormPage` pelo botão "Novo" via `_abrirNovo()`. Hoje passa `const ScheduleFormPage()` sem `escalasExistentes`, então a verificação local `_temConflito` nunca detecta nada. A correção carrega o cache local antes de abrir.

`ScheduleCacheService.load()` é assíncrono e retorna `Future<List<ScheduleModel>>`. O cache é salvo pela `ScheduleListPage` e `CalendarPage` quando buscam escalas da API. Pode estar vazio se o usuário nunca abriu essas telas — isso é aceitável, pois o servidor ainda valida.

- [ ] **Step 1: Adicionar import do `ScheduleCacheService`**

Em `apps/app/lib/home_page.dart`, adicione ao bloco de imports existente (após os imports atuais):

```dart
import 'core/services/schedule_cache_service.dart';
```

- [ ] **Step 2: Atualizar `_abrirNovo()`**

Substitua o método `_abrirNovo()` atual (linhas 79-87):

```dart
// antes
Future<void> _abrirNovo() async {
  await Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const ScheduleFormPage()),
  );
  _calendarKey.currentState?.refresh();
  _financeKey.currentState?.refresh();
  _listKey.currentState?.refresh();
}
```

pelo seguinte:

```dart
// depois
Future<void> _abrirNovo() async {
  final cached = await ScheduleCacheService.load();
  if (!mounted) return;
  await Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => ScheduleFormPage(escalasExistentes: cached),
    ),
  );
  _calendarKey.currentState?.refresh();
  _financeKey.currentState?.refresh();
  _listKey.currentState?.refresh();
}
```

- [ ] **Step 3: Confirmar que o app compila**

```bash
cd apps/app && flutter build apk --debug 2>&1 | tail -5
```

Resultado esperado: `✓ Built build/app/outputs/flutter-apk/app-debug.apk` ou similar sem erros.

- [ ] **Step 4: Commit**

```bash
git add apps/app/lib/home_page.dart
git commit -m "fix(flutter): passar cache de escalas ao abrir formulário pela home"
```

---

## Task 4: Flutter — atualizar mensagem do `_temConflito`

**Files:**
- Modify: `apps/app/lib/features/schedules/schedule_form_page.dart`

### Contexto

O método `_temConflito` (linha 268) verifica a lista local e exibe um `SnackBar` com mensagem diferente da que a API retorna. Unificar as duas mensagens evita confusão se o usuário ver mensagens distintas dependendo do fluxo.

O `SnackBar` de conflito está em `_salvar()` (por volta da linha 338-345), não dentro de `_temConflito` em si. `_temConflito` retorna `bool`; quem exibe o snack é `_salvar()`.

- [ ] **Step 1: Atualizar o SnackBar de conflito em `_salvar()`**

Em `apps/app/lib/features/schedules/schedule_form_page.dart`, localize o bloco (por volta da linha 337):

```dart
if (_temConflito(inicioDate, fimDate)) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Período indisponível! Já existe uma escala nesse horário.'),
      backgroundColor: AppColors.error,
    ),
  );
  setState(() => _salvando = false);
  return;
}
```

Substitua por:

```dart
if (_temConflito(inicioDate, fimDate)) {
  ScaffoldMessenger.of(context).showSnackBar(
    const SnackBar(
      content: Text('Horário indisponível — já existe um agendamento nesse período.'),
      backgroundColor: AppColors.error,
    ),
  );
  setState(() => _salvando = false);
  return;
}
```

- [ ] **Step 2: Confirmar que o app compila**

```bash
cd apps/app && flutter build apk --debug 2>&1 | tail -5
```

Resultado esperado: sem erros.

- [ ] **Step 3: Commit**

```bash
git add apps/app/lib/features/schedules/schedule_form_page.dart
git commit -m "fix(flutter): unificar mensagem de conflito de horário"
```

---

## Task 5: Teste de ponta a ponta no dispositivo

**Files:** nenhum — apenas verificação manual.

- [ ] **Step 1: Rodar o app e a API localmente**

```bash
# Terminal 1 — API
cd apps/api && node server.js

# Terminal 2 — Flutter
cd apps/app && flutter run
```

- [ ] **Step 2: Criar uma escala (ex: 10:00–12:00 em 01/06/2026)**

No app, abrir pelo botão "+" (aba Novo na home). Preencher e salvar. Confirmar que salva normalmente.

- [ ] **Step 3: Tentar criar um compromisso sobrepondo o horário (ex: 11:00–13:00 em 01/06/2026)**

Abrir o formulário novamente pela home. Selecionar "Compromisso", preencher título, mesma data, 11:00–13:00. Apertar Salvar.

Resultado esperado: SnackBar `'Horário indisponível — já existe um agendamento nesse período.'`

- [ ] **Step 4: Tentar criar escala com conflito pelo calendário (edição)**

Na tela de calendário, abrir uma escala e tentar mudar o horário para sobrepor outra.

Resultado esperado: SnackBar com a mesma mensagem.

- [ ] **Step 5: Push final**

```bash
git push
```
