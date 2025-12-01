defmodule DomainNameOperator.SentryClient.Test do
  @moduledoc """
  Test implementation of the Sentry client that records calls in the test
  process instead of sending anything over the network.
  """

  @behaviour DomainNameOperator.SentryClient

  @impl true
  def capture_exception(exception, options) do
    send(self(), {:sentry_called, exception, options})
    {:ok, :sent}
  end
end

defmodule DomainNameOperator.SentryClient.FailingTest do
  @moduledoc """
  Test implementation of the Sentry client that always fails. Useful for
  exercising the error logging path in `process_record_exception/4`.
  """

  @behaviour DomainNameOperator.SentryClient

  @impl true
  def capture_exception(_exception, _options) do
    {:error, :failed_to_send}
  end
end
