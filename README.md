# Autotest - Newman

Автотесты для API системы Primo RPA AI Server. Запускаются в Newman (Postman CLI).

---

## Структура проекта

```
testOlama/
├── collections/
│   ├── modules/
│   │   ├── auth/
│   │   │   └── auth.json              # Модуль: Авторизация
│   │   └── projects/
│   │       ├── README.md              # Документация модуля Проекты
│   │       └── smart-ocr.json         # Модуль: Проекты → Умный OCR
│   └── AuthTest.postman_environment.json  # Переменные окружения
├── swagger/
│   ├── swagger-inference.json         # Swagger спецификация Inference
│   └── swagger-primo-ai-api.json      # Swagger спецификация API
├── newman-config.json                 # Конфигурация Newman
├── run-tests.sh                       # Скрипт запуска (Linux/macOS)
├── .gitignore
└── README.md
```

---

## Модули тестирования

### 📋 Список модулей

| Модуль | Файл | Описание |
|--------|------|----------|
| **00 - Авторизация** | `collections/modules/auth/auth.json` | Тесты авторизации |
| **01 - Проекты → Умный OCR** | `collections/modules/projects/smart-ocr.json` | Тесты создания проектов OCR |

---

## Требования

- Node.js >= 14
- Newman: `npm install -g newman`
- Newman Allure Reporter: `npm install -g newman-reporter-allure`
- Allure CLI (опционально): `npm install -g allure-commandline`

## Установка

```bash
# Установка Newman и Allure reporter
npm install -g newman newman-reporter-allure

# Для Allure отчётов также установите Allure CLI
npm install -g allure-commandline
```

---

## Настройка

Отредактируйте файл `collections/AuthTest.postman_environment.json`:

```json
{
  "key": "baseUrl",
  "value": "https://10.0.0.164:44392"  // URL вашего сервера
},
{
  "key": "username",
  "value": "admin"  // Имя пользователя
},
{
  "key": "password",
  "value": "Qwe123!@#"  // Пароль
}
```

---

## Запуск тестов

### Linux/macOS

```bash
# Сделать скрипт исполняемым
chmod +x run-tests.sh

# Запуск с Allure отчётом
./run-tests.sh

# Простой запуск без отчёта
./run-tests.sh simple

# Справка
./run-tests.sh help
```

### Windows (PowerShell)

```powershell
# Простой запуск (Авторизация)
newman run collections/modules/auth/auth.json -e collections/AuthTest.postman_environment.json --insecure

# Простой запуск (Умный OCR)
newman run collections/modules/projects/smart-ocr.json -e collections/AuthTest.postman_environment.json --insecure

# С Allure отчётом
newman run collections/modules/auth/auth.json -e collections/AuthTest.postman_environment.json --insecure --reporters cli,allure --reporter-allure-export allure-results
allure serve allure-results
```

### Запуск всех модулей

```bash
# Запуск всех тестов подряд
newman run collections/modules/auth/auth.json -e collections/AuthTest.postman_environment.json --insecure && \
newman run collections/modules/projects/smart-ocr.json -e collections/AuthTest.postman_environment.json --insecure
```

---

## 📖 Документация тест-кейсов

---

## Модуль: 00 - Авторизация

**Файл:** `collections/modules/auth/auth.json`

### Тест-кейсы

#### 1. Проверка доступности

| # | Шаг | Метод | Endpoint | Проверки |
|---|-----|-------|----------|----------|
| 1 | Health Check | GET | `/login` | Status 200/302/401/403, Response time < 5000ms |

#### 2. Авторизация

| # | Тест-кейс | Метод | Endpoint | Описание |
|---|-----------|-------|----------|----------|
| 2.1 | Успешная авторизация | POST | `/auth/account` | Позитивный тест с валидными учётными данными |
| 2.2 | Неверные учётные данные | POST | `/auth/account` | Негативный тест с неправильными credentials |
| 2.3 | Пустые учётные данные | POST | `/auth/account` | Негативный тест с пустыми полями |

**Проверки теста 2.1 (Успешная авторизация):**

| Проверка | Описание |
|----------|----------|
| Status 200 | Успешная авторизация |
| Response is JSON | Ответ в формате JSON |
| Token exists | JWT токен присутствует |
| fullName exists | Имя пользователя возвращено |
| isAdmin is boolean | Флаг администратора корректного типа |
| permissions is array | Массив прав доступа |
| AccessToken cookie | Cookie с access token |
| RefreshToken cookie | Cookie с refresh token |

**Проверки теста 2.2 (Неверные credentials):**

| Проверка | Описание |
|----------|----------|
| Status 401 | Unauthorized |

**Проверки теста 2.3 (Пустые credentials):**

| Проверка | Описание |
|----------|----------|
| Status 400 или 401 | Bad Request или Unauthorized |

---

## Модуль: 01 - Проекты → Умный OCR

**Файл:** `collections/modules/projects/smart-ocr.json`

**Подробная документация:** `collections/modules/projects/README.md`

### Тест-кейс: Проверка создания проекта (Распознавания документов в утверждённой форме)

#### Предусловия

