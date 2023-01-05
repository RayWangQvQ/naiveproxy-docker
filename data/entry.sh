#!/bin/bash
set -e
/go/caddy start --config /data/Caddyfile

tail -f tail -f /dev/null