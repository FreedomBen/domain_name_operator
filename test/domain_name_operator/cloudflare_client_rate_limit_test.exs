defmodule DomainNameOperator.CloudflareClientRateLimitTest do
  use ExUnit.Case, async: false

  alias CloudflareApi.DnsRecord
  alias DomainNameOperator.CloudflareClient

  setup do
    original_retry = Application.get_env(:domain_name_operator, :cloudflare_rate_limit_retry)
    original_adapter = Application.get_env(:tesla, :adapter)

    Application.put_env(:tesla, :adapter, Tesla.Mock)

    on_exit(fn ->
      restore_retry_env(original_retry)
      restore_adapter(original_adapter)
    end)

    :ok
  end

  test "builds clients with rate-limit retry middleware enabled by default" do
    Application.delete_env(:domain_name_operator, :cloudflare_rate_limit_retry)

    client = CloudflareClient.new_client("token")

    assert %Tesla.Client{pre: pre} = client

    assert Enum.any?(pre, fn
             {CloudflareApi.RateLimitRetry, :call, [_opts]} -> true
             _ -> false
           end)
  end

  test "retries 429 responses honoring Retry-After headers" do
    Application.put_env(:domain_name_operator, :cloudflare_rate_limit_retry,
      max_retries: 2,
      jitter: 0.0,
      sleep: &record_sleep/1
    )

    Tesla.Mock.mock(fn
      %{method: :get, url: "https://api.cloudflare.com/client/v4/zones/zone-1/dns_records"} ->
        case bump(:retry_after_calls) do
          1 -> {:ok, rate_limited_env("zone-1", [{"Retry-After", "2"}])}
          _ -> {:ok, dns_records_env("zone-1")}
        end
    end)

    client = CloudflareClient.new_client("token")

    assert {:ok, [%DnsRecord{} = record]} = CloudflareClient.list_a_records(client, "zone-1")
    assert record.zone_id == "zone-1"
    assert_received {:slept, 2_000}
    refute_received {:slept, _}
  end

  test "stops retrying after configured attempts" do
    Application.put_env(:domain_name_operator, :cloudflare_rate_limit_retry,
      max_retries: 2,
      base_backoff: 50,
      jitter: 0.0,
      sleep: &record_sleep/1
    )

    Tesla.Mock.mock(fn
      %{method: :get, url: "https://api.cloudflare.com/client/v4/zones/zone-2/dns_records"} ->
        {:ok, rate_limited_env("zone-2")}
    end)

    client = CloudflareClient.new_client("token")

    assert {:error, {:ok, %Tesla.Env{status: 429}}} =
             CloudflareClient.list_a_records(client, "zone-2")

    assert_received {:slept, 50}
    assert_received {:slept, 100}
    refute_received {:slept, _}
  end

  defp record_sleep(ms) do
    send(self(), {:slept, ms})
    :ok
  end

  defp dns_records_env(zone_id) do
    %Tesla.Env{
      method: :get,
      url: "https://api.cloudflare.com/client/v4/zones/#{zone_id}/dns_records",
      status: 200,
      body: %{
        "result" => [
          %{
            "id" => "rec-#{zone_id}",
            "zone_id" => zone_id,
            "zone_name" => "example.com",
            "name" => "example.com",
            "content" => "203.0.113.10",
            "proxied" => false,
            "type" => "A"
          }
        ]
      }
    }
  end

  defp bump(key) do
    current = Process.get(key, 0) + 1
    Process.put(key, current)
    current
  end

  defp rate_limited_env(zone_id, headers \\ []) do
    %Tesla.Env{
      method: :get,
      url: "https://api.cloudflare.com/client/v4/zones/#{zone_id}/dns_records",
      headers: headers,
      status: 429
    }
  end

  defp restore_retry_env(nil),
    do: Application.delete_env(:domain_name_operator, :cloudflare_rate_limit_retry)

  defp restore_retry_env(value),
    do: Application.put_env(:domain_name_operator, :cloudflare_rate_limit_retry, value)

  defp restore_adapter(nil), do: Application.delete_env(:tesla, :adapter)
  defp restore_adapter(value), do: Application.put_env(:tesla, :adapter, value)
end
