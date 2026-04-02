# PgPeek

A self-hosted Postgres performance dashboard. Connects to your database read-only, snapshots `pg_stat_statements` periodically, stores history in SQLite, and surfaces trends, anomalies, and diagnostics in a clean LiveView UI.

**Zero footprint** on the monitored database — never creates tables, never writes, never resets stats.

![Dashboard](docs/dashboard.png)

![Query Details](docs/query_details.png)

![Diagnostics](docs/diagnose.png)

## Features

- **Dashboard** — cache hit ratio, connections, top queries by total time, delta tracking between snapshots
- **Query explorer** — sortable query list, per-query detail with history trend, EXPLAIN (GENERIC_PLAN) support
- **Diagnostics** — 25 checks across health, indexes, tables, queries, connections, and system settings
- **N+1 detection** — flags high-frequency, low-latency parameterized queries
- **Regression detection** — alerts when query mean time exceeds 2x the 7-day baseline
- **Deploy markers** — `POST /api/deploys` to annotate when deploys happened
- **AI explanations** — optional LLM integration for plain English query explanations and optimization suggestions (OpenAI, Anthropic, Ollama, etc.)
- **Auth** — session-based login, user management, password changes

## Quick start (Docker)

```bash
docker run -d --name pgpeek \
  -p 4444:4444 \
  -e PGPEEK_DATABASE_URL=postgres://readonly_user:pass@host:5432/mydb \
  -e PGPEEK_ADMIN_PASSWORD=changeme \
  -e PGPEEK_SECRET_KEY_BASE=$(openssl rand -hex 64) \
  -v pgpeek_data:/data \
  ghcr.io/gautema/pgpeek:latest
```

Visit [localhost:4444](http://localhost:4444) and log in with `admin@pgpeek.local` / your `PGPEEK_ADMIN_PASSWORD`.

### Docker Compose

```yaml
services:
  pgpeek:
    image: ghcr.io/gautema/pgpeek:latest
    ports:
      - "4444:4444"
    environment:
      PGPEEK_DATABASE_URL: postgres://readonly_user:pass@host:5432/mydb
      PGPEEK_ADMIN_PASSWORD: changeme
      PGPEEK_SECRET_KEY_BASE: # generate with: openssl rand -hex 64
    volumes:
      - pgpeek_data:/data

volumes:
  pgpeek_data:
```

### From source

```bash
export PGPEEK_DATABASE_URL=postgres://readonly_user:pass@localhost:5432/mydb
export PGPEEK_ADMIN_PASSWORD=changeme
mix setup
mix phx.server
```

## Environment variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PGPEEK_DATABASE_URL` | _(required)_ | Postgres connection string for the monitored database (read-only) |
| `PGPEEK_ADMIN_PASSWORD` | _(required on first boot)_ | Seeds the initial admin user. Ignored after first boot. |
| `PGPEEK_SECRET_KEY_BASE` | _(required in prod)_ | Phoenix secret for signing cookies. Generate with `openssl rand -hex 64` |
| `PORT` | `4444` | HTTP port |
| `PHX_HOST` | `localhost` | Hostname for URL generation |
| `PHX_SCHEME` | `https` | URL scheme (`http` if behind a reverse proxy handling TLS) |
| `SNAPSHOT_INTERVAL` | `300` | Seconds between snapshots (default: 5 minutes) |
| `RETENTION_DAYS` | `7` | Days to keep snapshot history before auto-cleanup |
| `DATA_DIR` | `./data` | SQLite database directory (mount as Docker volume) |
| `LLM_MODEL` | _(optional)_ | Initial LLM for AI query explanations, e.g. `anthropic:claude-haiku-4-5`, `openai:gpt-4o-mini`, `ollama:llama3`. Can also be configured in Settings UI. |
| `ANTHROPIC_API_KEY` | _(optional)_ | API key for Anthropic (if using `anthropic:` models). Can also be configured in Settings UI. |
| `OPENAI_API_KEY` | _(optional)_ | API key for OpenAI (if using `openai:` models). Can also be configured in Settings UI. |

## Storage considerations

PgPeek stores snapshot data in SQLite. Storage depends on the number of tracked queries in `pg_stat_statements` (default max: 5,000) and your snapshot interval.

**Per snapshot:** ~80 bytes per query (query text is stored once, not per snapshot).

| Interval | Snapshots/day | 5K queries/day | 7-day steady state |
|----------|--------------|----------------|-------------------|
| 5 min | 288 | ~110 MB | ~800 MB |
| 10 min | 144 | ~55 MB | ~400 MB |
| 15 min | 96 | ~37 MB | ~260 MB |

Tune with:
- `RETENTION_DAYS` — reduce to 3 for ~half the storage
- `SNAPSHOT_INTERVAL` — increase to 600 (10 min) or 900 (15 min) for less granularity but lower disk use
- Postgres `pg_stat_statements.max` — fewer tracked queries = smaller snapshots

Old snapshots are automatically cleaned up after each capture based on `RETENTION_DAYS`.

## Requirements

- PostgreSQL 16+ (for `EXPLAIN GENERIC_PLAN` support)
- `pg_stat_statements` extension enabled on the monitored database
- Elixir 1.16+ / Erlang/OTP 26+ (for development)

## Monitored database setup

PgPeek only needs a read-only connection. Create a dedicated user:

```sql
CREATE USER pgpeek_readonly WITH PASSWORD 'your-password';
GRANT CONNECT ON DATABASE mydb TO pgpeek_readonly;
GRANT USAGE ON SCHEMA public TO pgpeek_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO pgpeek_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO pgpeek_readonly;

-- Required for pg_stat_statements access
GRANT pg_read_all_stats TO pgpeek_readonly;
```

## API

### Deploy markers

Mark deploys so they can be correlated with query performance changes:

```bash
curl -X POST http://localhost:4444/api/deploys \
  -H "Content-Type: application/json" \
  -d '{"description": "v1.2.3 release"}'
```

## Development

```bash
mix setup          # Install deps, create DB, run migrations
mix phx.server     # Start dev server
mix test           # Run tests
mix precommit      # Compile (warnings-as-errors), format, test
```

## License

MIT
