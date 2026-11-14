#!/bin/bash

# SPDX-FileCopyrightText: 2026 comfydv
#
# SPDX-License-Identifier: GPL-3.0-or-later

# Records the terminal output shown on the slides into talk/captures/.
# Needs demo/.env. Recreates the demo containers and volumes.

set -u
cd "$(dirname "$0")/../.." || exit 1
C=$PWD/talk/captures

# cap FILE 'CMD': append "$ CMD" and its output to FILE, as it would look in a terminal.
cap() { local file=$1; shift; { printf '$ %s\n' "$*"; eval "$*" 2>&1; } >> "$C/$file"; }
# quiet 'CMD': a preparation step whose output is not shown on the slides.
quiet() { eval "$*" > /dev/null 2>&1; }
clear_caps() { local f; for f; do : > "$C/$f.txt"; done; }
die() { echo "capture.sh: $*" >&2; exit 1; }
build() { podman build -q --format docker "$@" > /dev/null || die "build failed: podman build $*"; }

section_images() (
    cd demo || exit 1
    # Docker format keeps HEALTHCHECK in the image; the OCI variant is recorded in `demo`.
    build -f Containerfile -t localhost/djdemo:multi -t localhost/djdemo:latest .
    build -f Containerfile.naive -t localhost/djdemo:naive .

    clear_caps images
    cap images.txt 'podman images --format "table {{.Repository}}:{{.Tag}}\t{{.Size}}" | rg "TAG|djdemo:(naive|multi)"'
    cap images.txt 'podman run --rm --entrypoint sh localhost/djdemo:naive -c "command -v gcc"'
    cap images.txt 'podman run --rm --entrypoint sh localhost/djdemo:multi -c "command -v gcc || echo no gcc"'
)

section_demo() (
    cd demo || exit 1
    [ -f .env ] || die "demo/.env is missing: copy demo/.env.example and fill it in"
    for tag in latest naive; do
        podman image exists "localhost/djdemo:$tag" || die "localhost/djdemo:$tag is missing: run the images section first"
    done
    clear_caps compose-up curl-counter persist logs process-tree db-failure db-failure-timing \
        oci health-on-failure pid1 stop-time migrate-on-start

    quiet podman-compose down -v
    quiet podman-compose up -d
    quiet podman wait --condition=healthy djdemo_web_1
    cap compose-up.txt 'podman-compose ps --format "table {{.Names}}\t{{.Status}}"'
    for _ in 1 2 3; do cap curl-counter.txt 'curl -s http://127.0.0.1:8000/; echo'; done
    cap persist.txt 'podman-compose down > /dev/null 2>&1'
    cap persist.txt 'podman-compose up -d > /dev/null 2>&1'
    quiet podman wait --condition=healthy djdemo_web_1
    cap persist.txt 'curl -s http://127.0.0.1:8000/; echo'

    # Two more visits, so the tail has application lines next to access lines.
    quiet 'curl -s http://127.0.0.1:8000/'
    quiet 'curl -s http://127.0.0.1:8000/'
    cap logs.txt 'podman logs djdemo_web_1 2>&1 | rg -v readyz | tail -n 4'

    local web conmon parent
    web=$(podman inspect --format '{{.State.Pid}}' djdemo_web_1)
    conmon=$(podman inspect --format '{{.State.ConmonPid}}' djdemo_web_1)
    parent=$(ps -o ppid= -p "$conmon" | tr -d ' ')
    cap process-tree.txt "ps -o pid,ppid,comm -p $parent,$conmon,$web"
    cap process-tree.txt 'pgrep -a dockerd || echo "no dockerd"'

    cap db-failure.txt 'podman-compose stop db > /dev/null 2>&1'
    cap db-failure.txt 'curl -s -w " %{http_code}\n" http://127.0.0.1:8000/healthz'
    cap db-failure.txt 'curl -s -w " %{http_code}\n" http://127.0.0.1:8000/readyz'
    local start
    start=$(date +%s)
    quiet podman wait --condition=unhealthy djdemo_web_1
    echo "unhealthy after $(( $(date +%s) - start ))s" > "$C/db-failure-timing.txt"
    cap db-failure.txt 'podman-compose ps --format "table {{.Names}}\t{{.Status}}"'
    cap db-failure.txt 'podman inspect --format "{{.RestartCount}}" djdemo_web_1'
    quiet podman-compose start db
    quiet podman wait --condition=healthy djdemo_web_1

    cap oci.txt 'podman build --no-cache -t localhost/djdemo:oci . 2>&1 | rg -m1 -o "HEALTHCHECK is not supported.*format"'
    cap oci.txt 'podman image inspect --format "{{if .HealthCheck}}healthcheck: yes{{else}}healthcheck: no{{end}}" localhost/djdemo:oci'
    cap oci.txt 'podman image inspect --format "{{if .HealthCheck}}healthcheck: yes{{else}}healthcheck: no{{end}}" localhost/djdemo:multi'

    quiet podman rm -f hof-demo
    cap health-on-failure.txt 'podman run -d --name hof-demo --health-cmd false --health-interval 2s --health-retries 1 --health-on-failure restart docker.io/library/python:3.13-slim-trixie sleep infinity > /dev/null'
    sleep 12  # let a few checks fail and restarts happen
    cap health-on-failure.txt 'podman events --since 1m --stream=false --filter container=hof-demo --format "{{.Status}} {{.HealthStatus}}" | rg -v "^(exec|exec_died|cleanup|init|died) " | head -n 8'
    cap health-on-failure.txt 'podman inspect --format "{{.RestartCount}}" hof-demo'
    quiet podman rm -f hof-demo

    quiet podman rm -f stop-multi stop-naive
    quiet podman run -d --name stop-multi --network djdemo_default --env-file .env localhost/djdemo:latest
    quiet podman run -d --name stop-naive --network djdemo_default --env-file .env localhost/djdemo:naive
    quiet 'timeout 60 podman logs -f stop-multi 2>&1 | rg -m1 -q "Booting worker"'
    quiet 'timeout 60 podman logs -f stop-naive 2>&1 | rg -m1 -q "Booting worker"'
    cap pid1.txt 'podman top stop-multi pid comm | head -n 2'
    cap pid1.txt 'podman top stop-naive pid comm | head -n 3'
    TIMEFORMAT='real %1Rs'
    cap stop-time.txt 'time podman stop stop-multi > /dev/null'
    cap stop-time.txt 'time podman stop stop-naive > /dev/null'
    cap stop-time.txt 'podman inspect --format "{{.State.ExitCode}}" stop-multi stop-naive'
    quiet podman rm -f stop-multi stop-naive
    cap migrate-on-start.txt 'podman run --rm --network djdemo_default --env-file .env -e DJANGO_MIGRATE_ON_START=1 localhost/djdemo:latest echo "server would start here"'

    quiet podman-compose down
)

