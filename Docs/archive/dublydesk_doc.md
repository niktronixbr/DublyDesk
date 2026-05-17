# 📱 DublyDesk — Documentação Completa da Última Versão

## 1. Visão geral

O **DublyDesk** é um aplicativo mobile em **Flutter** para gestão de escalas de dublagem, com backend em **Node.js + Express**, autenticação via **JWT** e banco **PostgreSQL** hospedado no **Render**.

O objetivo do app é permitir que o usuário:

- faça cadastro e login
- crie, edite e exclua escalas
- marque escalas como realizadas
- acompanhe o financeiro com base apenas nas escalas realizadas
- receba lembretes automáticos das escalas

---

## 2. Arquitetura do projeto

### Frontend mobile

- **Flutter (Dart)**
- Plataforma principal: **Android**
- UI com tema escuro, visual premium
- Armazenamento local:
  - `shared_preferences`

### Backend

- **Node.js**
- **Express**
- Autenticação com **JWT**
- Banco de dados **PostgreSQL**
- Deploy no **Render**

### Banco de dados

- PostgreSQL
- Tabelas principais:
  - `users`
  - `schedules`

---

## 3. Base URL da API

```dart
const String baseUrl = 'https://dublydesk.onrender.com';
```

---

## 4. Funcionalidades implementadas

### 4.1 Autenticação

- Cadastro de usuário
- Login
- Persistência de sessão local com JWT
- Logout
- Recuperação de sessão ao abrir o app

### 4.2 Escalas

- Criar nova escala
- Editar escala existente
- Excluir escala
- Marcar como realizada
- Busca por:
  - projeto
  - produtora
  - diretor
- Filtro por produtora

### 4.3 Financeiro

- Soma apenas escalas com:

```dart
item['realizado'] == true
```

- Tela financeira separada
- Exibição de total realizado

### 4.4 Notificações

- Notificações locais com `flutter_local_notifications`
- Timezone com `flutter_timezone`
- Lembretes automáticos por escala
- Cancelamento das notificações ao excluir a escala

### 4.5 Experiência do usuário

- Tema escuro moderno
- Cards com gradiente
- Botão de nova escala no topo
- Lista com swipe para exclusão
- Cards com status de pendente/realizada

---

## 5. Estrutura principal do Flutter

```text
lib/
├── main.dart
├── login_page.dart
├── register_page.dart
├── finance_page.dart
├── notification_service.dart
├── auth_service.dart
├── api_config.dart
```

---

## 6. Estrutura principal do backend

```text
backend/
├── server.js
├── db.js
├── routes/
│   ├── auth.js
│   └── schedules.js
├── middleware/
│   └── auth.js
```

---

## 7. Rotas da API

### Auth

- `POST /auth/register`
- `POST /auth/login`

### Schedules

- `GET /schedules`
- `POST /schedules`
- `PUT /schedules/:id`
- `DELETE /schedules/:id`

---

## 8. Modelagem do banco

### Tabela `users`

