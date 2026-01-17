#!/bin/sh
set -e

NEW_UID=${UID:-1000}
NEW_GID=${GID:-1000}

groupmod -g "$NEW_GID" appgroup > /dev/null
usermod -u "$NEW_UID" appuser > /dev/null

chown -R appuser:appgroup /data
chown -R appuser:appgroup /home/appuser

exec gosu appuser "$@"
