defmodule Mix.Tasks.K8s.Openapi.Fetch do
  @moduledoc """
  Download the latest Kubernetes OpenAPI (swagger.json) specification.

  The spec is stored under `priv/openapi/kubernetes/swagger.json` for use in
  tests and tooling (for example, mocking Kubernetes API calls).
  """

  use Mix.Task

  @shortdoc "Fetch the latest Kubernetes OpenAPI spec (swagger.json)."

  @k8s_openapi_url "https://raw.githubusercontent.com/kubernetes/kubernetes/refs/heads/master/api/openapi-spec/swagger.json"

  @impl Mix.Task
  def run(_args) do
    Mix.shell().info("Downloading Kubernetes OpenAPI spec from #{@k8s_openapi_url}...")

    :ok = ensure_http_started()

    case :httpc.request(:get, {@k8s_openapi_url |> to_charlist(), []}, [], body_format: :binary) do
      {:ok, {{_, 200, _}, _headers, body}} ->
        dest_dir = Path.join(["priv", "openapi", "kubernetes"])
        File.mkdir_p!(dest_dir)

        dest_path = Path.join(dest_dir, "swagger.json")
        File.write!(dest_path, body)

        Mix.shell().info("Saved Kubernetes OpenAPI spec to #{dest_path}")

      {:ok, {{_, status, _}, _headers, body}} ->
        Mix.raise(
          "Failed to download OpenAPI spec. HTTP status: #{status}. Body: #{inspect(body)}"
        )

      {:error, reason} ->
        Mix.raise("Failed to download OpenAPI spec: #{inspect(reason)}")
    end
  end

  defp ensure_http_started do
    _ = Application.ensure_all_started(:inets)
    _ = Application.ensure_all_started(:ssl)
    :ok
  end
end
