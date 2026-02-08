#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"

# load env
if [ -f ".env" ]; then
  set -a
  source .env
  set +a
fi

: "${DOMAIN:?DOMAIN is required in .env}"
: "${LE_EMAIL:?LE_EMAIL is required in .env}"
: "${V2RAY_PORT:?V2RAY_PORT is required in .env}"
: "${VLESS_UUID:?VLESS_UUID is required in .env}"
: "${VLESS_PATH:?VLESS_PATH is required in .env}"

DC="sudo docker compose"

CERT_DIR="./certs/live/${DOMAIN}"
FULLCHAIN="${CERT_DIR}/fullchain.pem"
PRIVKEY="${CERT_DIR}/privkey.pem"

ACME_TEMPLATE="./nginx/site.acme.conf.template"
FULL_TEMPLATE="./nginx/site.full.conf.template"
ACTIVE_TEMPLATE="./nginx/site.conf.template"

# ensure dirs
sudo mkdir -p ./certbot/www
sudo chown -R "$(id -u)":"$(id -g)" ./certbot || true

# render v2ray config on host
envsubst '$V2RAY_PORT $VLESS_UUID $VLESS_PATH' \
  < ./v2ray/config.json.template \
  > ./v2ray/config.json

# render clash config on host
envsubst '$DOMAIN $VLESS_UUID $VLESS_PATH' \
  < ./clash/clash.yaml.template \
  > ./clash/clash.yaml

# already have cert -> full stack
if [ -f "$FULLCHAIN" ] && [ -f "$PRIVKEY" ]; then
  cp -f "$FULL_TEMPLATE" "$ACTIVE_TEMPLATE"
  $DC up -d --force-recreate
  exit 0
fi

# no cert -> ACME first (only nginx)
cp -f "$ACME_TEMPLATE" "$ACTIVE_TEMPLATE"
$DC up -d --force-recreate nginx

$DC --profile init run --rm certbot-init certonly \
  --webroot -w /var/www/certbot \
  -d "$DOMAIN" \
  --email "$LE_EMAIL" --agree-tos --no-eff-email

# switch to full
cp -f "$FULL_TEMPLATE" "$ACTIVE_TEMPLATE"
$DC up -d --force-recreate
