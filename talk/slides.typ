// SPDX-FileCopyrightText: 2026 comfydv
//
// SPDX-License-Identifier: CC-BY-SA-4.0

#import "slides-lib.typ": *


#let authors = [Егор Семёнов, Артём Шкурат]
#show: deck.with(
  title: [Контейнеризация Django],
  subtitle: [Docker, Compose и Podman: от "локально работает" к "стабильно деплоится"],
  author: authors,
)

#let shot-note = muted[Настоящий вывод: Podman 6.1.4, podman-compose 1.6.0.]

#title-slide(extra: grid(
  columns: 2,
  column-gutter: 2.5em,
  align: horizon,
  podman-logo(3em), docker-logo(2.6em),
))

== План <no-cue>

#grid(
  columns: (1fr, 1fr),
  column-gutter: 2em,
  [
    + Контейнеры и движки
    + Многоступенчатые сборки
    + Compose
    + Healthcheck
    + Entrypoint и миграции при старте
  ],
  [
    #set enum(start: 6)
    + Миграции Django
    + Логи
    + Как контейнеры устроены внутри
    + Podman и Docker: итог
    + Пример: Django в контейнере
  ],
)

= Контейнеры и движки

== "У меня работает" <s-works-on-my-machine>

#grid(
  columns: (1fr, 1fr),
  column-gutter: 1.5em,
  align: horizon,
  [
    Код одинаковый, а запуск у одногруппника падает:

    - другая версия Python
    - не установлена библиотека
    - установлена, но другая версия
  ],
  [
    #image("img/container-ship.jpg", width: 100%)
    #v(-0.6em)
    #text(size: 9pt, fill: luma(120))[Фото: Trougnouf, CC BY 4.0, Wikimedia Commons]
  ],
)

#key[Отличается не код, а *окружение*: интерпретатор, библиотеки, настройки.]

== Движки: Docker и Podman <s-engines>

#grid(
  columns: (1fr, 1fr),
  column-gutter: 2em,
  align: horizon,
  align(center)[
    #grid(columns: 2, column-gutter: 1.5em, align: horizon, podman-icon(3.2em), docker-icon(2.6em))
    #v(0.4em)
    #muted[Собирают образы и запускают контейнеры]
  ],
  [
    - *Движок* --- программа, которая собирает образы и запускает контейнеры
    - 2015: Docker с другими компаниями основал *Open Container Initiative* и отдал туда формат образов и рантайм
    - Формат открытый: образ одного движка запускается другим
  ],
)

== Containerfile, образ, контейнер <s-containerfile-image-container>

#align(center + horizon, diagram(
  spacing: (4.5em, 1.2em),
  node-stroke: 1pt,
  node-corner-radius: 5pt,
  node-inset: 12pt,
  node((0, 1), [*Containerfile* \ #muted[файл сборки; у Docker --- Dockerfile]], name: <df>),
  e(<df>, <img>, "-|>", small[`build`]),
  node((1, 1), [*образ* \ #muted[шаблон]], name: <img>, fill: box-fill),
  e(<img>, <c1>, "-|>", small[`run`]),
  e(<img>, <c2>, "-|>"),
  e(<img>, <c3>, "-|>"),
  node((2, 0), [контейнер], name: <c1>, fill: warm-fill),
  node((2, 1), [контейнер], name: <c2>, fill: warm-fill),
  node((2, 2), [контейнер], name: <c3>, fill: warm-fill),
))

#key[Описание сборки, результат сборки и запущенная программа --- разные вещи.]

== Контейнер --- не виртуальная машина <s-not-a-vm>

#grid(
  columns: (1fr, 1fr),
  column-gutter: 2.5em,
  row-gutter: 0.4em,
  align(center)[*Виртуальные машины*], align(center)[*Контейнеры*],
  stack(
    spacing: 4pt,
    grid(columns: 2, column-gutter: 4pt,
      layer(fill: warm-fill)[приложение], layer(fill: warm-fill)[приложение]),
    grid(columns: 2, column-gutter: 4pt,
      layer[гостевая ОС \ *своё ядро*], layer[гостевая ОС \ *своё ядро*]),
    layer[гипервизор],
    layer[оборудование],
  ),
  stack(
    spacing: 4pt,
    grid(columns: 2, column-gutter: 4pt,
      layer(fill: warm-fill)[контейнер], layer(fill: warm-fill)[контейнер]),
    layer[*общее ядро* хоста],
    layer[оборудование],
  ),
)

#v(0.3em)
#key[Контейнер --- обычный процесс, который ядро хоста изолирует от остальных.]

= Многоступенчатые сборки

== Наивный Containerfile <s-naive-containerfile>

```dockerfile
FROM docker.io/library/python:3.13-slim-trixie
RUN apt-get update && apt-get install -y --no-install-recommends gcc libc6-dev libpq-dev
WORKDIR /app
COPY . .
RUN pip install -r requirements.txt
CMD python manage.py migrate --noinput && gunicorn config.wsgi:application --bind=0.0.0.0:8000
```

#key[Компилятор и заголовки уезжают в продакшен.]

== Два этапа: собрать и поставить <s-two-stages>

#align(center, text(size: 14pt, diagram(
  spacing: (10.5em, 0.5em),
  node-stroke: 1pt,
  node-corner-radius: 5pt,
  node-inset: 7pt,
  node((0, 0), align(left)[*builder* \ компилятор, заголовки, сборка], name: <b>, fill: box-fill),
  e(<b>, <r>, "-|>", small[`COPY --from`], label-side: left),
  node((1, 0), align(left)[*runtime* \ библиотеки, зависимости, код], name: <r>, fill: warm-fill),
  e(<r>, <i>, "-|>"),
  node((2, 0), [*образ*], name: <i>, stroke: 2pt + accent),
  node((0, 1), muted[в образ не попадает], stroke: none),
)))

