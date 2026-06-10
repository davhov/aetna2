#!/usr/bin/env bash
set -euo pipefail

: "${DEFAULT_WORKSPACE:=/home/jovyan}"
: "${APP_USER:=ubuntu}"

mkdir -p /run/sshd "$DEFAULT_WORKSPACE"
chown -R "${APP_USER}:${APP_USER}" /home/jovyan || true

if [ -n "${ROOT_PASSWORD:-}" ]; then
  echo "root:${ROOT_PASSWORD}" | chpasswd
fi

/usr/sbin/sshd

exec sudo -E -H -u "$APP_USER" code-server \
  --bind-addr 0.0.0.0:8888 \
  --auth none \
  "$DEFAULT_WORKSPACE"
