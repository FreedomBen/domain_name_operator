defmodule DomainNameOperator.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    maybe_attach_sentry_backend()

    children =
      [
        {DomainNameOperator.Cache, []}
      ]
      |> maybe_add_operator()

    opts = [strategy: :one_for_one, name: DomainNameOperator.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp maybe_attach_sentry_backend do
    if DomainNameOperator.SentryClient.enabled?() do
      Logger.add_backend(Sentry.LoggerBackend)
    end
  end

  defp maybe_add_operator(children) do
    if Application.get_env(:domain_name_operator, :enable_operator, true) do
      operator_opts =
        [conn: DomainNameOperator.K8sConn.get!()]
        |> maybe_put_watch_namespace()

      children ++ [{DomainNameOperator.Operator, operator_opts}]
    else
      children
    end
  end

  defp maybe_put_watch_namespace(opts) do
    case Application.get_env(:domain_name_operator, :watch_namespace) do
      nil -> opts
      namespace -> Keyword.put(opts, :watch_namespace, namespace)
    end
  end
end
