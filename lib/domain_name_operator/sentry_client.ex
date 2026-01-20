defmodule DomainNameOperator.SentryClient do
  @moduledoc """
  Behaviour and default implementation for sending exceptions to Sentry.

  `DomainNameOperator.Controller.V1.CloudflareDnsRecord` depends on this
  module instead of the `Sentry` module directly so tests can substitute a
  lightweight implementation that does not talk to the network.
  """

  @type exception :: Exception.t()
  @type options :: keyword()

  @callback capture_exception(exception(), options()) ::
              {:ok, any()} | {:error, any()}

  @behaviour __MODULE__

  @spec enabled?() :: boolean()
  def enabled? do
    case Application.fetch_env(:sentry, :dsn) do
      {:ok, dsn} when is_binary(dsn) -> String.trim(dsn) != ""
      _ -> false
    end
  end

  @impl true
  def capture_exception(exception, options) do
    if enabled?() do
      Sentry.capture_exception(exception, options)
    else
      {:ok, :disabled}
    end
  end
end
