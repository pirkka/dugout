# Dugout

A Blood Bowl 3 team manager — syncs league and team data from the Cyanide BB3 API.

## Ruby version

3.3.2

## Setup

```sh
bundle install
bin/rails db:create db:migrate db:seed
```

### Cyanide API key

The BB3 API key is stored in Rails encrypted credentials:

```sh
bin/rails credentials:edit
```

Key: `cyanide_api_key`

## Test suite

```sh
bin/rails test
```

## Cyanide API sync

Refresh a league's data from the Cyanide BB3 API:

```sh
bin/rails leagues:refresh[id]
```

Refresh all leagues:

```sh
bin/rails leagues:refresh_all
```

Raw API responses are stored in `leagues.api_data` (json column) for debugging.

## Deployment

Deployed to a Hetzner VPS (89.167.108.217) via Kamal using Docker containers on `dugout.odj.fi`.

```sh
bin/kamal deploy
```

### Kamal secrets

- `KAMAL_REGISTRY_PASSWORD` — GitHub PAT with `packages:write` scope for ghcr.io
- Stored in `.kamal/secrets` (gitignored)

### SSL / Cloudflare

Traffic flows through Cloudflare (proxied) with Automatic SSL. The origin server listens on HTTP only — kamal-proxy has `ssl_redirect: false` and `forward_headers: true` so Cloudflare handles HTTPS termination correctly.
