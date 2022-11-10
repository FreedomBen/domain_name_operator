import Config

config :k8s,
  clusters: %{
    default: %{}
  }

# config :logger, level: :info
config :logger, level: :debug

config :logger, Sentry.LoggerBackend,
  level: :error,
  excluded_domains: [],
  # metadata: [:foo_bar],
  # Change to true to capture log messages!
  capture_log_messages: false