#[
#show raw.where(block: true): set text(size: 11.5pt)
```dockerfile
FROM docker.io/library/python:3.13-slim-trixie AS builder
RUN apt-get update && apt-get install -y --no-install-recommends gcc libc6-dev libpq-dev
RUN python -m venv /opt/venv
COPY requirements.txt .
RUN /opt/venv/bin/pip install --no-cache-dir -r requirements.txt

FROM docker.io/library/python:3.13-slim-trixie AS runtime
RUN apt-get update && apt-get install -y --no-install-recommends libpq5
COPY --from=builder /opt/venv /opt/venv
COPY . .
```
]

#text(size: 18pt, key[Как у компилируемых языков: собрали, а поставляем только результат.])

== Результат: замер на Podman <s-size-result>

#terminal("captures/images.txt", title: [podman #sym.dot.c demo], size: 13pt)

#text(size: 19pt, table(
  columns: (1fr, auto, auto),
  inset: 7pt,
  stroke: 0.5pt + luma(180),
  table.header([], [*Наивный*], [*Многоступенчатый*]),
  [Размер образа], [*411 МБ*], [*186 МБ*],
  [Компилятор в образе], [есть], [нет],
))

#muted[Базовый `python:3.13-slim-trixie` --- 123 МБ: наивная сборка добавляет к нему 288 МБ, многоступенчатая --- 63 МБ. `.dockerignore` не пускает в сборку `.git` и `.env`.]

= Compose

== Один файл вместо длинных команд <s-compose-file>

```yaml
services:
  db:
    image: docker.io/library/postgres:17-alpine
    environment:
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
    volumes:
      - pgdata:/var/lib/postgresql/data

  web:
    image: localhost/djdemo:latest
    ports:
      - "127.0.0.1:8000:8000"

volumes:
  pgdata:
```

== Схема проекта <s-project-diagram>

#align(center, diagram(
  spacing: (7em, 2.5em),
  node-stroke: 1pt,
  node-corner-radius: 5pt,
  node-inset: 12pt,
  node((0, 0), [хост \ `127.0.0.1:8000`], name: <host>),
  e(<host>, <web>, "-|>", small[порт 8000]),
  node((1, 0), [*web*], name: <web>, fill: warm-fill),
  e(<web>, <db>, "-|>", small[по имени `db`]),
  node((2, 0), [*db*], name: <db>, fill: box-fill),
  e(<db>, <vol>, "-"),
  node((2, 1), [том `pgdata`], name: <vol>, stroke: (dash: "dashed")),
  node((1, 1), [`compose.yaml` \ #muted[значения из `.env`]], name: <cfg>, fill: box-fill),
  e(<cfg>, <web>, "-|>", small[пароли и ключи]),
  node(
    enclose: (<web>, <db>),
    stroke: (paint: luma(150), dash: "dashed"),
    inset: 22pt,
    corner-radius: 8pt,
  ),
  node((1.5, -0.75), muted[сеть проекта], stroke: none),
))

#v(-0.3em)
#text(size: 16pt)[
  - *Сеть:* сервисы находят друг друга по имени, адрес базы --- `db`; у `db` нет портов, снаружи она недоступна
  - *`127.0.0.1:8000:8000`:* только локальный интерфейс, без адреса порт открыт на всех
  - *Том:* `pgdata` переживает пересоздание контейнера
  - *Секреты:* значения в `.env`, он не попадает ни в git, ни в образ
]

== Порядок и перезапуск: `depends_on`, `restart` <s-order-restart>

#grid(
  columns: (1fr, 1.6fr),
  column-gutter: 1.5em,
  align: horizon,
  ```yaml
  web:
    depends_on:
      - db
    restart: unless-stopped
  ```,
  [
    - `depends_on`: сначала `db`, потом `web`; ждёт, пока `db` станет `running`
    - `restart`: процесс завершился --- запустить заново. По умолчанию `no`
  ],
)

#v(0.4em)
#align(center, diagram(
  spacing: (8em, 1.2em),
  node-stroke: 1pt,
  node-corner-radius: 5pt,
  node-inset: 12pt,
  node((0, 0), [`created`], name: <cr>, fill: box-fill),
  e(<cr>, <run>, "-|>", small[старт]),
  node((1, 0), [`running`], name: <run>, fill: warm-fill),
  e(<run>, <ex>, "-|>", small[процесс завершился]),
  node((2, 0), [`exited` \ #muted[код выхода]], name: <ex>, fill: box-fill),
  e(<ex>, <run>, "-|>", bend: 30deg, small[`restart`]),
))

