# SPDX-FileCopyrightText: Django Software Foundation and individual contributors
#
# SPDX-License-Identifier: BSD-3-Clause

"""ASGI config for the teaching example."""
import os

from django.core.asgi import get_asgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")

application = get_asgi_application()
