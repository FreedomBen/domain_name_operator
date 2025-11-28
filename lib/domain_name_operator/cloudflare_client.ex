defmodule DomainNameOperator.CloudflareClient do
  @moduledoc """
  Behaviour and default implementation for Cloudflare API access.

  `DomainNameOperator.CloudflareOps` depends on this module instead of calling
  `CloudflareApi` directly, so tests can substitute a mock implementation that
  never talks to the real Cloudflare API.
  """

  @type client :: any()
  @type zone_id :: String.t()
  @type hostname :: String.t()

  @callback new_client(api_token :: String.t()) :: client()

  @callback hostname_exists?(client(), zone_id(), hostname()) ::
              {:ok, boolean()} | {:error, any()}

  @callback list_a_records(client(), zone_id()) :: {:ok, list()} | {:error, any()}

  @callback list_a_records_for_host_domain(client(), zone_id(), hostname(), String.t()) ::
              {:ok, list()} | {:error, any()}

  @callback create_a_record(client(), zone_id(), CloudflareApi.DnsRecord.t()) ::
              {:ok, any()} | {:error, any()}

  @callback delete_a_record(client(), zone_id(), String.t()) ::
              {:ok, any()} | {:error, any()}

  @behaviour __MODULE__

  @impl true
  def new_client(api_token) do
    CloudflareApi.new(api_token)
  end

  @impl true
  def hostname_exists?(client, zone_id, hostname) do
    CloudflareApi.DnsRecords.hostname_exists?(client, zone_id, hostname)
  end

  @impl true
  def list_a_records(client, zone_id) do
    CloudflareApi.DnsRecords.list(client, zone_id)
  end

  @impl true
  def list_a_records_for_host_domain(client, zone_id, host, domain) do
    CloudflareApi.DnsRecords.list_for_host_domain(client, zone_id, host, domain)
  end

  @impl true
  def create_a_record(client, zone_id, %CloudflareApi.DnsRecord{} = record) do
    CloudflareApi.DnsRecords.create(client, zone_id, record)
  end

  @impl true
  def delete_a_record(client, zone_id, id) do
    CloudflareApi.DnsRecords.delete(client, zone_id, id)
  end
end

