defmodule DomainNameOperator.Operator do
  @moduledoc """
  Entry point for the DomainNameOperator Bonny pipeline.

  The operator owns the watch queries for the CRDs we manage and the shared
  processing steps that every action event should pass through.
  """

  use Bonny.Operator, default_watch_namespace: :all

  alias DomainNameOperator.Controller.V1.CloudflareDnsRecord

  step(Bonny.Pluggable.Logger, level: :info)
  step(:delegate_to_controller)
  step(Bonny.Pluggable.ApplyStatus)
  step(Bonny.Pluggable.ApplyDescendants)

  @impl Bonny.Operator
  def controllers(_watch_namespace, _opts) do
    [
      %{
        query:
          K8s.Client.watch(
            CloudflareDnsRecord.api_version(),
            CloudflareDnsRecord.crd_names().kind,
            namespace: :all
          ),
        controller: CloudflareDnsRecord
      }
    ]
  end

  @impl Bonny.Operator
  def crds do
    # CRDs are currently maintained by k8s/domain_name_operator_crd.yaml.
    # Returning an empty list keeps manifest generation optional for now.
    []
  end
end
