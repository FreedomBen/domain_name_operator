import Config

config :k8s,
  clusters: %{
    default: %{
      conn: "~/.kube/ameelio-k8s-dev-kubeconfig.yaml"
    }
  }

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

config :logger, level: :debug

config :logger, Sentry.LoggerBackend,
  level: :error,
  excluded_domains: [],
  # metadata: [:foo_bar],
  # Change to true to capture log messages!
  capture_log_messages: false

# config.exs
config :bonny, K8s.Conn, {:from_file, ["~/.kube/config", [context: "optional-alternate-context"]]}

# config :bonny,
# {
#   K8s.Conn,
#   :from_file,
#   ["~/.kube/ameelio-k8s-dev-kubeconfig.yaml", [context: "optional-alternate-context"]]
# }

# config :bonny, {K8s.Conn, :from_file,
#     ["~/.kube/ameelio-k8s-dev-kubeconfig.yaml", [context: "optional-alternate-context"]]}
