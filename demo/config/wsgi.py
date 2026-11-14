# SPDX-FileCopyrightText: Django Software Foundation and individual contributors
#
# SPDX-License-Identifier: BSD-3-Clause

import os

from django.core.wsgi import get_wsgi_application

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
application = get_wsgi_application()
