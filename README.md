<!--
SPDX-FileCopyrightText: 2026 comfydv

SPDX-License-Identifier: CC-BY-SA-4.0
-->

# Контейнеризация Django

Доклад "Контейнеризация Django-приложений: Docker, Compose, многоступенчатые сборки, healthcheck и миграции при старте" и примеры к нему.

| Каталог | Что внутри |
|---|---|
| `talk/` | Слайды (`slides.typ`) и текст выступления (`speech.typ`) на [Typst](https://typst.app); `talk.typ` собирает оба PDF |
| `talk/captures/` | Вывод команд, снятый на Podman 6.1.4 и podman-compose 1.6.0; слайды читают его как есть |
| `talk/tools/` | `capture.sh` заново снимает `talk/captures/` |
| `demo/` | Django + PostgreSQL: многоступенчатый Containerfile, `compose.yaml`, entrypoint, Quadlet-файл |
| `django-demo/` | Минимальный проект на Django + SQLite из последнего раздела |

## Сборка

Нужен Typst 0.15 или новее:

```sh
cd talk
typst compile --features bundle --format bundle talk.typ out
```

Получаются `out/slides.pdf` и `out/speech.pdf`. Оба документа собираются за одну компиляцию (экспериментальный режим [bundle](https://typst.app/docs/reference/bundle/)): метки смены слайдов в речи (`#cue(<s-...>)`) ссылаются на метки заголовков в `slides.typ` и сами подставляют номер слайда. Если у слайда нет метки в речи или метка указывает в никуда, сборка падает. Слайды можно собрать и отдельно, `typst compile slides.typ`; речь - только вместе со слайдами.

## Лицензии

Проект соответствует спецификации [REUSE](https://reuse.software): лицензия и авторы указаны в заголовке каждого файла, а для файлов, куда заголовок не вставить, - в `REUSE.toml`. Тексты лицензий лежат в `LICENSES/`.

- Код (`demo/`, `django-demo/`, `talk/tools/`) - GPL-3.0-or-later.
- Оформление слайдов и речи (`talk/*-lib.typ`) - MPL-2.0: копилефт на уровне файла, поэтому библиотеку можно подключать из текстов под CC BY-SA.
- Файлы, созданные `django-admin startproject` / `startapp` и оставленные почти без изменений (`manage.py`, `wsgi.py`, `asgi.py`, `apps.py`, `admin.py`), - BSD-3-Clause, (c) Django Software Foundation, как и шаблоны, из которых они получены. `django-demo/config/settings.py` - шаблон Django с нашими правками: BSD-3-Clause и GPL-3.0-or-later.
- Тривиальные и сгенерированные файлы (`requirements.txt`, `.gitignore`, `.dockerignore`, `.env.example`, `__init__.py`, миграции Django) - CC0 1.0: творческого вклада в них нет.
- Текст доклада и слайдов (`talk/slides.typ`, `talk/speech.typ`, PDF) - CC BY-SA 4.0.
- Снятый вывод команд (`talk/captures/`, `talk/mock/`) - CC0 1.0.
- Изображения принадлежат своим авторам, лицензии указаны в `REUSE.toml`. Логотипы - товарные знаки своих владельцев.

Проверка: `reuse lint`.
