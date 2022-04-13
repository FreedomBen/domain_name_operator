defmodule DomainNameOperator.CloudflareOps do
  alias DomainNameOperator.Utils.Logger
  alias DomainNameOperator.Utils

  def client do
    Application.fetch_env!(:domain_name_operator, :cloudflare_api_token)
    |> CloudflareApi.new()
  end

  # TODO:  Add ability to have a default zone ID since some users creating dns
  # records won't be able to get the zone ID
  # def zone_id do
  #   Application.fetch_env!(:domain_name_operator, :cloudflare_zone_id)
  # end

  def record_present?(zone_id, hostname) do
    Logger.notice("[record_present?]:  zone_id='#{zone_id}', hostname='#{hostname}'")
    CloudflareApi.DnsRecords.hostname_exists?(client(), zone_id, hostname)
  end

  def get_a_records(zone_id) do
    Logger.notice("[get_a_records]: all - zone_id='#{zone_id}'")

    case CloudflareApi.DnsRecords.list(client(), zone_id) do
      {:ok, records} ->
        records

      err ->
        Logger.error("[get_a_records/0 all]: error - #{Utils.to_string(err)}")
        []
    end
  end

  def get_a_records(zone_id, host, domain) do
    Logger.notice("[get_a_records]: host='#{host}', domain='#{domain}', zone_id='#{zone_id}'")

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
    Logger.debug("[relevant_a_records]: zone_id='#{zone_id}' host='#{host}' domain='#{domain}'")

    get_a_records(zone_id, host, domain)
    |> Map.get("status")
    |> Map.get("addresses")
    |> Enum.filter(fn a -> a["type"] == "ExternalIP" end)
    |> List.flatten()
  end

  def create_a_record(zone_id, hostname, ip) do
    Logger.notice("[create_a_record]: hostname='#{hostname}' ip='#{ip}'")

    case CloudflareApi.DnsRecords.create(client(), zone_id, hostname, ip) do
      {:ok, retval} ->
        Logger.notice(
          "[create_a_records/2]: Created A record.  Cloudflare response: #{Utils.to_string(retval)}"
        )

        {:ok, retval}

      {:error, errs} ->
        Logger.error("[create_a_records/2]: error - #{Utils.to_string(errs)}")
        {:error, errs}
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

        with {:ok, retval} <- create_a_record(record.zone_id, record.hostname, record.ip),
             :ok <- delete_records(prev_recs) do
          {:ok, retval}
        else
          {:error, error} -> {:error, error}
          :error -> {:error, :delete_records}
        end
    end
  end

  @doc ~S"""
  Deletes the specified record.

  If the record does *not* have an ID set, then prior to deletion the ID will
  be retrieved through the Cloudflare API.  If more than one record matches, then
  it is ambiguous which record to delete.  To control this behavior, set
  `multiple_match_behavior` to your preference.  :log_error will log the error and
  exit.  :delete_all_matching will delete all of the matching records.  :log_error
  is the default
  """
  def delete_record(record, multiple_match_behavior \\ :log_error)

  def delete_record(%CloudflareApi.DnsRecord{id: nil} = record, multiple_match_behavior) do
    Logger.debug(
      "[delete_record] id is nil [1]:  multiple_match_behavior='#{multiple_match_behavior}', record='#{Utils.to_string(record)}'"
    )

    recs = get_a_records(record.zone_id, record.hostname, record.zone_name)

    Logger.debug(
      "[delete_record] id is nil [2]: number of matching records is '#{Enum.count(recs)}' - recs='#{Utils.to_string(recs)}"
    )

    cond do
      Enum.count(recs) == 1 ->
        delete_record(List.first(recs), multiple_match_behavior)

      multiple_match_behavior == :delete_all_matching ->
        delete_records(recs, multiple_match_behavior)

      true ->
        Logger.error(
          Utils.FromEnv.mfa_str(__ENV__) <>
            ": When retrieving record ID for a record that we are deleting, got more than one matching record.  Because of this it's ambiguous which record should be deleted.  The only safe thing to do is delete nothing but raise an error.  If you wish to delete all matching records, either use #delete_records or pass :delete_all_matching"
        )
    end
  end

  # Returns {:ok, _} | {:error, errs}
  def delete_record(record, _multiple_match_behavior) do
    Logger.warning("[delete_record]: record='#{Utils.to_string(record)}'")
    CloudflareApi.DnsRecords.delete(client(), record.zone_id, record.id)
  end

  @doc ~S"""
  Delete the specified record.

  If the record does *not* have an ID set, then prior to deletion the ID will
  be retrieved through the Cloudflare API.  If more than one record matches, then
  it is ambiguous which record to delete.  To control this behavior, set
  `multiple_match_behavior` to your preference.  :log_error will log the error and
  exit.  :delete_all_matching will delete all of the matching records.  :log_error
  is the default
  """
  def delete_records(records, multiple_match_behavior \\ :log_error) do
    Logger.debug(
      "[delete_records]: multiple_match_behavior='#{multiple_match_behavior}', records='#{Utils.to_string(records)}'"
    )

    success =
      records
      |> Enum.map(fn r -> delete_record(r, multiple_match_behavior) end)
      |> Enum.all?(fn r ->
        case r do
          {:ok, _} -> true
          {:error, _} -> false
        end
      end)

    cond do
      success -> :ok
      true -> :error
    end
  end

  def delete_records(zone_id, host, domain) do
    Logger.warning("[delete_records]: zone_id='#{zone_id}', host='#{host}', domain='#{domain}'")

    with {:ok, records} <- get_a_records(zone_id, host, domain) do
      delete_records(records)
    end
  end

  defp record_exists?(recs, record) do
    Logger.debug("[record_exists?]: record='#{Utils.to_string(record)}'")

    Enum.any?(recs, fn r ->
      r.zone_id == record.zone_id && r.hostname == record.hostname && r.ip == record.ip &&
        r.proxied == record.proxied
    end)
  end
end
