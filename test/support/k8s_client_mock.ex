defmodule DomainNameOperator.K8sClient.Mock do
  @moduledoc """
  Test implementation of the Kubernetes client.

  This module does not perform any network calls. It returns deterministic
  Service objects for use in tests.
  """

  @behaviour DomainNameOperator.K8sClient

  alias DomainNameOperator.K8sOpenapi

  @impl true
  def get_service(namespace, name) do
    case name do
      "existing-service" ->
        {:ok, K8sOpenapi.example_service(namespace, name)}

      _ ->
        {:error, :service_not_found, %{namespace: namespace, name: name}}
    end
  end
end
