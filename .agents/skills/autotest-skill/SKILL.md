---
name: autotest-skill
description: Навык для генерации автотестов в Postman, включает примеры скриптов TEARDOWN, обработки ошибок и типичных ошибок.
---

# autotest-skill

## Обязательные принципы

### 1. Автономность
Каждый тест должен быть **полностью независим**:
- Генерируй уникальные имена с суффиксом `Date.now()`
- Каждый тест самостоятельно авторизуется
- Создавай зависимости внутри теста
- Удаляй созданные данные в TEARDOWN

### 2. Self-cleanup
Всегда реализуй очистку данных:
- Сохраняй ID созданных сущностей в `pm.environment`
- Удаляй сущности в правильном порядке
- Очищай переменные после использования

### 3. Уникальность имён
```javascript
// ✅ Правильно
var suffix = Date.now();
var userName = 'test_user_' + suffix;

// ❌ Неправильно
var userName = 'test_user';  // Конфликт при параллельном запуске
```

---

## Структура теста

### Обязательный шаблон

```
FOLDER: XX - Название категории
├── Авто-логин (получение токена)
├── Сценарий 1
│   ├── SETUP (создание зависимостей)
│   ├── EXECUTE (основной запрос)
│   └── TEARDOWN (очистка данных)
└── Негативные тесты
```

### Pre-request скрипт (collection level)

```javascript
// Инициализация уникальных имён
if (!pm.environment.get('runSuffix')) {
    pm.environment.set('runSuffix', String(Date.now()));
}

var suffix = pm.environment.get('runSuffix');

// Генерация имён для всех сущностей
if (!pm.environment.get('newUserName')) {
    pm.environment.set('newUserName', 'autotest_user_' + suffix);
}
if (!pm.environment.get('newWorkerName')) {
    pm.environment.set('newWorkerName', 'autotest_machine_' + suffix);
}
if (!pm.environment.get('newRobotName')) {
    pm.environment.set('newRobotName', 'autotest_robot_' + suffix);
}
if (!pm.environment.get('newProjectName')) {
    pm.environment.set('newProjectName', 'autotest_project_' + suffix);
}

// Добавление Authorization header
var token = pm.environment.get('token');
if (token) {
    pm.request.headers.upsert({
        key: 'Authorization',
        value: 'Bearer ' + token
    });
}
```

### Auto-Login запрос

```javascript
// Test скрипт
pm.test('Status 200', function () {
    pm.response.to.have.status(200);
});

var json = pm.response.json();
pm.test('Token exists', function () {
    pm.expect(json.token).to.be.a('string').and.not.empty;
});
pm.environment.set('token', json.token);
```

---

## Паттерны TEARDOWN

### По типу сущности

| Сущность | Метод удаления | Порядок |
|----------|----------------|---------|
| Users | DELETE `/api/users/{id}` | 1 |
| Roles | DELETE `/api/roles/{id}` | 1 |
| Assets | DELETE `/api/assets/{id}` | 1 |
| Queues | DELETE `/api/ExchangeQueues/{id}` | 1 |
| Schedules | DELETE `/api/Schedules/{id}` | 1 |
| Machines | PUT `/api/workers/{id}/disable` | 1 |
| Projects | PUT `/api/rpaprojects/{id}/disable` | 1 |
| Robots | erase + disable | 2 шага |

### Скрипт TEARDOWN

```javascript
var entityId = pm.environment.get('createdEntityId');

if (entityId) {
    pm.test('Status 2xx', function () {
        pm.expect(pm.response.code).to.be.at.least(200).and.below(300);
    });
    pm.environment.unset('createdEntityId');
} else {
    pm.test('Skipped - no entity', function () {
        pm.expect(true).to.be.true;
    });
}
```

### Порядок очистки для Robots

```javascript
// 1. Erase (только для развёрнутых роботов)
// PUT /api/robots/{id}/erase
pm.test('Status 2xx or 409', function () {
    pm.expect(pm.response.code).to.be.oneOf([200, 204, 409]);
});

// 2. Disable
// PUT /api/robots/{id}/disable
pm.test('Status 2xx', function () {
    pm.expect(pm.response.code).to.be.at.least(200).and.below(300);
});

// 3. Disable Worker (если создавали)
// PUT /api/workers/{id}/disable
pm.test('Status 2xx', function () {
    pm.expect(pm.response.code).to.be.at.least(200).and.below(300);
});
```

