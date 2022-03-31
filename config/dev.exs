import Config

# config :domain_name_operator,
#   cloudflare_zone_id: "c82786df7abd35eb6773c67960fba8d3" # prod
#   cloudflare_zone_id: "53eb2f3db04afdb3a9fca95bf5b27d10" # xyz

config :k8s,
  clusters: %{
    default: %{
      conn: "~/.kube/ameelio-k8s-dev-kubeconfig.yaml"
    }
  }

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "[$level] $message\n"

config :logger, level: :debug


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
