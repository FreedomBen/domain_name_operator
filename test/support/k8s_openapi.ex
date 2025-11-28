defmodule DomainNameOperator.K8sOpenapi do
  @moduledoc """
  Helpers for working with the local Kubernetes OpenAPI specification in tests.

  The spec is expected at `priv/openapi/kubernetes/swagger.json`, which can be
  downloaded via `mix k8s_spec`. Tests and mocks should treat the spec as an
  optional enhancement: if it is missing, helpers fall back to simple defaults
  rather than failing hard.
  """

  @spec spec() :: map() | nil
  def spec do
    priv_dir = :code.priv_dir(:domain_name_operator)
    path = Path.join([priv_dir, "openapi", "kubernetes", "swagger.json"])

    case File.read(path) do
      {:ok, body} ->
        Jason.decode!(body)

      {:error, _} ->
        nil
    end
  end

  @spec service_definition() :: map() | nil
  def service_definition do
    with %{"definitions" => defs} <- spec() do
      Map.get(defs, "io.k8s.api.core.v1.Service")
    end
  end

  @doc """
  Build a simple `Service` resource suitable for tests.

  If the OpenAPI spec is available, this helper can be extended to validate
  against or derive fields from the schema. For now it returns a minimal map
  consistent with how the operator reads Service objects.
  """
  @spec example_service(String.t(), String.t(), String.t()) :: map()
  def example_service(namespace, name, ip \\ "203.0.113.10") do
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
            %{"ip" => ip}
          ]
        }
      }
    }
  end
end

