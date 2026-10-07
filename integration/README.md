# DELTA:DOCS — развёртывание

## Запуск

Нужен Docker.

```bash
docker compose up -d
```

или без compose:

```bash
docker run -d --name delta-docs --restart unless-stopped -p 8080:8080 -v "${PWD}/delta:/app/delta" ghcr.io/dela-soft/docs:latest
```

(bash и PowerShell — из папки с `compose.yml`.)

или через `make` (если установлен):

| Команда | Действие |
|---------|----------|
| `make up` | Запустить |
| `make pull` | Скачать новую версию образа и перезапустить |
| `make down` | Остановить |
| `make logs` | Логи |

Обновление без `make`: `docker compose pull && docker compose up -d`.

Редактор: http://localhost:8080

Linux: контейнер работает под пользователем `app` (uid 1654) — дайте ему право записи в `delta/`:

```bash
sudo chown -R 1654:1654 delta
```

## Что внутри

| Путь | Назначение |
|------|------------|
| `compose.yml` | Запуск контейнера |
| `Makefile` | Короткие команды запуска и обновления |
| `delta/public/` | Ваши шаблоны (`.dlt`, `.dtc`); `path` в `DeltaDocs.open` — относительно этой папки |
| `delta/public/scripts/` | Скрипты; `include "common/ru"` — относительно этой папки |
| `delta/public/scripts/common/` | Стандартная библиотека: даты, числа и суммы прописью, склонение |
| `delta/fonts/` | Шрифты для редактора и PDF |
| `host/delta-docs.js` | Клиент для вашего web-приложения |
| `host/example.html` | Пример страницы host: открыть в браузере после `docker compose up -d` |

## Подключение к приложению

```html
<script src="delta-docs.js"></script>
<script>
  const docs = new DeltaDocs('http://localhost:8080')
  docs.open({ path: 'report.dlt', tables: { Сотрудники: rows } })
</script>
```

Вызов API приложения из скриптов (`host://`) и защита записи — закомментированные строки в `compose.yml`, креды передаются в `open({ auth: { headers } })`.

Подробно: [инструкция по интеграции](https://docs-demo.delasoft.org/instructions.html).
