defmodule DomainNameOperator.K8sConn do
  @moduledoc """
  Builds `K8s.Conn` structs based on the environment-specific configuration.

  The module centralizes how we talk to Kubernetes so the operator, the
  on-demand `DomainNameOperator.K8sClient`, and our tests all reuse the same
  connection shape.
  """

  alias K8s.Conn

  @config_key __MODULE__

  @spec get!() :: Conn.t()
  def get! do
    case Application.get_env(:domain_name_operator, @config_key, :service_account) do
      %Conn{} = conn ->
        conn

      {:conn, %Conn{} = conn} ->
        conn

      {:file, path} ->
        path |> Path.expand() |> Conn.from_file() |> unwrap!()

      {:file, path, opts} ->
        path |> Path.expand() |> Conn.from_file(opts) |> unwrap!()

      :service_account ->
        Conn.from_service_account() |> unwrap!()

      {:service_account, opts} ->
        Conn.from_service_account(opts) |> unwrap!()

      {:test, discovery_path} ->
        build_test_conn(Path.expand(discovery_path))

      other ->
        raise ArgumentError,
              "Unsupported Kubernetes connection provider #{inspect(other)}. " <>
                "Configure :domain_name_operator, #{inspect(@config_key)} accordingly."
    end
  end

  defp build_test_conn(discovery_path) do
    %Conn{
      url: "https://localhost",
      discovery_driver: K8s.Discovery.Driver.File,
      discovery_opts: [config: discovery_path],
      http_provider: K8s.Client.DynamicHTTPProvider,
      cacertfile: Path.join(System.tmp_dir!(), "k8s-test-cacert")
    }
  end

  defp unwrap!({:ok, %Conn{} = conn}), do: conn

  defp unwrap!({:error, reason}) do
    raise RuntimeError, "Unable to create Kubernetes connection: #{inspect(reason)}"
  end
end