---

## Обработка ошибок

### Проверка статуса ответа

```javascript
// Успешное создание
pm.test('Status 201', function () {
    pm.response.to.have.status(201);
});

// Успешное удаление
pm.test('Status 2xx', function () {
    pm.expect(pm.response.code).to.be.at.least(200).and.below(300);
});

// Негативный тест
pm.test('Status 4xx', function () {
    pm.expect(pm.response.code).to.be.at.least(400).and.below(500);
});

// Несуществующая сущность
pm.test('Status 404 or 4xx', function () {
    pm.expect(pm.response.code).to.be.oneOf([404, 400, 401]);
});
```

### Обработка разных форматов ответа

```javascript
var data = pm.response.json();

// API может вернуть массив или {result: [...]}
var items = Array.isArray(data)
    ? data
    : (Array.isArray(data.result) ? data.result : []);

pm.test('Items list is valid', function () {
    pm.expect(Array.isArray(items)).to.be.true;
});

if (items.length > 0) {
    pm.environment.set('firstItemId', items[0].id);
}
```

---

## Загрузка файлов

### Проекты (multipart/form-data)

```javascript
// 1. Получить GUID
// GET /api/rpaprojects/archiveguid
var guid = pm.response.text().replace(/"/g, '').trim();
pm.environment.set('archiveGuid', guid);

// 2. Загрузить архив
// POST /api/rpaprojects/archive/{guid}
// Body: form-data
//   key: "project"  // ВАЖНО: не "file"!
//   type: file
//   src: "/path/to/project.zip"
pm.test('Status 2xx', function () {
    pm.expect(pm.response.code).to.be.at.least(200).and.below(300);
});

// 3. Получить fileId
// GET /api/rpaprojects/archive/{guid}
var json = pm.response.json();
pm.environment.set('projectFileId', json.fileId || json.id);

// 4. Создать проект
// POST /api/rpaprojects/v2
// Body: {"name": "...", "fileId": "{{projectFileId}}", ...}
```

---

## Polling статуса

### Deploy робота

```javascript
// После deployasync проверяем статус N раз
var status = pm.response.json().deploymentStatus;

if (status === 3) {
    // Deployed (успех)
    pm.environment.set('deployed', 'true');
    pm.test('Deployed!', function () {
        pm.expect(true).to.be.true;
    });
} else if (status === 4) {
    // Error (провал)
    pm.environment.set('deployed', 'false');
    pm.test('Deploy ERROR', function () {
        pm.expect(status).to.equal(3);
    });
} else {
    // В процессе
    pm.environment.set('deployed', 'false');
}

// Финальная проверка после N итераций
if (pm.environment.get('deployed') !== 'true') {
    pm.test('Deploy timeout', function () {
        pm.expect(status).to.equal(3);
    });
}
```

---

## Переменные окружения

### Обязательные

```javascript
baseUrl: 'http://localhost:5000'
username: 'admin'
password: 'admin'
workerIp: '127.0.0.1'
```

### Автоматические (генерируются в тестах)

```javascript
token: 'JWT токен'
runSuffix: 'timestamp'
createdUserId: 'ID созданного пользователя'
createdWorkerId: 'ID созданной машины'
createdRoleId: 'ID созданной роли'
createdAssetId: 'ID созданного ассета'
createdQueueId: 'ID созданной очереди'
createdProjectId: 'ID созданного проекта'
createdRobotId: 'ID созданного робота'
createdScheduleId: 'ID созданного расписания'
```

---

## Чек-лист перед созданием теста

Перед созданием нового теста проверь:

- [ ] Добавлен Auto-Login в начало категории
- [ ] Используются уникальные имена с `{{newEntityName}}`
- [ ] Реализован SETUP для зависимостей
- [ ] Добавлены проверки статуса ответа
- [ ] ID созданной сущности сохраняется в `pm.environment`
- [ ] Реализован TEARDOWN для очистки
- [ ] Переменные очищаются после теста (`pm.environment.unset`)
- [ ] Проверен порядок очистки зависимостей
- [ ] Добавлены негативные тесты

