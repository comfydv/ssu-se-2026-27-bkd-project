# SPDX-FileCopyrightText: 2026 comfydv
#
# SPDX-License-Identifier: GPL-3.0-or-later

import logging
import socket

from django.db import connection
from django.http import JsonResponse

from .models import Visit

logger = logging.getLogger(__name__)


def index(request):
    Visit.objects.create()
    visits = Visit.objects.count()
    logger.info("visit recorded, total=%d", visits)
    return JsonResponse({"visits": visits, "container": socket.gethostname()})


def healthz(request):
    """Liveness: the process answers. Never touches the database."""
    return JsonResponse({"status": "ok"})


def readyz(request):
    """Readiness: the process can actually serve requests."""
    try:
        with connection.cursor() as cursor:
            cursor.execute("SELECT 1")
    except Exception:
        logger.exception("readiness check failed")
        return JsonResponse({"status": "unavailable"}, status=503)
    return JsonResponse({"status": "ok"})
