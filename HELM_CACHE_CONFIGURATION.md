# Конфигурация кеша Helm и таймаутов

Этот документ описывает настройку директории кеша Helm и таймаутов выполнения команд для flux-local.

## Обзор

Доступны две переменные окружения для настройки поведения flux-local:

1. **`FLUX_LOCAL_HELM_CACHE_DIR`** - настройка постоянной директории кеша Helm charts
2. **`FLUX_LOCAL_TIMEOUT`** - настройка таймаута выполнения команд

## Конфигурация кеша Helm

### Проблема
По умолчанию flux-local использовал временные директории для кеша Helm, которые удалялись после каждого запуска. Это означало, что Helm charts приходилось загружать из удаленных репозиториев каждый раз, что вызывало:
- Медленное выполнение
- Потенциальные ошибки таймаута для больших charts
- Ненужный сетевой трафик
- Сбои при медленных или недоступных удаленных репозиториях

### Решение
Кеш Helm теперь постоянный по умолчанию и настраивается через переменную окружения.

### Поведение по умолчанию
Если `FLUX_LOCAL_HELM_CACHE_DIR` не установлена, flux-local будет использовать:
```
~/.cache/flux-local/helm
```

Эта директория сохраняется между запусками, позволяя переиспользовать charts.

### Пользовательская директория кеша
Установите переменную окружения для использования пользовательской директории:

```bash
export FLUX_LOCAL_HELM_CACHE_DIR=/path/to/your/helm/cache
flux-local build hr podinfo -n podinfo --path tests/testdata/cluster/
```

### Очистка кеша
Для очистки кеша Helm и принудительной повторной загрузки всех charts:

```bash
# Использование стандартного расположения кеша
rm -rf ~/.cache/flux-local/helm

# Использование пользовательского расположения кеша
rm -rf $FLUX_LOCAL_HELM_CACHE_DIR
```

## Конфигурация таймаута

### Проблема
Команды в flux-local имели жестко закодированный таймаут в 60 секунд, чего было недостаточно для:
- Загрузки больших Helm charts
- Медленных сетевых соединений
- Сложных Kustomizations
- Удаленных репозиториев с ограничением скорости

### Решение
Таймаут теперь настраивается через переменную окружения.

### Поведение по умолчанию
Если `FLUX_LOCAL_TIMEOUT` не установлена, таймаут по умолчанию составляет 60 секунд.

### Пользовательский таймаут
Установите переменную окружения для использования пользовательского таймаута (в секундах):

```bash
# Установить таймаут на 5 минут (300 секунд)
export FLUX_LOCAL_TIMEOUT=300
flux-local build hr podinfo -n podinfo --path tests/testdata/cluster/

# Установить таймаут на 10 минут (600 секунд)
export FLUX_LOCAL_TIMEOUT=600
flux-local test --enable-helm
```

## Примеры использования

### Пример 1: Использование постоянного кеша с увеличенным таймаутом
```bash
export FLUX_LOCAL_HELM_CACHE_DIR=~/.cache/flux-local/helm
export FLUX_LOCAL_TIMEOUT=300

flux-local build hr my-release -n my-namespace --path clusters/prod/
```

### Пример 2: Использование пользовательской директории кеша для CI/CD
```bash
# В CI/CD пайплайне используйте общую директорию кеша
export FLUX_LOCAL_HELM_CACHE_DIR=/cache/flux-helm
export FLUX_LOCAL_TIMEOUT=600

flux-local test --enable-helm --path clusters/
```

### Пример 3: Отключение кеша (использование временной директории)
```bash
# Установить временную директорию, которая будет очищена
export FLUX_LOCAL_HELM_CACHE_DIR=$(mktemp -d)

flux-local build hr my-release -n my-namespace

# Очистка
rm -rf $FLUX_LOCAL_HELM_CACHE_DIR
```

### Пример 4: GitLab CI/CD

#### Базовый пример с кешированием
```yaml
variables:
  FLUX_LOCAL_TIMEOUT: "600"

cache:
  key: flux-helm-cache
  paths:
    - .cache/flux-local/helm

flux-local-test:
  stage: test
  image: python:3.11
  before_script:
    - pip install flux-local
    - apt-get update && apt-get install -y curl
    # Установка flux CLI
    - curl -s https://fluxcd.io/install.sh | bash
    - export PATH=$PATH:$HOME/.local/bin
  script:
    - export FLUX_LOCAL_HELM_CACHE_DIR=$CI_PROJECT_DIR/.cache/flux-local/helm
    - flux-local test --enable-helm --path clusters/
```

