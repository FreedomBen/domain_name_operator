defmodule DomainNameOperator.CloudflareClient.Mock do
  @moduledoc """
  Test implementation of the Cloudflare client.

  This module does not perform any network calls. It returns deterministic
  responses for use in tests of `DomainNameOperator.CloudflareOps`.
  """

  @behaviour DomainNameOperator.CloudflareClient

  alias CloudflareApi.DnsRecord

  @impl true
  def new_client(_api_token), do: :mock_client

  @impl true
  def hostname_exists?(_client, _zone_id, hostname) do
    {:ok, hostname == "existing.example.com"}
  end

  @impl true
  def list_a_records(_client, zone_id) do
    {:ok,
     [
       %DnsRecord{
         id: "rec-1",
         zone_id: zone_id,
         hostname: "existing.example.com",
         zone_name: "example.com",
         ip: "203.0.113.1",
         proxied: true
       }
     ]}
  end

  @impl true
  def list_a_records_for_host_domain(_client, zone_id, host, domain) do
    hostname =
      if String.ends_with?(host, "." <> domain) do
        host
      else
        "#{host}.#{domain}"
      end

    case {host, domain} do
      {"cached-host", "example.com"} ->
        {:ok,
         [
           %DnsRecord{
             id: "rec-cached",
             zone_id: zone_id,
             hostname: hostname,
             zone_name: "example.com",
             ip: "203.0.113.2",
             proxied: false
           }
         ]}

      {existing_host, "example.com"} when existing_host in ["existing", "existing.example.com"] ->
        {:ok,
         [
           %DnsRecord{
             id: "rec-existing",
             zone_id: zone_id,
             hostname: "existing.example.com",
             zone_name: "example.com",
             ip: "203.0.113.1",
             proxied: true
           }
         ]}

      {no_records, _} when no_records in ["no-records", "no-records.example.com"] ->
        {:ok, []}

      _ ->
        {:ok,
         [
           %DnsRecord{
             id: "rec-2",
             zone_id: zone_id,
             hostname: hostname,
             zone_name: domain,
             ip: "203.0.113.3",
             proxied: true
           }
         ]}
    end
  end

  @impl true
  def create_a_record(_client, _zone_id, %DnsRecord{} = record) do
    {:ok, Map.put(record, :id, "created-id")}
  end

  @impl true
  def delete_a_record(_client, _zone_id, _id) do
    {:ok, %{}}
  end
end
