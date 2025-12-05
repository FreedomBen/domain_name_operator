defmodule DomainNameOperator.Notifiers.Noop do
  @moduledoc """
  Default notifier that intentionally does nothing.
  """

  @behaviour DomainNameOperator.Notifier

  @impl true
  def notify(_event), do: :ok
end
