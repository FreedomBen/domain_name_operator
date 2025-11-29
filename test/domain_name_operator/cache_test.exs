defmodule DomainNameOperator.CacheTest do
  use ExUnit.Case, async: false

  alias DomainNameOperator.Cache
  alias DomainNameOperator.CacheEntry

  setup do
    case Process.whereis(DomainNameOperator.Cache) do
      nil -> {:ok, _pid} = Cache.start_link([])
      _pid -> :ok
    end

    :ok
  end

  test "add_records/2 then get_records/1 returns stored records" do
    hostname = "example-host"
    records = [:one, :two]

    Cache.add_records(hostname, records)
    assert Cache.get_records(hostname) == records
  end

  test "delete_records/1 removes cached entry" do
    hostname = "to-delete"
    Cache.add_records(hostname, [:record])
    assert Cache.get_records(hostname) != nil

    Cache.delete_records(hostname)
    assert Cache.get_records(hostname) == nil
  end

  test "expired entries are treated as missing" do
    hostname = "expired-host"
    past_timestamp = System.monotonic_time(:second) - 200

    Agent.update(DomainNameOperator.Cache, fn _state ->
      %{
        hostname => %CacheEntry{
          timestamp: past_timestamp,
          records: [:stale_record]
        }
      }
    end)

    assert Cache.get_records(hostname) == nil
  end
end

