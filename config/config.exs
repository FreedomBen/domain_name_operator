import Config

config :bonny,
  group: "domain-name-operator.tamx.org",
  get_conn: {DomainNameOperator.K8sConn, :get!, []},
  operator_name: "domain-name-operator",
  service_account_name: "domain-name-operator",
  labels: %{"k8s-app" => "domain-name-operator"},
  resources: %{
    limits: %{cpu: "200m", memory: "200Mi"},
    requests: %{cpu: "200m", memory: "200Mi"}
  }

config :domain_name_operator, DomainNameOperator.K8sConn, :service_account
config :domain_name_operator, :enable_operator, true

config :logger, :console,
  format: "$time $metadata[$level] $message\n",
  metadata: [:error_code],
  color: [enabled: true]

import_config "#{config_env()}.exs"
