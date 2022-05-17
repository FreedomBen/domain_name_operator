defmodule DomainNameOperator.CacheEntry do
  @moduledoc """
  """

  defstruct [:timestamp, :records]

  @type t :: %__MODULE__{
          timestamp: integer(),
          records: [CloudflareApi.DnsRecord.t()]
        }
end
