# Repository Guidelines

## Project Structure & Module Organization
- Code: `app/` (Rails MVC, services, jobs, mailers, components), JS in `app/javascript/`, styles/assets in `app/assets/` (Tailwind, images, fonts).
- Config: `config/`, environment examples in `.env.local.example` and `.env.test.example`.
- Data: `db/` (migrations, seeds), fixtures in `test/fixtures/`.
- Tests: `test/` mirroring `app/` (e.g., `test/models/*_test.rb`).
- Tooling: `bin/` (project scripts), `docs/` (guides), `public/` (static), `lib/` (shared libs).

## Build, Test, and Development Commands
- Setup: `cp .env.local.example .env.local && bin/setup` — install deps, set DB, prepare app.
- Run app: `bin/dev` — starts Rails server and asset/watchers via `Procfile.dev`.
- Test suite: `bin/rails test` — run all Minitest tests; add `TEST=test/models/user_test.rb` to target a file.
- Lint Ruby: `bin/rubocop` — style checks; add `-A` to auto-correct safe cops.
- Lint/format JS/CSS: `npm run lint` and `npm run format` — uses Biome.
- Security scan: `bin/brakeman` — static analysis for common Rails issues.

## Coding Style & Naming Conventions
- Ruby: 2-space indent, `snake_case` for methods/vars, `CamelCase` for classes/modules. Follow Rails conventions for folders and file names.
- Views: ERB checked by `erb-lint` (see `.erb_lint.yml`). Avoid heavy logic in views; prefer helpers/components.
- JavaScript: `lowerCamelCase` for vars/functions, `PascalCase` for classes/components. Let Biome format code.
- Commit small, cohesive changes; keep diffs focused.

## Testing Guidelines
- Framework: Minitest (Rails). Name files `*_test.rb` and mirror `app/` structure.
- Run: `bin/rails test` locally and ensure green before pushing.
- Fixtures/VCR: Use `test/fixtures` and existing VCR cassettes for HTTP. Prefer unit tests plus focused integration tests.

## Commit & Pull Request Guidelines
- Commits: Imperative subject ≤ 72 chars (e.g., "Add account balance validation"). Include rationale in body and reference issues (`#123`).
- PRs: Clear description, linked issues, screenshots for UI changes, and migration notes if applicable. Ensure CI passes, tests added/updated, and `rubocop`/Biome are clean.

## Security & Configuration Tips
- Never commit secrets. Start from `.env.local.example`; use `.env.local` for development only.
- Run `bin/brakeman` before major PRs. Prefer environment variables over hard-coded values.

## API Development Guidelines

### OpenAPI Documentation (MANDATORY)
When adding or modifying API endpoints in `app/controllers/api/v1/`, you **MUST** create or update corresponding OpenAPI request specs for **DOCUMENTATION ONLY**:

1. **Location**: `spec/requests/api/v1/{resource}_spec.rb`
2. **Framework**: RSpec with rswag for OpenAPI generation
3. **Schemas**: Define reusable schemas in `spec/swagger_helper.rb`
4. **Generated Docs**: `docs/api/openapi.yaml`
5. **Regenerate**: Run `RAILS_ENV=test bundle exec rake rswag:specs:swaggerize` after changes

### Post-commit API consistency (LLM checklist)
After every API endpoint commit, ensure: (1) **Minitest** behavioral coverage in `test/controllers/api/v1/{resource}_controller_test.rb` (no behavioral assertions in rswag); (2) **rswag** remains docs-only (no `expect`/`assert_*` in `spec/requests/api/v1/`); (3) **rswag auth** uses the same API key pattern everywhere (`X-Api-Key`, not OAuth/Bearer). Full checklist: [.cursor/rules/api-endpoint-consistency.mdc](.cursor/rules/api-endpoint-consistency.mdc).

## Providers: Pending Transactions and FX Metadata (SimpleFIN/Plaid/Lunchflow)

- Pending detection
  - SimpleFIN: pending when provider sends `pending: true`, or when `posted` is blank/0 and `transacted_at` is present.
  - Plaid: pending when Plaid sends `pending: true` (stored at `transaction.extra["plaid"]["pending"]` for bank/credit transactions imported via `PlaidEntry::Processor`).
  - Lunchflow: pending when API returns `isPending: true` in transaction response (stored at `transaction.extra["lunchflow"]["pending"]`).
