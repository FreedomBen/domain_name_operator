defmodule DomainNameOperator.K8sClient do
  @moduledoc """
  Thin wrapper around the Kubernetes client used by the operator.

  This module exists to make it easy to substitute a test implementation that
  does not talk to a real Kubernetes API server.
  """

  @callback get_service(namespace :: String.t(), name :: String.t()) ::
              {:ok, map()}
              | {:error, :service_not_found, %{namespace: String.t(), name: String.t()}}
              | {:error, any(), %{namespace: String.t(), name: String.t()}}

  alias DomainNameOperator.Utils
  alias DomainNameOperator.Utils.Logger

  @behaviour __MODULE__

  @doc """
  Retrieve a Service object from Kubernetes.

  Returns:
    * `{:ok, service_map}` on success
    * `{:error, :service_not_found, %{namespace: ns, name: name}}` if not found
    * `{:error, reason, %{namespace: ns, name: name}}` for other errors
  """
  @spec get_service(String.t(), String.t()) ::
          {:ok, map()}
          | {:error, :service_not_found, %{namespace: String.t(), name: String.t()}}
          | {:error, any(), %{namespace: String.t(), name: String.t()}}
  def get_service(namespace, name) do
    svc = %{
      "apiVersion" => "v1",
      "kind" => "Service",
      "metadata" => %{
        "name" => name,
        "namespace" => namespace
      }
    }

    Logger.debug(
      __ENV__,
      "Retrieving Service object from k8s: name='#{name}' namespace='#{namespace}'"
    )

    # See notes in original controller code about using service account vs kubeconfig.
    with _conn <- K8s.Conn.from_service_account(),
         operation <- K8s.Client.get(svc),
         {:ok, result} <- K8s.Client.run(operation, :default) do
      Logger.info(
        Utils.FromEnv.mfa_str(__ENV__) <>
          ": Retrieved Service object from k8s: #{Utils.map_to_string(result)}"
      )

      {:ok, result}
    else
      {:error, :not_found} ->
        Logger.error(
          Utils.FromEnv.mfa_str(__ENV__) <>
            ": Error retrieving Service object from k8s.  It does not appear to exist.  Verify it is named '#{name}' and is in the namespace '#{namespace}': :service_not_found"
        )

        {:error, :service_not_found, %{namespace: namespace, name: name}}

      err ->
        Logger.error(
          Utils.FromEnv.mfa_str(__ENV__) <>
            ": Error retrieving Service object from k8s: #{Utils.to_string(err)}"
        )

        {:error, err, %{namespace: namespace, name: name}}
    end
  end
end

