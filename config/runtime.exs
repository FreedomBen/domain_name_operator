import Config

config :domain_name_operator,
  cloudflare_api_token: System.get_env("CLOUDFLARE_API_TOKEN")

# config :domain_name_operator,
#   cloudflare_zone_id: System.get_env("CLOUDFLARE_ZONE_ID")

config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  environment_name: System.get_env("MIX_ENV") || :dev,
  enable_source_code_context: true,
  root_source_code_path: File.cwd!(),
  tags: %{
    env: System.get_env("MIX_ENV") || :dev
  },
  included_environments: [:dev, :prod]

# included_environments: [:prod]