#key[`restart` срабатывает на переход в `exited`, то есть когда процесс завершился.]

== Запуск <s-compose-run>

#terminal("captures/compose-up.txt", title: [podman-compose up -d #sym.dot.c demo], size: 12pt)
#v(-0.5em)
#grid(
  columns: (1fr, 1fr),
  column-gutter: 0.8em,
  align: top,
  terminal("captures/curl-counter.txt", title: "curl", size: 12pt),
  [
    #terminal("captures/persist.txt", title: "down и снова up", size: 12pt)
    #text(size: 16pt, key[Контейнер новый, а счётчик продолжился с 4: данные лежат в томе `pgdata`.])
  ],
)

#muted[`Up ...` --- это `running`; `Exited (0)` --- завершился с кодом 0; `(healthy)` --- в следующем разделе.] \
#shot-note

= Healthcheck

== `running` не значит "работает" <s-running-not-working>

```yaml
db:
  healthcheck:
    test: ["CMD-SHELL", "pg_isready -U $$POSTGRES_USER -d $$POSTGRES_DB"]
    interval: 5s
    timeout: 3s
    retries: 10

web:
  depends_on:
    db:
      condition: service_healthy
```

- Код выхода 0 --- здоров, иначе проблема
- `$$` --- переменную подставляет оболочка в контейнере, а не Compose

== Статусы проверки <s-health-states>

#align(center + horizon, diagram(
  spacing: (9em, 3.5em),
  node-stroke: 1pt,
  node-corner-radius: 5pt,
  node-inset: 12pt,
  node((0, 0), [`starting`], name: <s>, fill: box-fill),
  e(<s>, <h>, "-|>", small[первая успешная проверка]),
  node((1, 0), [`healthy`], name: <h>, fill: rgb("#d8f0d8")),
  e(<h>, <u>, "-|>", bend: 25deg, small[`retries` неудач подряд]),
  e(<u>, <h>, "-|>", bend: 25deg, small[успешная проверка]),
  node((2, 0), [`unhealthy`], name: <u>, fill: rgb("#f6d6d6")),
  e(<s>, <u>, "-|>", bend: -50deg, label-side: right, small[`retries` неудач подряд]),
))

#key[Это только статус. Что делать с `unhealthy`, решает кто-то другой.]

== Что именно проверять <s-what-to-check>

#table(
  columns: (auto, 1fr, 1fr),
  inset: 8pt,
  stroke: 0.5pt + luma(180),
  table.header([], [*Liveness: `/healthz`*], [*Readiness: `/readyz`*]),
  [Вопрос], [Не завис ли веб-сервер?], [Может ли он сейчас обслуживать запросы?],
  [Если нет], [Перезапустить контейнер], [Не слать сюда трафик],
  [База], [Не трогает], [Выполняет `SELECT 1`],
  [При сбое базы], [200], [503],
)

#v(0.3em)
#muted[Это не встроенные адреса Django: мы добавили их сами. Имена --- как у проверок в Kubernetes.]

#key[Перезапуск веб-сервера не чинит упавшую базу.]

== Сбой базы: `unhealthy`, но не перезапущен <s-db-failure>

#grid(
  columns: (1.2fr, 1fr),
  column-gutter: 1.2em,
  align: horizon,
  [
    #terminal("captures/db-failure.txt", title: [podman-compose #sym.dot.c demo], size: 12.5pt)
    #muted[`unhealthy` через #unhealthy-after секунд: три неудачные проверки с интервалом 10 секунд.]
  ],
  text(size: 18pt)[
    #key[
      Счётчик перезапусков --- 0. Healthcheck только выставляет статус, а `restart` ждёт завершения процесса. Здесь процесс жив.
    ]

    - #docker-icon(1em) Docker: нужен внешний инструмент --- Swarm, Kubernetes, autoheal
    - #podman-icon(1.2em) Podman: реагирует сам --- `--health-on-failure`
  ],
)

== Сам лечит нездоровые контейнеры <s-health-on-failure>

#[
#set text(size: 19pt)
#terminal("captures/health-on-failure.txt", title: "podman", size: 12pt)

- `--health-on-failure`: `none`, `kill`, `restart`, `stop`
- Проверка всегда падает --- Podman сам перезапускает контейнер

#key[Счётчик перезапусков --- 1. Без оркестратора.]
]

== `HEALTHCHECK` и формат образа <s-healthcheck-oci>

#[
#set text(size: 19pt)
#terminal("captures/oci.txt", title: [podman #sym.dot.c demo], size: 12pt)

#shot-note

