#!/bin/sh

# SPDX-FileCopyrightText: 2026 comfydv
#
# SPDX-License-Identifier: GPL-3.0-or-later

set -eu

# Convenient for a single replica, unsafe for several: see compose.yaml for the `migrate` job.
if [ "${DJANGO_MIGRATE_ON_START:-0}" = "1" ]; then
    python manage.py migrate --noinput
fi

# exec replaces this shell, so the server becomes PID 1 and receives SIGTERM itself.
exec "$@"
