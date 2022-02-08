defmodule DomainNameOperator.CloudflareOps do
  def client do
    Application.fetch_env!(:domain_name_operator, :cloudflare_api_token)
    |> CloudflareApi.new()
  end

  def zone_id do
    Application.fetch_env!(:domain_name_operator, :zone_id)
  end

  def record_present?(hostname) do
    CloudflareApi.DnsRecords.hostname_exists?(client(), zone_id(), hostname)
  end

  def get_a_records do
    case CloudflareApi.DnsRecords.list(client(), zone_id()) do
      {:ok, records} -> records
      _ -> []
    end
  end

  def get_a_records(hostname) do
    case CloudflareApi.DnsRecords.list_for_hostname(client(), zone_id(), hostname) do
      {:ok, records} -> records
      _ -> []
    end
  end

  def relevant_a_records(hostname) do
    get_a_records()
    |> Map.get("status")
    |> Map.get("addresses")
    |> Enum.filter(fn a -> a["type"] == "ExternalIP" end)
    |> List.flatten()
  end

  def create_a_record(hostname, ip) do
    CloudflareApi.DnsRecords.create(client(), zone_id(), hostname, ip)
  end

  def remove_a_record(hostname) do
    with {:ok, records} <- get_a_records(hostname) do
      records
      |> Enum.each(
          fn r -> CloudflareApi.DnsRecords.delete(client(), zone_id(), r.id)
        end)
    end
  end

  # TODO:  This should be tested thoroughly with 0, 1, n pre-existing records
  def add_or_update_record(record) do
    # Check if record exists already. We are assuming that only one
    # record will exist for any given hostname
    # First create new record, then delete old record
    prev_recs = get_a_records(record.hostname)

    # record exists yet?  If record does not exist, create one and delete others for this hostname
    unless Enum.any?(prev_recs, fn r -> r.hostname == record.hostname && r.content == record.ip end) do
      create_a_record(record.hostname, record.ip)
      Enum.each(prev_recs, fn r -> delete_record(r) end)
    end
  end

  def delete_record(record) do
    remove_a_record(record.hostname)
  end

  defp record_exists?(recs, record) do

  end
end
