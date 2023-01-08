#!/bin/bash
set -e
/app/caddy start --config /data/Caddyfile

tail -f /data/Caddyfile