#grid(
  columns: (1fr, 1.15fr),
  column-gutter: 1em,
  align: horizon,
  text(size: 16pt)[
    - В OCI нет поля для инструкции `HEALTHCHECK`
    - Решение: `--format docker` или проверка в `compose.yaml`, как у нас #sym.arrow.r
  ],
  [
    #show raw.where(block: true): set text(size: 12pt)
    #text(size: 12pt)[`Containerfile` --- теряется в OCI]
    ```dockerfile
    HEALTHCHECK --interval=10s --retries=3 \
      CMD ["python", "-c", "... /healthz"]
    ```
    #text(size: 12pt)[`compose.yaml` --- работает всегда]
    ```yaml
    web:
      healthcheck:
        test: ["CMD", "python", "-c", "... /readyz"]
        interval: 10s
        retries: 3
    ```
  ],
)
]

= Entrypoint и миграции при старте

== `ENTRYPOINT` и `CMD` <s-entrypoint-cmd>

#grid(
  columns: (1.15fr, 1fr),
  column-gutter: 1.2em,
  [
    #text(size: 14pt)[`entrypoint.sh`]
    ```sh
    #!/bin/sh
    set -eu

    if [ "${DJANGO_MIGRATE_ON_START:-0}" = "1" ]; then
        python manage.py migrate --noinput
    fi

    exec "$@"
    ```
    #text(size: 14pt)[`Containerfile`]
    ```dockerfile
    ENTRYPOINT ["/app/entrypoint.sh"]
    CMD ["gunicorn", "config.wsgi:application", ...]
    ```
  ],
  [
    - Запускается `ENTRYPOINT`, а `CMD` --- его аргументы
    - `CMD` легко заменить: `podman run образ команда`
    - `ENTRYPOINT` остаётся при любой команде
    - `exec "$@"` --- запустить команду вместо себя
  ],
)

== Миграция при старте <s-migrate-on-start>

#terminal("captures/migrate-on-start.txt", title: [podman #sym.dot.c demo], size: 12pt)

- Команда заменена на `echo`, а entrypoint всё равно выполнил `migrate`
- Удобно, пока копия веб-сервера одна
- Несколько копий начнут мигрировать одновременно

#key[Поэтому в Compose миграции --- отдельный сервис `migrate`.]

== PID 1 и остановка: 0,3 с против 10 с <s-pid1>

#grid(
  columns: (1fr, 1.1fr),
  column-gutter: 1.2em,
  align: horizon,
  terminal("captures/pid1.txt", title: "podman top", size: 13pt),
  text(size: 17pt)[
    - С `exec "$@"` PID 1 --- сам `gunicorn`
    - В наивном образе с `CMD` строкой PID 1 --- оболочка, а сервер --- её дочерний процесс
    - Сигнал остановки получает PID 1
  ],
)
#v(-0.3em)
#terminal("captures/stop-time.txt", title: "podman stop", size: 11.5pt)

#text(size: 17pt, key[Оболочка на `SIGTERM` не реагирует: Podman ждёт 10 секунд и убивает контейнер через `SIGKILL`, код выхода 137.])

= Миграции Django

== Код и база расходятся <s-schema-drift>

#align(center, diagram(
  spacing: (6.5em, 1.2em),
  node-stroke: 1pt,
  node-corner-radius: 5pt,
  node-inset: 11pt,
  node((0, 0), [*модель* \ #muted[новое поле `done`]], name: <m>, fill: warm-fill),
  e(<m>, <f>, "-|>", small[`makemigrations`]),
  node((1, 0), [*файл миграции* \ #muted[хранится в] #icon("git-logo.svg", 0.9em)], name: <f>, fill: box-fill),
  e(<f>, <db>, "-|>", small[`migrate`]),
  node((2, 0), [*база* \ #muted[новый столбец]], name: <db>, fill: box-fill),
))

#text(size: 18pt, table(
  columns: (auto, 1fr, 1fr),
  inset: 6pt,
  stroke: 0.5pt + luma(180),
  table.header([], [*`makemigrations`*], [*`migrate`*]),
  [Что делает], [Создаёт файл миграции], [Применяет миграции к базе],
  [Когда], [При разработке], [При запуске или обновлении],
))

#text(size: 18pt, key[Миграции --- механизм Django. Движок только даёт среду, в которой выполняется команда.])

== Миграции в контейнере, а не при сборке <s-migrations-in-container>

#align(center, diagram(
  spacing: (4em, 1.6em),
  node-stroke: 1pt,
  node-corner-radius: 5pt,
  node-inset: 11pt,
  node((0, 0), [*временный контейнер* \ `migrate`, затем выход], name: <m>, fill: box-fill),
  node((2, 0), [*контейнер сайта*], name: <w>, fill: warm-fill),
  node((1, 1), [*том* \ #muted[данные базы]], name: <v>, stroke: (dash: "dashed")),
  e(<m>, <v>, "-|>", small[меняет структуру], label-side: right),
  e(<w>, <v>, "<|-|>", small[читает и пишет], label-side: left),
  e(<m>, <w>, "-|>", small[потом запускается]),
))

#text(size: 18pt)[
  - Сборка готовит *программу*, миграция меняет *конкретную базу*
  - Для рабочего сайта миграция --- управляемый шаг: проверка, резервная копия

  #key[Том --- не резервная копия: от случайного удаления данных он не защищает.]
]

== Сервис `migrate` в Compose <s-migrate-service>

#[
#show raw.where(block: true): set text(size: 13pt)
#grid(
  columns: (2.1fr, 1fr),
  column-gutter: 1.2em,
  align: horizon,
  ```yaml
  migrate:
    image: localhost/djdemo:latest
    command: ["python", "manage.py", "migrate", "--noinput"]
    depends_on:
      db:
        condition: service_healthy

  web:
    image: localhost/djdemo:latest
    depends_on:
      migrate:
        condition: service_completed_successfully
  ```,
  [
    - Тот же образ, другая команда
    - `migrate` ждёт `healthy` базы
    - `web` ждёт, пока `migrate` успешно завершится
  ],
)
]

