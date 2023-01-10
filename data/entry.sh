#!/bin/bash
set -e

echo "Formate the Caddyfile"
/app/caddy fmt --overwrite /data/Caddyfile

echo "Start server"
/app/caddy start --config /data/Caddyfile

tail -f -n 50 /data/Caddyfile