import Config

config :domain_name_operator,
  cloudflare_api_token: System.get_env("CLOUDFLARE_API_TOKEN")

# config :domain_name_operator,
#   cloudflare_zone_id: System.get_env("CLOUDFLARE_ZONE_ID")

config :sentry,
  dsn: System.get_env("SENTRY_DSN"),
  environment_name: Mix.env(),
  enable_source_code_context: true,
  root_source_code_path: File.cwd!(),
  tags: %{
    env: Mix.env()
  },
  included_environments: [:prod]
