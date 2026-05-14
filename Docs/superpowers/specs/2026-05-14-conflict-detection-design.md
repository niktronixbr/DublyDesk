# Design: Detecção de Conflito de Horário

**Data:** 2026-05-14
**Status:** Aprovado

## Problema

Escalas (trabalho) e compromissos compartilham a mesma tabela `schedules` e o mesmo formulário. Hoje, nenhuma validação impede que dois agendamentos se sobreponham no tempo. Além disso, a verificação client-side existente (`_temConflito`) não funciona quando o formulário é aberto via botão home, pois `escalasExistentes` chega vazio.

## Objetivo

Impedir que qualquer agendamento (trabalho ou compromisso) seja criado ou editado com horário que sobreponha outro já existente, de forma confiável em todos os fluxos de entrada.

## Decisões de design

- **Onde validar:** cliente + servidor (cliente como feedback imediato, servidor como autoridade final).
- **Mensagem:** genérica — `'Horário indisponível — já existe um agendamento nesse período.'` — sem expor detalhes do item conflitante.
- **Tipos:** a verificação é bidirecional — trabalho bloqueia compromisso e vice-versa. Nenhum filtro por `tipo`.

## Arquitetura

```
[Formulário Flutter]
  _temConflito()          ← verifica lista em memória (feedback imediato)
  _salvar()
    │
    ▼
[API Node.js — POST/PUT /schedules]
  verificarConflito()     ← query SQL atômica (autoridade final)
  → 409 se conflito
  → 201/200 se ok
    │
    ▼
[Flutter — trata result['success'] != true]
  409 → SnackBar com result['error'] (já funciona via ApiService._handle)
```

## Mudanças na API (`apps/api/routes/schedules.js`)

### Nova função auxiliar

```js
async function verificarConflito(userId, dateStr, horaInicio, horaFim, excludeId = null) {
  const result = await pool.query(
    `SELECT id FROM schedules
     WHERE user_id = $1
       AND data::date = $2
       AND ($3 IS NULL OR id != $3)
       AND hora_inicio < $4
       AND hora_fim   > $5
     LIMIT 1`,
    [userId, dateStr, excludeId, horaFim, horaInicio]
  );
  return result.rowCount > 0;
}
```

O algoritmo `hora_inicio < horaFim_novo AND hora_fim > horaInicio_novo` cobre sobreposição parcial, total e interna.

### POST /schedules

Antes do `INSERT`, após a validação de campos:

```js
const conflito = await verificarConflito(
  req.user.id,
  data.substring(0, 10),
  hora_inicio,
  hora_fim
);
if (conflito) {
  return res.status(409).json({
    error: 'Horário indisponível — já existe um agendamento nesse período.'
  });
}
```

### PUT /schedules/:id

Executado apenas quando `data`, `hora_inicio` ou `hora_fim` chegam no body. Se algum chegar mas outros não, busca os valores atuais do banco (SELECT) antes de mesclar e checar.

```js
const temCampoTemporal = ['data', 'hora_inicio', 'hora_fim']
  .some(k => req.body[k] !== undefined);

if (temCampoTemporal) {
  // fetch current if partial
  let { data: d, hora_inicio: hi, hora_fim: hf } = req.body;
  if (!d || !hi || !hf) {
    const cur = await pool.query(
      'SELECT data, hora_inicio, hora_fim FROM schedules WHERE id=$1 AND user_id=$2',
      [id, req.user.id]
    );
    if (cur.rowCount === 0) return res.status(404).json({ error: 'Escala não encontrada' });
    d  = d  ?? cur.rows[0].data.toISOString().substring(0, 10);
    hi = hi ?? cur.rows[0].hora_inicio;
    hf = hf ?? cur.rows[0].hora_fim;
  }
  const conflito = await verificarConflito(
    req.user.id, d.substring(0, 10), hi, hf, parseInt(id)
  );
  if (conflito) {
    return res.status(409).json({
      error: 'Horário indisponível — já existe um agendamento nesse período.'
    });
  }
}
```

## Mudanças no Flutter

### `home_page.dart` — fix do fluxo sem escalas

`_abrirNovo()` passa a carregar o cache antes de abrir o formulário:

```dart
Future<void> _abrirNovo() async {
  final cached = await ScheduleCacheService.load();
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

### `schedule_form_page.dart` — mensagem unificada

Atualizar o SnackBar dentro de `_temConflito` (chamado em `_salvar()`):

```dart
// antes
content: Text('Período indisponível! Já existe uma escala nesse horário.')

// depois
content: Text('Horário indisponível — já existe um agendamento nesse período.')
```

Nenhuma mudança em `_salvar()` nem em `ApiService` — o retorno 409 da API já cai no fluxo `result['success'] != true` existente, que exibe `result['error']`.

## O que NÃO muda

- Estrutura da tabela `schedules` — sem nova coluna, sem migration.
- `ApiService` — nenhuma mudança.
- `_salvar()` do formulário — nenhuma mudança.
- `calendar_page.dart` e `schedule_list_page.dart` — já passam `escalasExistentes` corretamente.

## Arquivos a modificar

| Arquivo | Mudança |
|---------|---------|
| `apps/api/routes/schedules.js` | Adicionar `verificarConflito()` + chamadas em POST e PUT |
| `apps/app/lib/home_page.dart` | `_abrirNovo()` carrega cache antes de abrir form |
| `apps/app/lib/features/schedules/schedule_form_page.dart` | Atualizar mensagem do SnackBar em `_temConflito` |