#### Расширенный пример с матрицей для нескольких кластеров
```yaml
variables:
  FLUX_LOCAL_TIMEOUT: "600"
  FLUX_LOCAL_HELM_CACHE_DIR: "$CI_PROJECT_DIR/.cache/flux-local/helm"

cache:
  key:
    files:
      - clusters/**/helmrelease.yaml
    prefix: flux-helm
  paths:
    - .cache/flux-local/helm

.flux-local-base:
  stage: test
  image: python:3.11
  before_script:
    - pip install flux-local
    - apt-get update && apt-get install -y curl
    - curl -s https://fluxcd.io/install.sh | bash
    - export PATH=$PATH:$HOME/.local/bin
    - mkdir -p $FLUX_LOCAL_HELM_CACHE_DIR

flux-local-test-dev:
  extends: .flux-local-base
  script:
    - flux-local test --enable-helm --path clusters/dev/

flux-local-test-prod:
  extends: .flux-local-base
  script:
    - flux-local test --enable-helm --path clusters/prod/

flux-local-build:
  extends: .flux-local-base
  script:
    - flux-local build hr --all-namespaces --path clusters/prod/
  artifacts:
    paths:
      - output/
    expire_in: 1 week
```

#### Пример с очисткой кеша по расписанию
```yaml
variables:
  FLUX_LOCAL_TIMEOUT: "600"

cache:
  key: flux-helm-cache
  paths:
    - .cache/flux-local/helm
  policy: pull-push

# Обычные тесты используют кеш
flux-local-test:
  stage: test
  script:
    - export FLUX_LOCAL_HELM_CACHE_DIR=$CI_PROJECT_DIR/.cache/flux-local/helm
    - flux-local test --enable-helm --path clusters/
  except:
    - schedules

# Еженедельная очистка кеша
flux-local-test-clean:
  stage: test
  cache:
    policy: push  # Только запись, игнорируем существующий кеш
  before_script:
    - rm -rf $CI_PROJECT_DIR/.cache/flux-local/helm
  script:
    - export FLUX_LOCAL_HELM_CACHE_DIR=$CI_PROJECT_DIR/.cache/flux-local/helm
    - flux-local test --enable-helm --path clusters/
  only:
    - schedules
```

## Устранение неполадок

### Charts не кешируются
Проверьте, что директория кеша существует и доступна для записи:
```bash
ls -la ~/.cache/flux-local/helm
```

### Ошибки таймаута все еще возникают
Увеличьте значение таймаута:
```bash
export FLUX_LOCAL_TIMEOUT=900  # 15 минут
```

### Кеш занимает слишком много места
Директория кеша может расти со временем. Периодически очищайте её:
```bash
du -sh ~/.cache/flux-local/helm
rm -rf ~/.cache/flux-local/helm
```

### Проблемы с правами доступа в CI/CD
Убедитесь, что директория кеша создана и доступна для записи:
```bash
mkdir -p $FLUX_LOCAL_HELM_CACHE_DIR
chmod -R 755 $FLUX_LOCAL_HELM_CACHE_DIR
```

## Детали реализации

### Измененные файлы
- `flux_local/command.py` - добавлена поддержка переменной окружения `FLUX_LOCAL_TIMEOUT`
- `flux_local/helm.py` - добавлена функция `get_helm_cache_dir()` и поддержка `FLUX_LOCAL_HELM_CACHE_DIR`
- `flux_local/orchestrator/orchestrator.py` - обновлен для использования настраиваемого кеша
- `flux_local/tool/build.py` - обновлен для использования настраиваемого кеша
- `flux_local/tool/diff.py` - обновлен для использования настраиваемого кеша
- `flux_local/tool/get.py` - обновлен для использования настраиваемого кеша
- `flux_local/tool/test.py` - обновлен для использования настраиваемого кеша

### Обратная совместимость
Все изменения обратно совместимы. Если переменные окружения не установлены:
- Кеш Helm по умолчанию использует `~/.cache/flux-local/helm` (постоянный)
- Таймаут по умолчанию составляет 60 секунд

Изменения в существующем коде или конфигурациях не требуются.
