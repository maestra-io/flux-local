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

## Установка форка в Docker

### Вариант 1: Установка из Git-репозитория (рекомендуется)

Если форк загружен в Git-репозиторий:

```dockerfile
FROM python:3.11-slim

# Установка зависимостей системы
RUN apt-get update && apt-get install -y \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Установка flux CLI
RUN curl -s https://fluxcd.io/install.sh | bash

# Установка модифицированного flux-local из git
RUN pip install git+https://github.com/your-username/flux-local.git@your-branch

# Или установка из конкретного коммита
# RUN pip install git+https://github.com/your-username/flux-local.git@commit-hash

WORKDIR /workspace

CMD ["bash"]
```

### Вариант 2: Установка из локального каталога

Если нужно использовать локальную версию:

```dockerfile
FROM python:3.11-slim

# Установка зависимостей системы
RUN apt-get update && apt-get install -y \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Установка flux CLI
RUN curl -s https://fluxcd.io/install.sh | bash

# Копирование исходников форка
COPY . /tmp/flux-local

# Установка из локального каталога
RUN pip install /tmp/flux-local && rm -rf /tmp/flux-local

WORKDIR /workspace

CMD ["bash"]
```

### Вариант 3: Multi-stage build (оптимизированный)

Для минимизации размера образа:

```dockerfile
# Этап 1: Сборка
FROM python:3.11-slim AS builder

RUN apt-get update && apt-get install -y git

# Установка flux-local в виртуальное окружение
RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Установка из git или локального каталога
COPY . /tmp/flux-local
RUN pip install --no-cache-dir /tmp/flux-local

# Этап 2: Финальный образ
FROM python:3.11-slim

# Копирование виртуального окружения из builder
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Установка только необходимых runtime зависимостей
RUN apt-get update && apt-get install -y \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Установка flux CLI
RUN curl -s https://fluxcd.io/install.sh | bash

# Создание директории для кеша
RUN mkdir -p /cache/flux-local/helm

WORKDIR /workspace

CMD ["bash"]
```

### Использование в GitLab CI/CD с кастомным образом

#### Создание образа с форком

**Dockerfile:**
```dockerfile
FROM python:3.11-slim

RUN apt-get update && apt-get install -y \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

RUN curl -s https://fluxcd.io/install.sh | bash

# Установка модифицированного flux-local
RUN pip install git+https://github.com/your-username/flux-local.git@dev

RUN mkdir -p /cache/flux-local/helm

WORKDIR /workspace
```

**Сборка и публикация образа:**
```bash
docker build -t registry.gitlab.com/your-group/flux-local:latest .
docker push registry.gitlab.com/your-group/flux-local:latest
```

**Использование в .gitlab-ci.yml:**
```yaml
variables:
  FLUX_LOCAL_TIMEOUT: "600"
  FLUX_LOCAL_HELM_CACHE_DIR: "$CI_PROJECT_DIR/.cache/flux-local/helm"

cache:
  key: flux-helm-cache
  paths:
    - .cache/flux-local/helm

flux-local-test:
  stage: test
  image: registry.gitlab.com/your-group/flux-local:latest
  script:
    - flux-local test --enable-helm --path clusters/
```

### Вариант 4: Установка requirements из форка

Создайте `requirements.txt` в вашем проекте:

```text
# requirements.txt
git+https://github.com/your-username/flux-local.git@dev
```

**Dockerfile:**
```dockerfile
FROM python:3.11-slim

RUN apt-get update && apt-get install -y \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

RUN curl -s https://fluxcd.io/install.sh | bash

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

WORKDIR /workspace

CMD ["bash"]
```

### Переменные окружения в Docker

Установите переменные окружения в Dockerfile или при запуске:

**В Dockerfile:**
```dockerfile
ENV FLUX_LOCAL_TIMEOUT=600
ENV FLUX_LOCAL_HELM_CACHE_DIR=/cache/flux-local/helm
```

**При запуске контейнера:**
```bash
docker run -e FLUX_LOCAL_TIMEOUT=600 \
           -e FLUX_LOCAL_HELM_CACHE_DIR=/cache/flux-local/helm \
           -v $(pwd):/workspace \
           your-image:tag \
           flux-local test --enable-helm
```

### Docker Compose пример

```yaml
version: '3.8'

services:
  flux-local:
    build:
      context: .
      dockerfile: Dockerfile
    environment:
      - FLUX_LOCAL_TIMEOUT=600
      - FLUX_LOCAL_HELM_CACHE_DIR=/cache/flux-local/helm
    volumes:
      - ./clusters:/workspace/clusters
      - flux-helm-cache:/cache/flux-local/helm
    command: flux-local test --enable-helm --path clusters/

volumes:
  flux-helm-cache:
```