- Пользователь авторизован с правами администратора
- Базовый URL системы доступен
- Учётные данные корректны

#### Шаги выполнения

| # | Шаг | Метод | Endpoint | Описание |
|---|-----|-------|----------|----------|
| 1 | Авто-логин | POST | `/auth/account` | Получение JWT токена для авторизации |
| 2 | Создание проекта | POST | `/api/Projects` | Создание нового проекта OCR |
| 3 | Получение проекта | GET | `/api/Projects/{id}` | Проверка созданного проекта |
| 4 | Проверка схемы разметки | GET | `/api/MarkingSchemes/project/{id}` | Проверка автоматического создания схемы |
| 5 | Удаление проекта | DELETE | `/api/Projects/{id}` | Очистка тестовых данных (TEARDOWN) |

#### Входные данные

**POST /api/Projects:**

```json
{
  "name": "autotest_ocr_{{timestamp}}",
  "description": "Тестовый проект OCR для автотестов",
  "component": 0,
  "modelUsage": 0
}
```

| Параметр | Тип | Описание |
|----------|-----|----------|
| `name` | string | Уникальное имя проекта (генерируется автоматически) |
| `description` | string | Описание проекта |
| `component` | number | Тип компонента: `0` = Умный OCR |
| `modelUsage` | number | Использование модели: `0` = По умолчанию |

#### Проверки

**Шаг 1: Авторизация**

| Проверка | Ожидаемое значение |
|----------|-------------------|
| Status | 200 OK |
| Token | JWT токен сохранён в environment |

**Шаг 2: Создание проекта**

| Проверка | Ожидаемое значение |
|----------|-------------------|
| Status | 201 Created |
| Response | ID созданного проекта (число > 0) |

**Шаг 3: Получение проекта**

| Проверка | Ожидаемое значение |
|----------|-------------------|
| Status | 200 OK |
| `id` | Совпадает с созданным |
| `name` | Совпадает с отправленным |
| `description` | "Тестовый проект OCR для автотестов" |
| `component` | 0 |
| `smartOCRModelUsage` | 0 |
| `dataSetCount` | 0 |
| `freeDoc` | false |

**Шаг 4: Проверка схемы разметки**

| Проверка | Ожидаемое значение |
|----------|-------------------|
| Status | 200 OK |
| `result` | Массив схем разметки |
| `result.length` | >= 1 (минимум одна схема) |
| `result[0].projectId` | Совпадает с ID проекта |
| `result[0].name` | Непустая строка |

**Шаг 5: Удаление проекта (TEARDOWN)**

| Проверка | Ожидаемое значение |
|----------|-------------------|
| Status | 204 No Content или 200 OK |

---

## Переменные окружения

| Переменная | Описание | Пример |
|------------|----------|--------|
| `baseUrl` | Базовый URL системы | `https://10.0.0.164:44392` |
| `username` | Логин пользователя | `admin` |
| `password` | Пароль пользователя | `Qwe123!@#` |
| `token` | JWT токен (автоматически) | - |
| `runSuffix` | Уникальный суффикс (автоматически) | `1713408425123` |
| `newProjectName` | Имя проекта (автоматически) | `autotest_ocr_1713408425123` |
| `createdProjectId` | ID созданного проекта | `341` |
| `createdMarkingSchemeId` | ID схемы разметки | `1193` |

---

## Принципы тестирования

### Автономность

- Каждый тест полностью независим
- Имена сущностей генерируются с уникальным суффиксом через `Date.now()`
- Авторизация происходит автоматически перед каждым запуском

### Self-cleanup

- После выполнения теста созданные данные удаляются
- Переменные очищаются в TEARDOWN
- Удаляются только созданные сущности (по сохранённым ID)

### Безопасность данных

- Тесты НЕ удаляют существующие данные
- Тесты создают только новые сущности с уникальными именами
- После завершения все созданные данные очищаются

---

## Allure отчёт

После запуска тестов с флагом `--reporters allure` автоматически генерируется отчёт:

```bash
# Просмотр отчёта
allure serve allure-results
```

---

## Возможные ошибки

| Ошибка | Причина | Решение |
|--------|---------|---------|
| `401 Unauthorized` | Неверные учётные данные | Проверить `username`/`password` |
| `Connection refused` | Недоступен сервер | Проверить `baseUrl` |
| `500 Internal Server Error` | Ошибка сервера | Проверить логи сервера |
| `Project already exists` | Конфликт имён | Тест использует уникальные имена |

---

## Добавление новых тестов

### Структура нового модуля

1. Создайте папку: `collections/modules/<категория>/`
2. Создайте JSON файл с коллекцией Postman
3. Создайте README.md с документацией
4. Обновите этот файл (список модулей)

### Шаблон коллекции

Используйте существующие коллекции как шаблон:
- `collections/modules/auth/auth.json` - пример авторизации
- `collections/modules/projects/smart-ocr.json` - пример CRUD операций

---

## Источник данных

Коллекции тестов созданы на основе HAR файлов:
- `test.har` - исходный запрос авторизации
- HAR файлы из `/home/ilya/harfiles/` - записи браузерных запросов