---

## Пример полного теста

### Создание пользователя

```json
{
  "name": "02 - Пользователи",
  "item": [
    {
      "name": "Авто-логин",
      "item": [
        {
          "name": "Получить токен",
          "event": [
            {
              "listen": "test",
              "script": {
                "exec": [
                  "pm.test('Status 200', function () { pm.response.to.have.status(200); });",
                  "var json = pm.response.json();",
                  "pm.environment.set('token', json.token);"
                ]
              }
            }
          ],
          "request": {
            "method": "POST",
            "header": [{"key": "Content-Type", "value": "application/json"}],
            "body": {
              "mode": "raw",
              "raw": "{\"userName\": \"{{username}}\", \"password\": \"{{password}}\"}"
            },
            "url": "{{baseUrl}}/api/account"
          }
        }
      ]
    },
    {
      "name": "Создание пользователя",
      "item": [
        {
          "name": "SETUP - Get roleId",
          "event": [
            {
              "listen": "test",
              "script": {
                "exec": [
                  "pm.test('Status 200', function () { pm.response.to.have.status(200); });",
                  "var rolesData = pm.response.json();",
                  "var roles = Array.isArray(rolesData) ? rolesData : rolesData.result;",
                  "if (roles.length > 0) { pm.environment.set('roleId', roles[0].id); }"
                ]
              }
            }
          ],
          "request": {
            "method": "GET",
            "url": "{{baseUrl}}/api/roles"
          }
        },
        {
          "name": "POST /api/users/v2 - Create",
          "event": [
            {
              "listen": "test",
              "script": {
                "exec": [
                  "pm.test('Status 201', function () { pm.response.to.have.status(201); });",
                  "var json = pm.response.json();",
                  "pm.environment.set('createdUserId', json.id);"
                ]
              }
            }
          ],
          "request": {
            "method": "POST",
            "header": [{"key": "Content-Type", "value": "application/json"}],
            "body": {
              "mode": "raw",
              "raw": "{\"userName\": \"{{newUserName}}\", \"email\": \"test@test.local\", \"roles\": [\"{{roleId}}\"], \"password\": \"Test123!\"}"
            },
            "url": "{{baseUrl}}/api/users/v2"
          }
        },
        {
          "name": "TEARDOWN - Delete user",
          "event": [
            {
              "listen": "test",
              "script": {
                "exec": [
                  "var userId = pm.environment.get('createdUserId');",
                  "if (userId) {",
                  "    pm.test('Status 2xx', function () { pm.expect(pm.response.code).to.be.at.least(200).and.below(300); });",
                  "    pm.environment.unset('createdUserId');",
                  "} else {",
                  "    pm.test('Skipped', function () { pm.expect(true).to.be.true; });",
                  "}"
                ]
              }
            }
          ],
          "request": {
            "method": "DELETE",
            "url": "{{baseUrl}}/api/users/{{createdUserId}}"
          }
        }
      ]
    }
  ]
}
```

---

## Типичные ошибки

### ❌ Неправильный порядок TEARDOWN

```javascript
// Ошибка: worker удаляется до робота
DELETE /api/workers/{id}
PUT /api/robots/{id}/disable
```

### ✅ Правильный порядок

```javascript
// Сначала робот, потом worker
PUT /api/robots/{id}/disable
PUT /api/workers/{id}/disable
```

### ❌ Забытый TEARDOWN

```javascript
// Создаём, но не удаляем
POST /api/users/v2
// Нет TEARDOWN!
```

### ✅ Правильно

```javascript
POST /api/users/v2
pm.environment.set('createdUserId', json.id);

// TEARDOWN
DELETE /api/users/{createdUserId}
pm.environment.unset('createdUserId');
```

---

## При модификации тестов

1. **Сохраняй автономность** — не создавай зависимости между тестами
2. **Проверяй TEARDOWN** — убедись, что все созданные сущности удаляются
3. **Используй переменные** — не хардкодь значения, используй `{{variableName}}`
4. **Добавляй проверки** — каждый запрос должен иметь test скрипт с проверками
5. **Документируй** — добавляй комментарии к сложным сценариям