```sql
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

### Tabela `schedules`

```sql
CREATE TABLE schedules (
  id SERIAL PRIMARY KEY,
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,

  projeto TEXT NOT NULL,
  produtora TEXT NOT NULL,
  diretor TEXT,

  data TIMESTAMP NOT NULL,
  hora_inicio VARCHAR(5) NOT NULL,
  hora_fim VARCHAR(5) NOT NULL,

  valor_hora NUMERIC(10,2) NOT NULL,
  valor_total NUMERIC(10,2) NOT NULL,

  realizado BOOLEAN NOT NULL DEFAULT false,

  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

---

## 9. Variáveis de ambiente do backend

No Render:

```env
DATABASE_URL=...
JWT_SECRET=...
PORT=3000
```

---

## 10. Configuração do Render

### Serviço backend

- **Build Command**:

```bash
npm install
```

- **Start Command**:

```bash
npm start
```

### Observações importantes

Não usar:

```bash
yarnnpm install
```

Nem:

```bash
yarn npm install
```

Nem:

```bash
yarn npm start
```

Esses comandos foram a causa inicial de falhas de deploy no Render.

---

## 11. Regras de negócio das escalas

### Campos obrigatórios

- Produtora
- Projeto
- Data
- Hora início
- Hora fim
- Valor/hora

### Validações

- `hora_fim` deve ser maior que `hora_inicio`
- O formato de hora utilizado é `HH:mm`
- O valor total é calculado automaticamente

### Cálculo do valor total

```dart
final diferencaMinutos = fimDate.difference(inicioDate).inMinutes;
final horasCalculadas = diferencaMinutos / 60.0;
final valorHoraDouble = parseValor(valorHora.text);
final valorTotal = horasCalculadas * valorHoraDouble;
```

---

## 12. Fluxo atual de notificação

Na última versão do projeto, o app foi preparado para lembretes semelhantes ao comportamento de agenda.

### Lembretes automáticos por escala

Ao salvar uma escala, o app tenta criar até 3 notificações:

1. **30 minutos antes**
2. **5 minutos antes**
3. **no horário exato**

### Regra importante

Notificações em horário passado **não são agendadas**.

Exemplo:

- Se faltar 10 minutos para a escala:
  - a de 30 minutos antes será ignorada
  - a de 5 minutos antes será agendada
  - a do horário exato será agendada

### Estratégia de IDs das notificações

Cada escala usa um `baseId`, e os lembretes derivados usam:

- `baseId * 10 + 1`
- `baseId * 10 + 2`
- `baseId * 10 + 3`

Isso permite cancelar facilmente todas as notificações relacionadas à escala.

### Cancelamento

Ao excluir uma escala, o app cancela os 3 lembretes associados.

---

## 13. Permissões Android necessárias

Arquivo: `android/app/src/main/AndroidManifest.xml`

O projeto precisa destas permissões:

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
<uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />
```

### Observações

- `INTERNET` é obrigatória para comunicação com o backend
- `POST_NOTIFICATIONS` é necessária em Android 13+
- A permissão de notificação **não aparece na instalação**; ela deve ser solicitada em runtime

---

## 14. Configuração Android para notificações

### Manifest completo esperado

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
    <uses-permission android:name="android.permission.SCHEDULE_EXACT_ALARM" />

    <application
        android:label="dublydesk"
        android:name="${applicationName}"
        android:icon="@mipmap/ic_launcher">
        <activity
            android:name=".MainActivity"
            android:exported="true"
            android:launchMode="singleTop"
            android:taskAffinity=""
            android:theme="@style/LaunchTheme"
            android:configChanges="orientation|keyboardHidden|keyboard|screenSize|smallestScreenSize|locale|layoutDirection|fontScale|screenLayout|density|uiMode"
            android:hardwareAccelerated="true"
            android:windowSoftInputMode="adjustResize">
            <meta-data
                android:name="io.flutter.embedding.android.NormalTheme"
                android:resource="@style/NormalTheme" />
            <intent-filter>
                <action android:name="android.intent.action.MAIN" />
                <category android:name="android.intent.category.LAUNCHER" />
            </intent-filter>
        </activity>

        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>

    <queries>
        <intent>
            <action android:name="android.intent.action.PROCESS_TEXT" />
            <data android:mimeType="text/plain" />
        </intent>
    </queries>
</manifest>
```

---

## 15. Configuração Gradle Android

Durante a evolução do projeto, o plugin de notificações exigiu **desugaring** no Android.

### `android/app/build.gradle.kts`

```kotlin
plugins {
    id("com.android.application")
    id("kotlin-android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.dublydesk"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    defaultConfig {
        applicationId = "com.example.dublydesk"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = "11"
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
```

### Observação importante

Se o projeto Android estiver muito antigo e o Flutter acusar:

```text
unsupported Gradle project
```

A recomendação é:

1. criar um projeto Flutter novo com `flutter create`
2. copiar `lib/`, `assets/` e `pubspec.yaml`
3. reaplicar apenas as configurações Android necessárias

---

## 16. Estado atual do `main.dart`

### Responsabilidades principais

- inicialização do app
- verificação de sessão
- exibição da home
- carregamento das escalas
- filtros e busca
- CRUD das escalas
- integração com notificações

### Comportamento importante corrigido

Na última versão, o salvamento da escala foi desacoplado do agendamento de notificação.

Antes:
- se a notificação falhasse, o app mostrava erro genérico mesmo com a escala salva

Agora:
- a escala é salva normalmente
- se a notificação falhar, o app informa apenas que o lembrete não foi agendado

---

## 17. Estado atual do `notification_service.dart`

### Responsabilidades

- inicialização do plugin
- criação do canal Android
- configuração do timezone local
- solicitação de permissão de notificações
- disparo de notificação imediata
- agendamento de notificações futuras
- agendamento padrão de agenda (30 min, 5 min, horário)
- cancelamento de notificações

### Estratégia atual de agendamento

O modo adotado foi:

```dart
AndroidScheduleMode.inexactAllowWhileIdle
```

Esse ajuste foi escolhido para reduzir falhas em aparelhos Android que bloqueiam ou restringem alarmes exatos.

---

## 18. Fluxo de cadastro e login

### Cadastro

- envia `name`, `email` e `password` para `/auth/register`
- se o backend responder com sucesso:
  - salva `token`
  - salva nome e email localmente
  - entra no app

### Login

- envia `email` e `password` para `/auth/login`
- salva sessão local
- redireciona para a home

### Persistência de sessão

A sessão é mantida localmente via `shared_preferences`.

---

## 19. Erros já resolvidos no projeto

### Backend / Render

- comando inválido no build:
  - `yarnnpm install`
  - `yarn npm install`
- comando inválido no start:
  - `yarn npm start`
- rota `Cannot GET /auth/register`
  - entendido como comportamento normal para rota POST
- backend offline ou dúvida de funcionamento
  - validado com `curl`

### Banco

- `relation does not exist`
- criação automática das tabelas com `createTables()`

### Mobile / Flutter

- uso de `localhost` no Android
- falhas de DNS por ausência de permissão `INTERNET`
- erro ao salvar escala mesmo com escala criada
- incompatibilidade de API do `flutter_local_notifications`
- necessidade de desugaring Android
- permissão de notificação em Android 13+

---

## 20. Dependências importantes do projeto mobile

Exemplos relevantes já utilizados no projeto:

- `http`
- `intl`
- `shared_preferences`
- `flutter_local_notifications`
- `flutter_timezone`
- `timezone`

---

## 21. Comandos úteis de desenvolvimento

### Rodar o app

```bash
flutter run
```

### Gerar APK release

```bash
flutter build apk --release
```

### Limpar projeto

```bash
flutter clean
```

### Buscar dependências

```bash
flutter pub get
```

### Verificar dependências desatualizadas

```bash
flutter pub outdated
```

---

## 22. Fluxo recomendado para testar notificações

Para validar corretamente os lembretes:

1. instalar o app no celular
2. abrir o app
3. aceitar permissão de notificações
4. criar uma escala para pelo menos **10 minutos no futuro**
5. confirmar se o lembrete de 5 minutos e o lembrete do horário exato aparecem

### Observação

A notificação de 30 minutos antes só será criada se ainda houver pelo menos 30 minutos até a escala.

---

## 23. Melhorias futuras recomendadas

### Curto prazo

- permitir o usuário configurar o tipo de lembrete
- selecionar antecedência personalizada
- melhorar mensagem de erro no agendamento
- adicionar página de configurações

### Médio prazo

- recuperação de senha
- backup em nuvem
- dashboard financeiro avançado
- exportação de relatórios

### Longo prazo

- publicação na Play Store
- monetização
- sincronização com calendário externo
- múltiplos lembretes customizáveis por escala

---

## 24. Resumo do status da última versão

### Backend

- online no Render
- cadastro e login funcionando
- CRUD de escalas funcionando
- PostgreSQL funcionando

### Mobile

- app roda no celular
- login e cadastro funcionando
- escalas salvando corretamente
- financeiro funcionando
- notificações integradas
- lembretes em processo final de validação por dispositivo Android

### UX

- visual dark premium
- fluxo principal do produto funcionando
- base pronta para próxima fase

---

## 25. Prompt-base para continuar o projeto com IA

```text
Estou desenvolvendo um app Flutter chamado DublyDesk para gestão de escalas de dublagem com backend Node.js e PostgreSQL no Render. O app possui autenticação JWT, controle financeiro baseado em escalas realizadas, notificações locais e UI premium. A versão atual já possui CRUD de escalas, login, cadastro, financeiro, integração com Render e notificações com lembretes automáticos de 30 min, 5 min e no horário exato. Preciso evoluir com arquitetura profissional, melhorias de UX e novas funcionalidades sem quebrar o que já funciona.
```

---

## 26. Observação final

A versão atual do DublyDesk já representa um **MVP funcional e utilizável em dispositivo real**, com backend online, persistência, controle financeiro e experiência visual consistente.

O foco da próxima etapa deve ser:

- robustez das notificações por dispositivo
- personalização de lembretes
- recuperação de senha
- publicação