section_django_demo() (
    cd django-demo || exit 1
    page='curl -s http://127.0.0.1:8000/ | tr -s " \n" " " | rg -o "<li>[^<]*</li>"'
    clear_caps ex-build ex-migrate ex-run ex-persist
    quiet podman rm -f django_site
    quiet podman volume rm django_data

    cap ex-build.txt 'podman build -t django-demo:1 . | tail -n 1'
    cap ex-build.txt 'podman volume create django_data'
    cap ex-migrate.txt 'podman run --rm -v django_data:/data django-demo:1 python manage.py migrate | rg "Apply all|Running|tasks"'

    cap ex-run.txt 'podman run -d --rm --name django_site -p 127.0.0.1:8000:8000 -v django_data:/data django-demo:1 > /dev/null'
    quiet 'timeout 60 podman logs -f django_site 2>&1 | rg -m1 -q "Quit the server"'
    cap ex-run.txt "$page"
    cap ex-run.txt "podman exec django_site python manage.py shell -c \"from tasks.models import Task; Task.objects.create(title='Docker')\" > /dev/null"
    cap ex-run.txt "$page"

    cap ex-persist.txt 'podman stop django_site > /dev/null'
    cap ex-persist.txt 'podman run -d --rm --name django_site -p 127.0.0.1:8000:8000 -v django_data:/data django-demo:1 > /dev/null'
    quiet 'timeout 60 podman logs -f django_site 2>&1 | rg -m1 -q "Quit the server"'
    cap ex-persist.txt "$page"
    quiet podman stop django_site
)

[ $# -gt 0 ] || set -- images demo django-demo
for section; do
    case $section in
        images|demo|django-demo) "section_${section//-/_}" || exit 1 ;;
        *) die "unknown section: $section (expected images, demo or django-demo)" ;;
    esac
    echo "$section: done"
done
