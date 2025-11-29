import Config

config :domain_name_operator,
  cloudflare_api_token: "test-token",
  cloudflare_default_domain: "example.com",
  cloudflare_default_zone_id: "test-zone-id",
  k8s_client: DomainNameOperator.K8sClient.Mock,
  cloudflare_client: DomainNameOperator.CloudflareClient.Mock,
  sentry_client: DomainNameOperator.SentryClient.Test

config :logger, level: :warning

config :logger, :console,
  format: "[$level] $message\n",
  metadata: [],
  color: [enabled: false]

config :sentry,
  dsn: nil,
  environment_name: :test,
  log_level: :warning,
  included_environments: [:test]
