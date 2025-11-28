defmodule DomainNameOperator.K8sClient.Mock do
  @moduledoc """
  Test implementation of the Kubernetes client.

  This module does not perform any network calls. It returns deterministic
  Service objects for use in tests.
  """

  @behaviour DomainNameOperator.K8sClient

  @impl true
  def get_service(namespace, name) do
    case {namespace, name} do
      {"default", "existing-service"} ->
        {:ok, example_service(namespace, name)}

      _ ->
        {:error, :service_not_found, %{namespace: namespace, name: name}}
    end
  end

  defp example_service(namespace, name) do
    %{
      "apiVersion" => "v1",
      "kind" => "Service",
      "metadata" => %{
        "name" => name,
        "namespace" => namespace
      },
      "status" => %{
        "loadBalancer" => %{
          "ingress" => [
            %{"ip" => "203.0.113.10"}
          ]
        }
      }
    }
  end
end

