# SPDX-FileCopyrightText: 2026 comfydv
#
# SPDX-License-Identifier: GPL-3.0-or-later

from django.db import models


class Visit(models.Model):
    created_at = models.DateTimeField(auto_now_add=True)