- Storage (extras)
  - Provider metadata lives on `Transaction#extra`, namespaced (e.g., `extra["simplefin"]["pending"]`).
  - SimpleFIN FX: `extra["simplefin"]["fx_from"]`, `extra["simplefin"]["fx_date"]`.
- UI
  - Shows a small “Pending” badge when `transaction.pending?` is true.
- Variability
  - Some providers don’t expose pendings; in that case nothing is shown.
- Configuration (default-off)
  - SimpleFIN runtime toggles live in `config/initializers/simplefin.rb` via `Rails.configuration.x.simplefin.*`.
  - Lunchflow runtime toggles live in `config/initializers/lunchflow.rb` via `Rails.configuration.x.lunchflow.*`.
  - ENV-backed keys:
    - `SIMPLEFIN_INCLUDE_PENDING=1` (forces `pending=1` on SimpleFIN fetches when caller didn’t specify a `pending:` arg)
    - `SIMPLEFIN_DEBUG_RAW=1` (logs raw payload returned by SimpleFIN)
    - `LUNCHFLOW_INCLUDE_PENDING=1` (forces `include_pending=true` on Lunchflow API requests)
    - `LUNCHFLOW_DEBUG_RAW=1` (logs raw payload returned by Lunchflow)

### Provider support notes

- SimpleFIN: supports pending + FX metadata; stored under `extra["simplefin"]`.
- Plaid: supports pending when the upstream Plaid payload includes `pending: true`; stored under `extra["plaid"]`.
- Plaid investments: investment transactions currently do not store pending metadata.
- Lunchflow: supports pending via `include_pending` query parameter; stored under `extra["lunchflow"]`.
- Manual/CSV imports: no pending concept.

## Codex Rule Translation from `.cursor/rules` (always-on)
These are the normalized instructions Codex should follow on every prompt so Cursor `.mdc` rules are enforced in this environment.

### Core behavior
- Use `Current.user` and `Current.family` (never `current_user` / `current_family`).
- Before coding, review project architecture and conventions in `.cursor/rules/project-design.mdc`, `.cursor/rules/project-conventions.mdc`, and `.cursor/rules/ui-ux-design-guidelines.mdc`.
- Migrations must inherit from `ActiveRecord::Migration[7.2]`.
- Never run: `rails server`, `touch tmp/restart.txt`, `rails credentials`, or automatic migrations.

### Architecture and domain expectations
- Follow the app's Rails-first architecture and finance domain model in `.cursor/rules/project-design.mdc`.
- Prefer POROs/concerns and model-centric logic over adding service-object layers.
- Minimize dependencies; justify any new dependency with strong technical/business need.
- Keep code clear and simple; optimize performance only in globally critical paths.

### View/UI/Stimulus expectations
- Prefer semantic HTML and Hotwire-first patterns (Turbo frames/streams before custom JS apps).
- Prefer components over partials when behavior, reuse, variants, or accessibility complexity exists.
- Keep domain/business logic out of ERB templates.
- Stimulus must be declarative (`data-action` in HTML); avoid imperative event wiring in `connect`.
- Keep Stimulus controllers focused/lightweight; component-scoped controllers stay inside their components.
- Use Tailwind design tokens from `app/assets/tailwind/maybe-design-system.css` (e.g., `text-primary`, `bg-container`) instead of ad hoc color utilities.
- Do not add new styles to `maybe-design-system.css` or `application.css` without explicit permission.
- Use the `icon` helper in `app/helpers/application_helper.rb`; never call `lucide_icon` directly.

### Testing expectations
- Use Minitest + fixtures (not RSpec/factories) for behavioral tests in `test/`.
- Write pragmatic tests for important paths; avoid testing Rails internals.
- Test boundaries correctly (assert your unit's outcomes, mock/stub command boundaries only).
- Use `mocha` for mocks/stubs; prefer `OpenStruct` for simple test doubles.

### API endpoint consistency expectations
When editing `app/controllers/api/v1/**`, `test/controllers/api/v1/**`, or `spec/requests/api/v1/**`:
- Add/update Minitest behavioral coverage in `test/controllers/api/v1/{resource}_controller_test.rb`.
- Keep rswag request specs documentation-only (no behavioral assertions).
- Use the shared API key auth pattern with `X-Api-Key` consistently (no OAuth/Bearer).
- Regenerate OpenAPI docs with `RAILS_ENV=test bundle exec rake rswag:specs:swaggerize` after spec changes.

### Rule maintenance expectations
- If a pattern appears repeatedly (or recurring bugs/review comments emerge), update `.cursor/rules/*.mdc` and keep examples synced with real code.
