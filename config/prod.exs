import Config

# config :logger, level: :info
config :logger, level: :debug

config :k8s,
  clusters: %{
    default: %{}
  }
