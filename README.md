# DomainNameOperator

DomainNameOperator is an Elixir-powered Kubernetes operator built with [Bonny](https://github.com/coryodaniel/bonny) that manages `CloudflareDnsRecord` custom resources. It watches for Kubernetes resources that describe the desired Cloudflare DNS entries (including the service to point at, hostname, zone, and proxy settings) and reconciles those changes against the Cloudflare API so your cluster services automatically receive the correct external DNS.

## Features

- Reconciles `CloudflareDnsRecord` CRDs in the `domain-name-operator.tamx.org/v1` API group.
- Talks to Cloudflare DNS via the bundled `CloudflareClient`, keeping records in sync with cluster Services.
- Ships with controller logic, caching, and exception handling tailored for Cloudflare automation.
- Runs anywhere you can deploy Kubernetes operators; see `k8s/` and `domain_name_operator_crd.yaml` for manifests.

## Example DNS Record

```yaml
apiVersion: domain-name-operator.tamx.org/v1
kind: CloudflareDnsRecord
metadata:
  name: accounts
  labels:
    app: malan
    tier: web
    env: prod
    kind: cloudflarednsrecord
  namespace: malan-prod
spec:
  hostName: accounts.ameelio.org
  serviceName: malan
  proxied: true
```

## Example DNS Record (with Zone ID)

```yaml
apiVersion: domain-name-operator.tamx.org/v1
kind: CloudflareDnsRecord
metadata:
  name: api
  labels:
    app: edge
    tier: api
    env: prod
    kind: cloudflarednsrecord
  namespace: edge-prod
spec:
  hostName: api.example.com
  serviceName: edge-api
  domain: example.com
  zoneId: 023e105f4ecef8ad9ca31a8372d0c353
  proxied: false
```

## Development

Start locally:

1.  Apply CRD to target cluster
2.  Setup kube config in `config/dev.exs`
3.  Start with `iex -S mix`

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `domain_name_operator` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:domain_name_operator, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/domain_name_operator>.
