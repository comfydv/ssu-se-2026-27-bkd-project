# SPDX-FileCopyrightText: 2026 comfydv
#
# SPDX-License-Identifier: GPL-3.0-or-later

from django.shortcuts import render
from .models import Task

def index(request):
    return render(request, "tasks/index.html", {
        "tasks": Task.objects.order_by("id")
    })
