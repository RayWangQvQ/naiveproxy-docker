#!/bin/bash
set -e

/app/caddy fmt --overwrite /data/Caddyfile
/app/caddy start --config /data/Caddyfile

tail -f /data/Caddyfile