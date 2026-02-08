# VPS Stack (Nginx + V2Ray + Certbot)

This repo provisions a small VPS stack with:

- `nginx` serving static content from `./html` and proxying a VLESS-over-WebSocket endpoint.
- `v2ray` (v2fly-core) providing the VLESS inbound.
- `certbot` handling Let's Encrypt HTTP-01 issuance and renewal.

It is intended to be started via `./start.sh`, which renders templates, initializes TLS (if needed), and boots the stack.

## Quick Start

1. Create `.env` from the example:

```bash
cp .env.example .env
```

2. Fill in values in `.env`:

- `DOMAIN` - your public domain (A/AAAA record must point to this VPS).
- `LE_EMAIL` - email for Let's Encrypt.
- `VLESS_UUID` - client UUID for VLESS (see below for how to generate).
- `VLESS_PATH` - websocket path (default in `.env.example`).
- `V2RAY_PORT` - internal v2ray port (default in `.env.example`).

3. Start the stack:

```bash
./start.sh
```

The script will:

- Render `./v2ray/config.json` from `./v2ray/config.json.template`.
- Render `./clash/clash.yaml` from `./clash/clash.yaml.template`.
- If a cert already exists in `./certs/live/$DOMAIN`, it will start the full stack.
- Otherwise, it will start a temporary HTTP-only nginx config, request the cert, then switch to the full TLS config.

## Services

- `nginx` (container `nginx-blog`)
  - Ports: `80`, `443`.
  - Serves static files from `./html`.
  - Terminates TLS using certificates in `./certs`.
  - Proxies `VLESS_PATH` to `v2ray` on `V2RAY_PORT`.

- `v2ray` (container `v2ray`)
  - VLESS inbound over WebSocket with path `VLESS_PATH`.
  - Config rendered to `./v2ray/config.json`.

- `certbot` (container `certbot`)
  - Performs `certbot renew` every 12 hours and reloads nginx after renewal.

- `certbot-init` (profile `init`)
  - Runs one-time issuance when no cert exists yet.

## Files and Templates

- `docker-compose.yml` - core stack definition.
- `start.sh` - bootstrap script.
- `nginx/site.acme.conf.template` - HTTP-only nginx used for ACME issuance.
- `nginx/site.full.conf.template` - full TLS + proxy configuration.
- `v2ray/config.json.template` - V2Ray config template.
- `clash/clash.yaml.template` - Clash client config template output.

## Requirements

- A domain name you control, with A/AAAA records pointing to this VPS public IP.
- Ports `80` and `443` open to the internet for HTTP-01 issuance and HTTPS traffic.
- Docker and Docker Compose installed on the VPS.

## Generate VLESS_UUID

You need a UUID for VLESS clients. Any RFC4122 UUID is fine.

Common options:

```bash
# Linux/macOS (uuidgen is commonly available)
uuidgen

# Python (if uuidgen is missing)
python - << 'PY'
import uuid
print(uuid.uuid4())
PY
```

Copy the UUID into `VLESS_UUID` in `.env`.

## Using clash.yaml

`./start.sh` renders a ready-to-import Clash config at `./clash/clash.yaml`.

What it contains:

- A single VLESS-over-WebSocket proxy pointed at `https://$DOMAIN` and `VLESS_PATH`.
- TLS enabled, matching the server config.

How to use it:

1. Run `./start.sh` to generate `./clash/clash.yaml`.
1. Download `./clash/clash.yaml` to your client device.
1. In Clash, import the file as a profile and enable it.

If you change `DOMAIN`, `VLESS_UUID`, or `VLESS_PATH`, re-run `./start.sh` to re-render `./clash/clash.yaml`.

## Notes

- `start.sh` uses `sudo docker compose`, so run it as a user with sudo privileges.
- Ensure your DNS is set before running the initial certificate issuance.
- The websocket endpoint is only exposed on `https://$DOMAIN$VLESS_PATH` after TLS is active.
