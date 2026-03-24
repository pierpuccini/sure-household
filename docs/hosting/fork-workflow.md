# Sure Household Fork Workflow

This fork is meant to stay close to upstream `we-promise/sure` while layering household-specific changes on top.

## Local repo setup

```sh
git clone git@github.com:<your-user>/<your-private-fork>.git sure-household.nosync
cd sure-household.nosync
git remote add upstream https://github.com/we-promise/sure.git
git fetch upstream
git checkout -b codex/sure-v1 upstream/main
```

## Local self-hosted deployment on the always-on Mac

1. Copy `compose.example.yml` to `compose.yml`.
2. Configure environment values in `.env.local`.
3. Start the app:

```sh
docker compose up -d
```

4. Expose it on your LAN with the Mac's stable hostname or local IP.

## Updating after a push

```sh
git fetch origin
git pull --rebase origin codex/sure-v1
docker compose build
docker compose up --no-deps -d web worker
```

## Later private remote access

- Preferred first step: Tailscale or Cloudflare Tunnel
- Keep direct public exposure out of scope until the fork is stable
