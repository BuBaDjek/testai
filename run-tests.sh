#!/bin/bash

# Скрипт для запуска автотестов
# Модульная структура на основе проекта PostmanCollection
#
# Использование:
#   ./run-tests.sh          - запустить все тесты с Allure отчётом
#   ./run-tests.sh simple   - запустить все тесты без отчёта
#   ./run-tests.sh auth     - запустить только тесты авторизации
#   ./run-tests.sh ocr      - запустить только тесты Умный OCR
#   ./run-tests.sh ai       - запустить только тесты AI Текст
#   ./run-tests.sh help     - показать справку

ENV="collections/AuthTest.postman_environment.json"
MODULES_DIR="collections/modules"
DELAY=1000

# Список модулей для запуска
declare -a MODULES=(
    "auth/auth"
    "projects/smart-ocr"
    "projects/smart-ai"
    "projects/smart-func"
    "home-page/home-page"
    "machines/general"
    "settings/roles"
    "settings/users"
)

declare -a MODULE_NAMES=(
    "00 - Авторизация"
    "01 - Проекты → Умный OCR"
    "02 - Проекты → AI Текст"
    "03 - Проекты → Функционал"
    "04 - Главная страница"
    "05 - Машины"
    "06 - Настройки → Роли"
    "07 - Настройки → Пользователи"
)

show_help() {
    echo "================================"
    echo "  Autotest Runner"
    echo "================================"
    echo ""
    echo "Использование:"
    echo "  ./run-tests.sh          - запустить все тесты с Allure отчётом"
    echo "  ./run-tests.sh simple   - запустить все тесты без отчёта"
    echo "  ./run-tests.sh auth     - запустить только тесты авторизации"
    echo "  ./run-tests.sh ocr      - запустить только тесты Умный OCR"
    echo "  ./run-tests.sh help     - показать эту справку"
    echo ""
    echo "Модули:"
    echo "  auth    - Тесты авторизации (auth/auth.json)"
    echo "  ocr     - Тесты Умный OCR (projects/smart-ocr.json)"
    echo ""
    echo "Структура проекта:"
    echo "  collections/modules/auth/auth.json         - тесты авторизации"
    echo "  collections/modules/projects/smart-ocr.json - тесты Умный OCR"
    echo "  collections/AuthTest.postman_environment.json - переменные окружения"
    echo ""
    echo "Для изменения параметров подключения отредактируйте environment файл:"
    echo "  - baseUrl: URL сервера"
    echo "  - username: имя пользователя"
    echo "  - password: пароль"
}

run_module() {
    local module_path="$1"
    local module_name="$2"
    local report_flag="$3"
    
    local full_path="${MODULES_DIR}/${module_path}.json"
    
    if [ ! -f "$full_path" ]; then
        echo "❌ Файл коллекции не найден: $full_path"
        return 1
    fi
    
    echo ""
    echo "--------------------------------"
    echo "  Модуль: $module_name"
    echo "  Файл: $full_path"
    echo "--------------------------------"
    echo ""
    
    if [ "$report_flag" = "allure" ]; then
        newman run "$full_path" \
            -e "$ENV" \
            --delay-request "$DELAY" \
            --insecure \
            --reporters cli,allure \
            --reporter-allure-export allure-results
    else
        newman run "$full_path" \
            -e "$ENV" \
            --delay-request "$DELAY" \
            --insecure \
            --reporters cli
    fi
    
    return $?
}

