import Config

config :domain_name_operator,
  zone_id: "1576e86130161d3809f2e5248e8d9e08"

config :k8s,
  clusters: %{
    default: %{
      conn: "~/.kube/ameelio-k8s-dev-kubeconfig.yaml"
    }
  }

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
