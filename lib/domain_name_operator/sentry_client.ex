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

  @impl true
  def capture_exception(exception, options) do
    Sentry.capture_exception(exception, options)
  end
end