#key[Миграции выполняются один раз за запуск, а не в каждой копии сайта.]

#muted[#podman-icon(1.1em) `podman-compose` 1.6.0 ждёт только остановки `migrate` и код выхода не проверяет: результат миграции проверяйте отдельно.]

= Логи

== Пишем в stdout <s-stdout>

Контейнер временный, а файл внутри него пропадёт вместе с ним.

```dockerfile
ENV PYTHONUNBUFFERED=1
CMD ["gunicorn", "config.wsgi:application", "--access-logfile=-", "--error-logfile=-"]
```

#terminal("captures/logs.txt", title: "podman logs", size: 12pt)

#key[Приложение пишет в поток, а хранит и ротирует среда запуска.]

== Где хранятся логи <s-log-storage>

#grid(
  columns: (1fr, 1fr),
  column-gutter: 1.5em,
  row-gutter: 0.6em,
  align: (left + horizon),
  [#podman-icon(1.5em) #h(0.3em) *Podman*], [#docker-icon(1.5em) #h(0.3em) *Docker*],
  grid.cell(align: top)[
    - Драйвер по умолчанию --- journald
    - Журнал занимает не больше 10% ФС и не больше 4 ГБ
    - Старые записи удаляются сами

    #key[Ротация из коробки.]
  ],
  grid.cell(align: top)[
    - Драйвер по умолчанию --- `json-file`
    - Ротации по умолчанию нет
    - Включается в `daemon.json`, только для новых контейнеров

    ```json
    "log-opts": { "max-size": "10m", "max-file": "3" }
    ```
  ],
)

#muted[Драйвер по умолчанию --- из `containers.conf(5)`, лимиты --- из `journald.conf(5)`. Из журнала логи забирают сборщики, например Fluent Bit.]

= Как контейнеры устроены внутри

== Слои <s-layers>

#align(center, block(width: 72%, stack(
  spacing: 5pt,
  layer(fill: warm-fill)[*Движок* --- Docker, Podman \ образы, сеть, тома],
  layer[*OCI-рантайм* --- `runc`, `crun` \ запускает процесс по стандарту OCI],
  layer[*Ядро Linux* \ namespaces --- изоляция #sym.dot.c cgroups --- лимиты ресурсов \ capabilities, seccomp --- урезанные права],
)))

#v(0.4em)
#key[В ядре нет понятия "контейнер": это обычный процесс, к которому применены эти ограничения.]

== Docker и Podman изнутри <s-engine-internals>

