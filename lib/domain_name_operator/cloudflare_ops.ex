defmodule DomainNameOperator.CloudflareOps do
  require Logger
  alias DomainNameOperator.Utils

  def client do
    Application.fetch_env!(:domain_name_operator, :cloudflare_api_token)
    |> CloudflareApi.new()
  end

  # def zone_id do
  #   Application.fetch_env!(:domain_name_operator, :cloudflare_zone_id)
  # end

  def record_present?(zone_id, hostname) do
    CloudflareApi.DnsRecords.hostname_exists?(client(), zone_id, hostname)
  end

  def get_a_records(zone_id) do
    Logger.debug("[get_a_records]: all - zone_id='#{zone_id}'")

    case CloudflareApi.DnsRecords.list(client(), zone_id) do
      {:ok, records} ->
        records

      err ->
        Logger.error("[get_a_records/0 all]: error - #{Utils.to_string(err)}")
        []
    end
  end

  def get_a_records(zone_id, host, domain) do
    Logger.debug("[get_a_records]: host='#{host}', domain='#{domain}', zone_id='#{zone_id}'")

    case CloudflareApi.DnsRecords.list_for_host_domain(client(), zone_id, host, domain) do
      {:ok, records} ->
        records

      err ->
        Logger.error("[get_a_records/1 hostname]: error - #{Utils.to_string(err)}")
        IO.inspect(err)
        []
    end
  end

  def relevant_a_records(zone_id, host, domain) do
    Logger.debug("relevant_a_records: zone_id='#{zone_id}' host='#{host}' domain='#{domain}'")

    get_a_records(zone_id, host, domain)
    |> Map.get("status")
    |> Map.get("addresses")
    |> Enum.filter(fn a -> a["type"] == "ExternalIP" end)
    |> List.flatten()
  end

  def create_a_record(zone_id, hostname, ip) do
    Logger.debug("[create_a_record]: hostname='#{hostname}' ip='#{ip}'")

    case CloudflareApi.DnsRecords.create(client(), zone_id, hostname, ip) do
      {:ok, retval} ->
        Logger.info(
          "[create_a_records/2]: Created A record.  Cloudflare response: #{Utils.to_string(retval)}"
        )

        {:ok, retval}

      {:error, errs} ->
        Logger.error("[create_a_records/2]: error - #{Utils.to_string(errs)}")
        {:error, errs}
    end
  end

  def remove_a_record(zone_id, host, domain) do
    Logger.debug("[remove_a_record]: host='#{host}', domain='#{domain}'")

    with {:ok, records} <- get_a_records(zone_id, host, domain) do
      records
      |> Enum.each(fn r -> CloudflareApi.DnsRecords.delete(client(), zone_id, r.id) end)
    end
  end

  # TODO:  This should be tested thoroughly with 0, 1, n pre-existing records
  def add_or_update_record(record) do
    Logger.debug("[add_or_update_record]: record='#{Utils.to_string(record)}'")

    # Check if record exists already. We are assuming that only one
    # record will exist for any given hostname
    # First create new record, then delete old record

    prev_recs = get_a_records(record.zone_id, record.hostname, record.zone_name)

    Logger.info(
      "[add_or_update_record]: Retrieved #{Enum.count(prev_recs)} matching records from CloudFlare for " <>
      "zone_id='#{record.zone_id}', hostname='#{record.hostname}', zone_name='#{record.zone_name}': " <>
        Utils.to_string(prev_recs)
    )

    cond do
      record_exists?(prev_recs, record) ->
        Logger.info(
          Utils.FromEnv.mfa_str(__ENV__) <>
            ": Entry already exists for '" <>
            record.hostname <>
            "' for ip '" <> record.ip <> "':  record: " <> Utils.to_string(record)
        )

        {:ok, record}

      true ->
        Logger.debug(
          Utils.FromEnv.mfa_str(__ENV__) <>
            ": No entry exists for '" <>
            record.hostname <>
            "' for ip '" <> record.ip <> "'.  Adding one.  record: " <> Utils.to_string(record)
        )

        create_a_record(record.zone_id, record.hostname, record.ip)
        delete_records(prev_recs)
    end
  end

  def delete_records(records) do
    Enum.each(records, fn r -> delete_record(r) end)
  end

  def delete_record(record) do
    Logger.debug("[delete_record]: record='#{Utils.to_string(record)}'")
    remove_a_record(record.zone_id, record.hostname, record.zone_name)
  end

  defp record_exists?(recs, record) do
    Logger.debug("[record_exists?]: record='#{Utils.to_string(record)}'")

    Enum.any?(recs, fn r ->
      r.zone_id == record.zone_id && r.hostname == record.hostname && r.ip == record.ip
    end)
  end
end
