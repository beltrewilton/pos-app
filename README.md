# POS

POS is a desktop client and server foundation for a future point-of-sale system.

## Architecture

```text
Tauri Client
HTML / CSS / Vanilla JavaScript
Rust native device layer
        ⇅
Phoenix / Elixir
        ⇅
PostgreSQL
```

## Responsibilities

- JavaScript renders the POS UI, owns temporary cart state, and invokes client/server boundaries.
- Rust owns native device access, including USB transport and ESC/POS receipt encoding.
- Elixir/Phoenix will own business rules, authorization, sales, inventory, realtime events, and integrations.
- PostgreSQL will hold persistent application state.

## Current status

- The Tauri desktop PoC is validated on macOS Apple Silicon.
- Epson TM-T20II direct USB ESC/POS printing is validated on macOS.
- The Phoenix server foundation includes PostgreSQL repository configuration, PubSub, Channels, Triplex wiring, public identity migrations, tenant company migrations, and `GET /api/health`.
- POS business-domain migration has not started.
- Windows, Android, and iOS printer support have not been validated.

## Repository layout

```text
client/  Tauri v2 desktop client
server/  Phoenix/Elixir application foundation
```

## Development

Prerequisites: Rust stable, Node.js/npm, Elixir/Erlang, Phoenix installer, and PostgreSQL.

Create the Phoenix skeleton (already completed in this repository) with:

```bash
mix phx.new server \
  --app pos_server \
  --module PosServer \
  --database postgres \
  --binary-id \
  --no-tailwind \
  --no-install \
  --no-agents-md
```

Set up the server once:

```bash
cd server
cp .env.example .env
./sh/deps_get.sh
```

The database is provisioned outside of Mix. Public and Triplex tenant migrations are checked in but are not run automatically; tenant creation and migration orchestration will be introduced deliberately in a later SaaS phase.

To run the public migrations after the database has been provisioned:

```bash
cd server
./sh/migrate.sh
```

Run the server in terminal 1:

```bash
cd server
./sh/run_local.sh
```

On macOS, `sh/run_local.sh` starts Phoenix with `iex -S mix phx.server`.

Run the desktop client in terminal 2:

```bash
cd client
npm install
npm run tauri dev
```

The health endpoint is available at `http://localhost:4000/api/health` when the Phoenix server is running.

## Phoenix LiveView foundation

For a fresh Phoenix application with HTML and LiveView support, use:

```bash
mix phx.new server \
  --app pos_server \
  --module PosServer \
  --database postgres \
  --binary-id \
  --no-tailwind \
  --no-install \
  --no-agents-md
```

Do not add `--no-html`, `--no-assets`, or `--no-live`: the application needs Phoenix HTML, static assets, and LiveView forms. `--no-tailwind` is intentional because the UI uses static framework-agnostic shadcn-html CSS. `--no-install` prevents the generator from fetching dependencies or compiling during generation. The existing `server/` application has been upgraded manually to preserve its Triplex configuration and migrations. Its Users screen is available at `/users` (`/users/new` remains available as a compatibility route).

The UI uses vendored framework-agnostic shadcn-html assets. No npm package or asset build is required for those components.
