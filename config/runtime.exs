import Config

config :domain_name_operator,
  cloudflare_api_token: System.get_env("CLOUDFLARE_API_TOKEN")
