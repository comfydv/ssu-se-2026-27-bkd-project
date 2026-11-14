# SPDX-FileCopyrightText: 2026 comfydv
#
# SPDX-License-Identifier: GPL-3.0-or-later

from django.urls import path

from notes import views

urlpatterns = [
    path("", views.index),
    path("healthz", views.healthz),
    path("readyz", views.readyz),
]
