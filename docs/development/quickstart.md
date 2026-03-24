# Development Quickstart

Use this if you want the shortest possible set of commands for local development.

## Start dev mode

```sh
cd /Users/ppuccinir/Documents/Development/sure-household.nosync
docker-compose down
docker-compose -f compose.yml -f compose.dev.yml build
docker-compose -f compose.yml -f compose.dev.yml run --rm web bin/rails db:prepare
bin/dev-docker
```

Then open:

- `http://localhost:3000`

## Stop dev mode

```sh
cd /Users/ppuccinir/Documents/Development/sure-household.nosync
docker-compose -f compose.yml -f compose.dev.yml down
```

## Quick restart

```sh
cd /Users/ppuccinir/Documents/Development/sure-household.nosync
docker-compose -f compose.yml -f compose.dev.yml down
bin/dev-docker
```

## Rebuild after dependency changes

Use this when `Gemfile`, `Gemfile.lock`, or `Dockerfile` changes.

```sh
cd /Users/ppuccinir/Documents/Development/sure-household.nosync
docker-compose -f compose.yml -f compose.dev.yml build
bin/dev-docker
```

## Common Rails commands

Run a migration:

```sh
docker-compose -f compose.yml -f compose.dev.yml exec web bin/rails db:migrate
```

Open a Rails console:

```sh
docker-compose -f compose.yml -f compose.dev.yml exec web bin/rails console
```

Run tests:

```sh
docker-compose -f compose.yml -f compose.dev.yml exec web env RAILS_ENV=test DISABLE_DATABASE_ENVIRONMENT_CHECK=1 bin/rails test
```

## If port 3000 is busy

That usually means an older stack is still running.

```sh
cd /Users/ppuccinir/Documents/Development/sure-household.nosync
docker-compose down
docker-compose -f compose.yml -f compose.dev.yml down
bin/dev-docker
```
