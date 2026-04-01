import Config

if System.get_env("PHX_SERVER") do
  config :pgpeek, PgpeekWeb.Endpoint, server: true
end

config :pgpeek, PgpeekWeb.Endpoint,
  http: [port: String.to_integer(System.get_env("PORT", "4444"))]

# DATABASE_URL is the monitored Postgres database (read-only connection)
if database_url = System.get_env("DATABASE_URL") do
  config :pgpeek, Pgpeek.ProbeRepo, url: database_url
end

# ADMIN_PASSWORD is only used on first boot to seed the admin user
if admin_password = System.get_env("ADMIN_PASSWORD") do
  config :pgpeek, :admin_password, admin_password
end

# Snapshot polling interval in seconds (default: 300 = 5 minutes)
if interval = System.get_env("SNAPSHOT_INTERVAL") do
  config :pgpeek, :snapshot_interval, String.to_integer(interval) * 1_000
end

# LLM for query explanations (optional, format: "provider:model")
# Examples: "anthropic:claude-haiku-4-5", "openai:gpt-4o-mini", "ollama:llama3"
# Requires corresponding API key env var (ANTHROPIC_API_KEY, OPENAI_API_KEY, etc)
if llm_model = System.get_env("LLM_MODEL") do
  config :pgpeek, :llm_model, llm_model
end

# Retention period in days (default: 7)
if retention = System.get_env("RETENTION_DAYS") do
  config :pgpeek, :retention_days, String.to_integer(retention)
end

# SQLite database path override (useful for Docker volumes)
if data_dir = System.get_env("DATA_DIR") do
  config :pgpeek, Pgpeek.Repo, database: Path.join(data_dir, "pgpeek.db")
end

if config_env() == :prod do
  secret_key_base =
    System.get_env("SECRET_KEY_BASE") ||
      raise """
      environment variable SECRET_KEY_BASE is missing.
      You can generate one by calling: mix phx.gen.secret
      """

  host = System.get_env("PHX_HOST") || "localhost"
  scheme = System.get_env("PHX_SCHEME", "https")

  url_port =
    if scheme == "https", do: 443, else: String.to_integer(System.get_env("PORT", "4444"))

  config :pgpeek, :dns_cluster_query, System.get_env("DNS_CLUSTER_QUERY")

  config :pgpeek, PgpeekWeb.Endpoint,
    url: [host: host, port: url_port, scheme: scheme],
    http: [ip: {0, 0, 0, 0, 0, 0, 0, 0}],
    secret_key_base: secret_key_base

  # Disable force_ssl when running behind a reverse proxy on HTTP
  if scheme == "http" do
    config :pgpeek, PgpeekWeb.Endpoint, force_ssl: false
  end
end
