import Config

config :domain_name_operator,
       DomainNameOperator.K8sConn,
       {:file, "~/.kube/ameelio-k8s-dev-kubeconfig.yaml", []}

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

config :logger, level: :debug

config :logger, Sentry.LoggerBackend,
  level: :error,
  excluded_domains: [],
  # metadata: [:foo_bar],
  # Change to true to capture log messages!
  capture_log_messages: false
