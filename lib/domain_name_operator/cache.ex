defmodule DomainNameOperator.Cache do
  use Agent

  alias DomainNameOperator.CacheEntry

  alias DomainNameOperator.Utils.Logger

  @expire_seconds 180

  def start_link(_initial_value) do
    Logger.debug(__ENV__, "Starting Cache link")
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def add_records(hostname, records) do
    Agent.update(__MODULE__, fn state ->
      cond do
        records == [] ->
          Map.delete(state, hostname)

        true ->
          Map.put(state, hostname, %CacheEntry{timestamp: cur_seconds(), records: records})
      end
    end)
  end

  def delete_records(hostname) do
    Agent.update(__MODULE__, fn state ->
      Map.delete(state, hostname)
    end)
  end

  def get_records(hostname) do
    Agent.get(__MODULE__, fn state ->
      cond do
        Map.has_key?(state, hostname) && !expired?(state, hostname) ->
          case state[hostname].records do
            [] -> nil
            records -> records
          end

        true -> nil
      end
    end)
  end

  defp cur_seconds() do
    System.monotonic_time(:second)
  end

  defp expired?(state, hostname) do
    cond do
      Map.has_key?(state, hostname) -> state[hostname].timestamp + @expire_seconds < cur_seconds()
      true -> false
    end
  end
end