#let inner(body) = text(size: 0.6em, fill: luma(90), body)
#text(size: 17pt, align(center + horizon, diagram(
  spacing: (1.7em, 2.6em),
  node-shape: fletcher.shapes.rect,
  node-stroke: 1pt,
  node-corner-radius: 5pt,
  node-inset: 7pt,
  node((0, 0), docker-icon(1.5em), stroke: none),
  node((1, 0), [`docker`], name: <d1>),
  e(<d1>, <d2>, "-|>", small[REST]),
  node((2, 0), [*dockerd* \ #inner[демон: API, \ сборка BuildKit, \ сеть libnetwork]], name: <d2>, fill: box-fill),
  e(<d2>, <d3>, "-|>", small[gRPC]),
  node((3, 0), [containerd \ #inner[демон: образы, \ CRI для Kubernetes]], name: <d3>, fill: box-fill),
  e(<d3>, <d4>, "-|>"),
  node((4, 0), [`containerd-shim` \ #inner[на контейнер]], name: <d4>, fill: box-fill),
  e(<d4>, <d5>, "-|>", small[*OCI*]),
  node((5, 0), [`runc`], name: <d5>),
  e(<d5>, <d6>, "-|>"),
  node((6, 0), [контейнер], name: <d6>, fill: warm-fill),
  node((0, 1), podman-icon(1.9em), stroke: none),
  node((2, 1), [`podman` \ #inner[без демона: \ сборка Buildah, образы, \ сеть netavark, pasta]], name: <p1>, fill: box-fill),
  e(<p1>, <p2>, "-|>"),
  node((4, 1), [`conmon` \ #inner[на контейнер]], name: <p2>, fill: box-fill),
  e(<p2>, <p3>, "-|>", small[*OCI*]),
  node((5, 1), [`crun`], name: <p3>),
  e(<p3>, <p4>, "-|>"),
  node((6, 1), [контейнер], name: <p4>, fill: warm-fill),
  node(
    enclose: (<d5>, <p3>),
    stroke: (paint: accent, dash: "dashed"),
    inset: 9pt,
    corner-radius: 6pt,
  ),
  node((5, 1.45), text(fill: accent, size: 0.7em)[OCI-рантайм], stroke: none),
)))

#muted[*OCI* --- стандарт запуска: любой движок вызывает любой рантайм. *CRI* --- интерфейс Kubernetes, о нём дальше. Рантайм запускает процесс и выходит; сеть и образы --- забота движка.]

== Дерево процессов: без демона <s-process-tree>

#grid(
  columns: (1fr, 1fr),
  column-gutter: 1em,
  align: top,
  [
    #align(center)[#podman-icon(1.4em)]
    #terminal("captures/process-tree.txt", title: [ps #sym.dot.c Podman], size: 12pt)
  ],
  [
    #align(center)[#docker-icon(1.2em)]
    #terminal("mock/process-tree-docker.txt", title: [ps #sym.dot.c Docker], size: 12pt)
  ],
)

#text(size: 17pt)[
  - #podman-icon(1em) Упал или обновился `podman` --- контейнеры работают: у каждого свой `conmon`
  - #docker-icon(0.9em) Два демона всегда рядом; остановка `dockerd` по умолчанию останавливает все контейнеры #muted[(если не включён `live-restore`)]
  - *Rootless:* у Podman основной режим; у Docker --- отдельная установка, а демон по умолчанию работает от root
]

== systemd вместо демона <s-systemd>

#[
#set text(size: 19pt)
#grid(
  columns: (1fr, 1fr),
  column-gutter: 1.2em,
  align: horizon,
  [
    #icon("systemd-logo.svg", 1.3em) #h(0.3em) #text(size: 14pt)[`djdemo-web.container` --- Quadlet]
    #[
      #show raw.where(block: true): set text(size: 11.5pt)
      ```ini
      [Unit]
      Requires=djdemo-db.service
      After=djdemo-db.service

      [Container]
      Image=localhost/djdemo:latest
      PublishPort=127.0.0.1:8000:8000
      AutoUpdate=local

      [Service]
      Restart=always
      MemoryMax=512M

      [Install]
      WantedBy=default.target
      ```
    ]
  ],
  text(size: 17pt)[
    - Старт при загрузке --- `WantedBy`
    - Перезапуск --- `Restart`
    - Порядок со службами хоста --- `Requires`, `After`
    - Лимиты --- `MemoryMax`
    - Логи --- `journalctl -u`
    - Обновление образа --- `podman auto-update`
  ],
)

#key[У Docker всё это решает сам демон. У Podman --- systemd, как для любой службы.]
]

== Kubernetes и CRI <s-kubernetes-cri>

#align(center + horizon, diagram(
  spacing: (3.2em, 1.6em),
  node-stroke: 1pt,
  node-corner-radius: 5pt,
  node-inset: 10pt,
  node((0, 0.5), [*kubelet* \ #muted[агент на узле]], name: <k>, fill: warm-fill),
  e(<k>, <c1>, "-|>", small[CRI]),
  e(<k>, <c2>, "-|>", small[CRI], label-side: right),
  node((1, 0), [containerd], name: <c1>, fill: box-fill),
  node((1, 1), [CRI-O \ #muted[семейство Podman]], name: <c2>, fill: box-fill),
  e(<c1>, <r1>, "-|>"),
  e(<c2>, <r2>, "-|>"),
  node((2, 0), [`runc`], name: <r1>),
  node((2, 1), [`runc` / `crun`], name: <r2>),
))

- Kubernetes сам контейнеры не запускает, он командует CRI-рантаймом
- Docker из этой цепочки убран в Kubernetes 1.24

#key[Формат образов общий: собранное Docker или Podman запускается везде.]

= Podman и Docker: итог

== Podman против Docker <s-podman-vs-docker>

#text(size: 18pt, table(
  columns: (auto, 1fr, 1fr),
  inset: 6pt,
  stroke: 0.5pt + luma(180),
  table.header([], podman-logo(1.3em), docker-logo(1.1em)),
  [Архитектура], [Без демона], [Клиент и демон `dockerd`],
  [Rootless], [Основной режим, работает сразу], [Отдельная установка, по умолчанию демон от root],
  [Реакция на `unhealthy`], [Сам: `--health-on-failure`], [Нужен внешний инструмент],
  [Логи по умолчанию], [journald, ротация из коробки], [`json-file`, без ротации],
  [Служба на сервере], [Quadlet и systemd], [Демон и `restart`],
  [Compose], [`podman-compose` или Docker Compose через сокет], [Docker Compose],
))

#text(size: 19pt, key[#podman-icon(1.2em) *Без демона, без root, в связке с systemd* --- и с теми же образами, что у Docker и Kubernetes.])

= Пример: Django в контейнере

== Минимальный проект <s-minimal-project>

#grid(
  columns: (1fr, 1fr),
  column-gutter: 2em,
  [
    ```
    django-demo/
    ├── manage.py
    ├── config/
    ├── tasks/
    │   ├── models.py
    │   ├── views.py
    │   ├── templates/
    │   └── migrations/
    ├── requirements.txt
    ├── Containerfile
    └── .dockerignore
    ```
  ],
  [
    - Список задач на Django 5.2
    - База SQLite: один файл, без отдельного сервера
    - Один контейнер и один том
    - Миграции готовы *до* сборки образа

    #v(0.6em)
    #image("img/sqlite-logo.svg", height: 2.4em)
  ],
)

== Containerfile <s-ex-containerfile>

```dockerfile
FROM docker.io/library/python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]
```

- Сначала зависимости, потом код: правка кода не сбрасывает кеш установки
- `RUN` выполняется при *сборке*, `CMD` --- при *запуске* контейнера
- `0.0.0.0` --- слушать внутри контейнера, сам порт ещё не опубликован

== Сборка и миграция <s-ex-build-migrate>

#terminal("captures/ex-build.txt", title: [podman #sym.dot.c django-demo], size: 13pt)
#v(-0.4em)
#terminal("captures/ex-migrate.txt", title: "migrate", size: 13pt)

#muted[Команда после имени образа заменяет `CMD`. Снято на Podman, команды те же, что у Docker.]

== Запуск, страница и перезапуск <s-ex-run>

#terminal("captures/ex-run.txt", title: [podman #sym.dot.c django-demo], size: 11.5pt)
#v(-0.3em)
#terminal("captures/ex-persist.txt", title: "после остановки и нового запуска", size: 11.5pt)

#text(size: 17pt)[
  - Сначала список пуст, после `exec` в контейнере появилась задача
  - Порт опубликован только на `127.0.0.1`
]

