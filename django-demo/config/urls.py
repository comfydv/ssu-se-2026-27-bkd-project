# SPDX-FileCopyrightText: 2026 comfydv
#
# SPDX-License-Identifier: GPL-3.0-or-later

from django.urls import path
from tasks.views import index

urlpatterns = [path("", index)]
