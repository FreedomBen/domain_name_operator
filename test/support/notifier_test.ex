defmodule DomainNameOperator.Notifier.Test do
  @behaviour DomainNameOperator.Notifier

  @impl true
  def notify(event) do
    send(self(), {:notified, event})
    :ok
  end
end

defmodule DomainNameOperator.Notifier.FailingTest do
  @behaviour DomainNameOperator.Notifier

  @impl true
  def notify(event) do
    send(self(), {:notified, event})
    {:error, :failing_notifier}
  end
end
