#!/usr/bin/env python

# SPDX-FileCopyrightText: Django Software Foundation and individual contributors
#
# SPDX-License-Identifier: BSD-3-Clause

import os
import sys

from django.core.management import execute_from_command_line

os.environ.setdefault("DJANGO_SETTINGS_MODULE", "config.settings")
execute_from_command_line(sys.argv)
