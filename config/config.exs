import Config

# The default k8s config uses the service account in the Pod, so leave this out
# config :k8s,
#   clusters: %{
#     default: %{ # `default` here must match `cluster_name` below
#       conn: "~/.kube/config"
#     }
#   }

config :bonny,
  # Add each CRD Controller module for this operator to load here
  controllers: [
    DomainNameOperator.Controller.V1.CloudflareDnsRecord
  ],

  # Your kube config file here
  # kubeconf_file: "~/.kube/config",
  kubeconf_file: "~/.kube/ameelio-k8s-dev-kubeconfig.yaml",

  # Bonny will default to using your current-context, optionally set cluster: and user: here.
  # kubeconf_opts: [cluster: "my-cluster", user: "my-user"]
  kubeconf_opts: [],

  resources: %{
    limits: %{cpu: "200m", memory: "200Mi"},
    requests: %{cpu: "200m", memory: "200Mi"}
  }

config :logger, :console,
 format: "$time $metadata[$level] $message\n",
 # metadata: [:error_code, :file],
 metadata: [:error_code],
 color: [enabled: true]

import_config "#{config_env()}.exs"