#text(size: 18pt, key[Контейнер новый, а задача на месте: база лежит в томе `django_data`.])

== Итоги <s-summary>

#align(center, diagram(
  spacing: (2.2em, 1em),
  node-stroke: 1pt,
  node-corner-radius: 5pt,
  node-inset: 9pt,
  node((0, 0), small[Containerfile], name: <a>),
  e(<a>, <b>, "-|>"),
  node((1, 0), small[образ], name: <b>, fill: box-fill),
  e(<b>, <c>, "-|>"),
  node((2, 0), small[контейнер], name: <c>, fill: warm-fill),
  e(<c>, <d>, "<|-|>"),
  node((3, 0), small[том], name: <d>, stroke: (dash: "dashed")),
  e(<d>, <m>, "<|-", small[миграции]),
  node((4, 0), small[Django], name: <m>),
))

#v(0.3em)
#set text(size: 19pt)
- Собирайте образ в несколько этапов
- Описывайте запуск в Compose, секреты держите вне образа
- Отличайте `running` от `healthy`: Docker сам не перезапустит
- Миграции --- отдельный шаг, а не часть сборки
- Логи --- в stdout, ротацию настройте
- На Podman помните про формат образа
- Учебный запуск --- не продакшен: нужны сервер приложения, отключённая отладка, защищённые секреты

== Источники <no-cue>

