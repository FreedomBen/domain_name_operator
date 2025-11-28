import Config

config :domain_name_operator,
  cloudflare_api_token: "test-token",
  cloudflare_default_domain: "example.com",
  cloudflare_default_zone_id: "test-zone-id",
  k8s_client: DomainNameOperator.K8sClient.Mock

config :logger, level: :warning

config :logger, :console,
  format: "[$level] $message\n",
  metadata: [],
  color: [enabled: false]

config :logger, Sentry.LoggerBackend,
  level: :error,
  excluded_domains: [],
  capture_log_messages: false

config :sentry,
  dsn: nil,
  environment_name: :test,
  included_environments: [:test]