run_all_simple() {
    echo "================================"
    echo "  Запуск всех тестов"
    echo "  (без Allure отчёта)"
    echo "================================"
    
    if [ ! -f "$ENV" ]; then
        echo "❌ Файл окружения не найден: $ENV"
        exit 1
    fi
    
    local failed=0
    local total=${#MODULES[@]}
    
    for i in "${!MODULES[@]}"; do
        run_module "${MODULES[$i]}" "${MODULE_NAMES[$i]}" "simple"
        if [ $? -ne 0 ]; then
            failed=$((failed + 1))
        fi
    done
    
    echo ""
    echo "================================"
    echo "  Результат: $((total - failed))/$total модулей пройдено"
    echo "================================"
    
    return $failed
}

run_all_with_report() {
    echo "================================"
    echo "  Запуск всех тестов"
    echo "  с Allure отчётом"
    echo "================================"
    
    if [ ! -f "$ENV" ]; then
        echo "❌ Файл окружения не найден: $ENV"
        exit 1
    fi
    
    # Очистка старых результатов
    rm -rf allure-results 2>/dev/null
    mkdir -p allure-results
    
    local failed=0
    local total=${#MODULES[@]}
    
    for i in "${!MODULES[@]}"; do
        run_module "${MODULES[$i]}" "${MODULE_NAMES[$i]}" "allure"
        if [ $? -ne 0 ]; then
            failed=$((failed + 1))
        fi
    done
    
    echo ""
    echo "================================"
    echo "  Результат: $((total - failed))/$total модулей пройдено"
    echo "================================"
    echo ""
    echo "Генерация Allure отчёта..."
    echo "================================"
    
    allure serve allure-results
    
    return $failed
}

run_single() {
    local module_key="$1"
    local report_flag="$2"
    
    local module_path=""
    local module_name=""
    
    case "$module_key" in
        auth)
            module_path="auth/auth"
            module_name="00 - Авторизация"
            ;;
        ocr)
            module_path="projects/smart-ocr"
            module_name="01 - Проекты → Умный OCR"
            ;;
        ai)
            module_path="projects/smart-ai"
            module_name="02 - Проекты → AI Текст"
            ;;
        func)
            module_path="projects/smart-func"
            module_name="03 - Проекты → Функционал"
            ;;
        home)
            module_path="home-page/home-page"
            module_name="04 - Главная страница"
            ;;
        machines)
            module_path="machines/general"
            module_name="05 - Машины"
            ;;
        settings)
            module_path="settings/roles"
            module_name="06 - Настройки → Роли"
            ;;
        users)
            module_path="settings/users"
            module_name="07 - Настройки → Пользователи"
            ;;
        *)
            echo "❌ Неизвестный модуль: $module_key"
            echo "Доступные модули: auth, ocr, ai, func, home, machines, settings, users"
            exit 1
            ;;
    esac
    
    if [ ! -f "$ENV" ]; then
        echo "❌ Файл окружения не найден: $ENV"
        exit 1
    fi
    
    if [ "$report_flag" = "allure" ]; then
        rm -rf allure-results 2>/dev/null
        mkdir -p allure-results
    fi
    
    run_module "$module_path" "$module_name" "$report_flag"
    local result=$?
    
    if [ "$report_flag" = "allure" ]; then
        echo ""
        echo "================================"
        echo "Генерация Allure отчёта..."
        echo "================================"
        allure serve allure-results
    fi
    
    return $result
}

# Проверка наличия newman
if ! command -v newman &> /dev/null; then
    echo "❌ Newman не установлен!"
    echo ""
    echo "Установка:"
    echo "  npm install -g newman newman-reporter-allure"
    exit 1
fi

# Главная логика
if [ "$1" = "help" ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    show_help
    exit 0
fi

if [ "$1" = "simple" ]; then
    run_all_simple
    exit $?
fi

if [ "$1" = "auth" ]; then
    run_single "auth" "simple"
    exit $?
fi

if [ "$1" = "ocr" ]; then
    run_single "ocr" "simple"
    exit $?
fi

if [ "$1" = "ai" ]; then
    run_single "ai" "simple"
    exit $?
fi

if [ "$1" = "home" ]; then
    run_single "home" "simple"
    exit $?
fi

if [ "$1" = "machines" ]; then
    run_single "machines" "simple"
    exit $?
fi

if [ "$1" = "settings" ]; then
    run_single "settings" "simple"
    exit $?
fi

if [ "$1" = "users" ]; then
    run_single "users" "simple"
    exit $?
fi

# По умолчанию - все тесты с отчётом
run_all_with_report