#text(size: 13pt, grid(
  columns: (1fr, 1.15fr, 1fr),
  column-gutter: 1.2em,
  align: top,
  [
    - #link("https://docs.docker.com/get-started/docker-overview/")[Docker overview]
    - #link("https://docs.docker.com/get-started/docker-concepts/the-basics/what-is-a-container/")[What is a container]
    - #link("https://docs.docker.com/reference/dockerfile/")[Dockerfile reference]
    - #link("https://docs.docker.com/build/concepts/context/")[Build context]
    - #link("https://docs.docker.com/reference/cli/docker/buildx/build/")[Docker build]
    - #link("https://docs.docker.com/reference/cli/docker/container/run/")[Docker run]
    - #link("https://docs.docker.com/engine/storage/volumes/")[Docker volumes]
    - #link("https://docs.docker.com/engine/logging/drivers/json-file/")[Docker: JSON File logging driver]
    - #link("https://docs.docker.com/engine/logging/configure.md")[Docker: Configure logging drivers]
    - #link("https://docs.docker.com/engine/security/rootless/")[Docker: Rootless mode]
    - #link("https://docs.docker.com/engine/swarm/how-swarm-mode-works/services/")[Docker: How services work (Swarm)]
  ],
  [
    - #link("https://docs.djangoproject.com/en/5.2/topics/migrations/")[Django: Migrations]
    - #link("https://docs.djangoproject.com/en/5.2/intro/tutorial01/")[Django tutorial, part 1]
    - #link("https://docs.djangoproject.com/en/5.2/intro/tutorial02/")[Django tutorial, part 2]
    - #link("https://docs.djangoproject.com/en/5.2/ref/django-admin/")[Django: django-admin и manage.py]
    - #link("https://docs.djangoproject.com/en/5.2/howto/deployment/checklist/")[Django: Deployment checklist]
    - #link("https://docs.djangoproject.com/en/5.2/releases/5.2.8/")[Django 5.2.8 release notes]
    - #link("https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/")[Kubernetes: Liveness, Readiness and Startup Probes]
    - #link("https://kubernetes.io/docs/reference/using-api/health-checks/")[Kubernetes API health endpoints]
    - #link("https://docs.podman.io/en/latest/markdown/podman-run.1.html")[Podman: podman-run]
    - #link("https://docs.podman.io/en/latest/markdown/podman-container.unit.5.html")[Podman: podman-container.unit]
    - #link("https://github.com/containers/podman/discussions/20218")[Podman Discussion \#20218: Quadlet]
    - #link("https://github.com/containers/buildah/pull/3540")[Buildah PR \#3540: Healthcheck и OCI]
    - #link("https://docs.redhat.com/ko/documentation/red_hat_enterprise_linux/10/html/building_running_and_managing_containers/performing-a-health-check-using-a-containerfile")[Red Hat: health check через Containerfile]
    - #link("https://github.com/containers/podman-compose/blob/v1.6.0/podman_compose.py")[podman-compose 1.6.0: исходный код]
    - #link("https://livebook.manning.com/learn/concepts/podman-system-service--api-element/podman-in-action")[Podman in Action: system service и Docker API]
  ],
  [
    - #link("https://github.com/containers/common/blob/main/docs/containers.conf.5.md")[containers.conf(5)]
    - #link("https://www.freedesktop.org/software/systemd/man/latest/journald.conf.html")[journald.conf(5)]
    - #link("https://docs.fluentbit.io/manual/data-pipeline/inputs/systemd")[Fluent Bit: Systemd input]
    - #link("https://opencontainers.org/about/overview/")[About the Open Container Initiative]
    - #link("https://www.docker.com/blog/demystifying-open-container-initiative-oci-specifications/")[Docker: Demystifying the OCI Specifications]
    - #link("https://www.docker.com/blog/containerd-vs-docker/")[Docker: containerd vs. Docker]
    - #link("https://github.com/opencontainers/runc")[runc] и #link("https://github.com/containers/crun")[crun]
    - #link("https://cri-o.io/")[CRI-O]
    - #link("https://www.cncf.io/projects/containerd/")[CNCF: containerd]
    - #link("https://kubernetes.io/docs/concepts/containers/cri/")[Kubernetes: CRI]
    - #link("https://kubernetes.io/docs/setup/production-environment/container-runtimes/")[Kubernetes: Container Runtimes]
    - #link("https://kubernetes.io/blog/2022/02/17/dockershim-faq/")[Kubernetes: Dockershim Removal FAQ]
  ],
))

#v(0.4em)
#text(size: 10pt, fill: luma(110))[
  Весь вывод на слайдах снят на Podman 6.1.4 и podman-compose 1.6.0. Изображения с Wikimedia Commons: фото контейнеровоза --- Trougnouf, #link("https://creativecommons.org/licenses/by/4.0/")[CC BY 4.0], уменьшено, на последнем слайде кадрировано; логотип Git --- Jason Long, #link("https://creativecommons.org/licenses/by/3.0/")[CC BY 3.0]\; логотипы SQLite и systemd --- общественное достояние; логотип Podman --- The Podman Authors, #link("https://www.apache.org/licenses/LICENSE-2.0")[Apache 2.0], значок обрезан из полного логотипа\; логотип Docker (вариант 2013 года) --- dotCloud, Inc., #link("https://www.apache.org/licenses/LICENSE-2.0")[Apache 2.0], значок обрезан из полного логотипа. Логотипы являются товарными знаками своих владельцев. Исходники доклада: #link("https://github.com/comfydv/ssu-se-2026-27-bkd-project")[github.com/comfydv/ssu-se-2026-27-bkd-project].
]


#focus-slide[
  #show underline: it => it.body
  #grid(
    columns: (auto, auto),
    column-gutter: 2em,
    align: horizon,
    move(dx: 0.8cm, cat),
    text(size: 1.4em)[Спасибо \ за внимание!],
  )
  #place(top + left, dx: -0.6cm, dy: -0.8cm, sticker(logo("img/podman-icon.svg", k: 100%), size: 3cm, angle: -14deg))
  #place(top + right, dx: -3.2cm, dy: -1cm,
    sticker(photo("img/container-ship.jpg"), size: 3.3cm, angle: 9deg))
  #place(bottom + right, dx: 0.4cm, dy: -1.4cm, sticker(logo("img/systemd-logo.svg", k: 95%), size: 3cm, angle: -7deg))
  #place(bottom + left, dx: -1cm, dy: -1.6cm, sticker(logo("img/docker-icon.svg"), size: 2.8cm))
  #place(bottom + center, dy: 0.2em, text(size: 18pt, fill: luma(185))[
    Сделано на #link("https://typst.app", text(fill: rgb("#3fc1d0"))[Typst]) #sys.version, современной альтернативе #LaTeX,
    с пакетами #link("https://typst.app/universe/package/touying", text(fill: rgb("#3fc1d0"))[Touying]) и #link("https://typst.app/universe/package/fletcher", text(fill: rgb("#3fc1d0"))[fletcher]) \
    #text(size: 11pt)[Фото: Trougnouf, CC BY 4.0, уменьшено и кадрировано --- Wikimedia Commons]
  ])
  #metadata(none) <deck-end>
]
