defmodule DomainNameOperator.Notifier.Event do
  @moduledoc """
  Struct describing a notification-worthy event.
  """

  @typedoc "Type of change applied to a DNS record."
  @type action :: :created | :updated | :deleted

  @enforce_keys [:action, :record]
  defstruct [:action, :record, metadata: %{}]

  @type t :: %__MODULE__{
          action: action(),
          record: CloudflareApi.DnsRecord.t(),
          metadata: map()
        }
end

defmodule DomainNameOperator.Notifier do
  @moduledoc """
  Behaviour and dispatch module for outbound notifications (e.g., Slack).

  Use `notify/1` with a `DomainNameOperator.Notifier.Event` and configure
  `:domain_name_operator, :notifier` to choose the concrete implementation.
  """

  alias DomainNameOperator.Notifier.Event

  @type notifier_module :: module()

  @callback notify(Event.t()) :: :ok | {:error, term()}

  def notify(%Event{} = event) do
    notifier().notify(event)
  end

  def notifier do
    Application.get_env(:domain_name_operator, :notifier, DomainNameOperator.Notifiers.Noop)
  end
end
