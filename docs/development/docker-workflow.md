# Docker Development Workflow

This project can run in a Docker-based development mode without requiring Ruby on the host machine.

## What you get

- Rails code reloads on refresh because the repo is bind-mounted into the container
- Tailwind watches for stylesheet changes
- Sidekiq runs in a separate container
- PostgreSQL and Redis stay in Docker

This is not full frontend HMR, but for Rails work it is the practical "edit, refresh, see it" workflow.

## First-time setup

1. Copy the local env file if you have not already:

```sh
cp .env.local.example .env.local
```

2. Build the containers:

```sh
docker-compose -f compose.yml -f compose.dev.yml build
```

3. Prepare the database:

```sh
docker-compose -f compose.yml -f compose.dev.yml run --rm web bin/rails db:prepare
```

## Start development mode

Run:

```sh
bin/dev-docker
```

This starts:

- `web` on `http://localhost:3000`
- `worker` for Sidekiq
- `css` for Tailwind watch
- `db` and `redis`

## Common commands

Open a Rails console:

```sh
docker-compose -f compose.yml -f compose.dev.yml exec web bin/rails console
```

Run a migration:

```sh
docker-compose -f compose.yml -f compose.dev.yml exec web bin/rails db:migrate
```

Run tests:

```sh
docker-compose -f compose.yml -f compose.dev.yml exec web env RAILS_ENV=test DISABLE_DATABASE_ENVIRONMENT_CHECK=1 bin/rails test
```

Stop everything:

```sh
docker-compose -f compose.yml -f compose.dev.yml down
```

## When you need a rebuild

You only need to rebuild when dependencies or the Docker image itself change, for example:

- `Gemfile` / `Gemfile.lock`
- system packages in `Dockerfile`

Then run:

```sh
docker-compose -f compose.yml -f compose.dev.yml build
```
