defmodule DomainNameOperator.CloudflareOps do
  alias DomainNameOperator.Utils.Logger
  alias DomainNameOperator.{Utils, Cache, Notifier}
  alias DomainNameOperator.Notifier.Event
  alias DomainNameOperator.CloudflareClient

  # TODO:  Add ability to have a default zone ID since some users creating dns
  # records won't be able to get the zone ID
  # def zone_id do
  #   Application.fetch_env!(:domain_name_operator, :cloudflare_zone_id)
  # end

  def record_present?(zone_id, hostname) do
    Logger.notice("[record_present?]:  zone_id='#{zone_id}', hostname='#{hostname}'")

    with {:ok, zone_id} <- require_zone_id(zone_id) do
      case cloudflare_client().hostname_exists?(client(), zone_id, hostname) do
        {:ok, exists?} ->
          exists?

        {:error, err} ->
          Logger.error("[record_present?/2]: error - #{Utils.to_string(err)}")
          false
      end
    else
      {:error, :missing_zone_id} ->
        Logger.error("[record_present?/2]: missing zone id for hostname '#{hostname}'")
        false
    end
  end

  def get_a_records(zone_id) do
    Logger.notice("[get_a_records]: all - zone_id='#{zone_id}'")

    with {:ok, zone_id} <- require_zone_id(zone_id) do
      case cloudflare_client().list_a_records(client(), zone_id) do
        {:ok, records} ->
          records

        err ->
          Logger.error("[get_a_records/0 all]: error - #{Utils.to_string(err)}")
          []
      end
    else
      {:error, :missing_zone_id} ->
        Logger.error("[get_a_records/0 all]: missing zone id; returning empty list")
        []
    end
  end

  def get_a_records(zone_id, host, domain) do
    with {:ok, zone_id} <- require_zone_id(zone_id) do
      case Cache.get_records(host) do
        nil ->
          Logger.notice(
            "[get_a_records]: host='#{host}', domain='#{domain}', zone_id='#{zone_id}'"
          )

          case cloudflare_client().list_a_records_for_host_domain(client(), zone_id, host, domain) do
            {:ok, records} ->
              # Logger.info(__ENV__, "Adding records to cache")
              Logger.trace(__ENV__, "Adding records to cache for hostname '#{host}'")
              Cache.add_records(host, records)
              records

            err ->
              Logger.error("[get_a_records/1 hostname]: error - #{Utils.to_string(err)}")
              IO.inspect(err)
              []
          end

        records ->
          Logger.info(__ENV__, "Serving hostname '#{host}' records from cache")
          records
      end
    else
      {:error, :missing_zone_id} ->
        Logger.error(
          "[get_a_records/3]: missing zone id for host='#{host}', domain='#{domain}'; returning empty list"
        )

        []
    end
  end

  def relevant_a_records(zone_id, host, domain) do
    Logger.debug("[relevant_a_records]: zone_id='#{zone_id}' host='#{host}' domain='#{domain}'")

    case get_a_records(zone_id, host, domain) do
      %{"status" => %{"addresses" => addresses}} ->
        addresses
        |> Enum.filter(fn a -> a["type"] == "ExternalIP" end)
        |> List.flatten()

      other ->
        Logger.error(
          "[relevant_a_records]: expected service-like map but received '#{Utils.to_string(other)}'"
        )

        []
    end
  end

  def create_a_record(%CloudflareApi.DnsRecord{} = record) do
    Logger.notice("[create_a_record]: record='#{Utils.to_string(record)}'")

    with {:ok, zone_id} <- require_zone_id(record.zone_id) do
      record = ensure_zone_id(record, zone_id)

      case cloudflare_client().create_a_record(client(), zone_id, record) do
        {:ok, retval} ->
          Logger.notice(
            "[create_a_records/2]: Created A record.  Cloudflare response: #{Utils.to_string(retval)}"
          )

          {:ok, retval}

        {:error, errs} ->
          Logger.error("[create_a_records/2]: error - #{Utils.to_string(errs)}")
          {:error, errs}
      end
    else
      {:error, :missing_zone_id} = err ->
        Logger.error(
          "[create_a_records/2]: missing zone id for record='#{Utils.to_string(record)}'"
        )

        err
    end
  end

  # def create_a_record(zone_id, hostname, ip, proxied) do
  #   Logger.notice("[create_a_record]: hostname='#{hostname}' ip='#{ip}' proxied='#{proxied}'")

  #   case CloudflareApi.DnsRecords.create(client(), zone_id, hostname, ip, proxied) do
  #     {:ok, retval} ->
  #       Logger.notice(
  #         "[create_a_records/2]: Created A record.  Cloudflare response: #{Utils.to_string(retval)}"
  #       )

  #       {:ok, retval}

  #     {:error, errs} ->
  #       Logger.error("[create_a_records/2]: error - #{Utils.to_string(errs)}")
  #       {:error, errs}
  #   end
  # end

  # TODO:  This should be tested thoroughly with 0, 1, n pre-existing records
  def add_or_update_record(record) do
    Logger.debug("[add_or_update_record]: record='#{Utils.to_string(record)}'")

    # Logger.info(__ENV__, "Deleting cache for hostname #{record.hostname}")
    # Cache.delete_records(record.hostname)

    # Check if record exists already. We are assuming that only one
    # record will exist for any given hostname
    # First create new record, then delete old record

    with {:ok, zone_id} <- require_zone_id(record.zone_id) do
      record = ensure_zone_id(record, zone_id)
      host = host_for_lookup(record)
      prev_recs = get_a_records(zone_id, host, record.zone_name)

      Logger.info(
        "[add_or_update_record]: Retrieved #{Enum.count(prev_recs)} matching records from CloudFlare for " <>
          "zone_id='#{zone_id}', hostname='#{record.hostname}', zone_name='#{record.zone_name}', proxied='#{record.proxied}': " <>
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
          action = if Enum.empty?(prev_recs), do: :created, else: :updated

          Logger.debug(
            Utils.FromEnv.mfa_str(__ENV__) <>
              ": No entry exists for '" <>
              record.hostname <>
              "' for ip '" <> record.ip <> "'.  Adding one.  record: " <> Utils.to_string(record)
          )

          with :ok <- delete_records(prev_recs, :delete_all_matching, notify?: false),
               {:ok, retval} <- create_a_record(record) do
            metadata = %{previous_records: prev_recs, response: retval}
            notify_change(action, event_record(record, retval), metadata, [])

            {:ok, retval}
          else
            {:error, error} -> {:error, error}
            :error -> {:error, :delete_records}
          end
      end
    else
      {:error, :missing_zone_id} = err ->
        Logger.error(
          "[add_or_update_record]: missing zone id for record='#{Utils.to_string(record)}'"
        )

        err
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
  def delete_record(record, multiple_match_behavior \\ :log_error, opts \\ [])
  def delete_record(%CloudflareApi.DnsRecord{id: nil} = record, multiple_match_behavior, opts) do
    Logger.debug(
      "[delete_record] id is nil [1]:  multiple_match_behavior='#{multiple_match_behavior}', record='#{Utils.to_string(record)}'"
    )

    with {:ok, zone_id} <- require_zone_id(record.zone_id) do
      recs =
        zone_id
        |> get_a_records(host_for_lookup(record), record.zone_name)
        |> Enum.map(&ensure_zone_id(&1, zone_id))

      Logger.debug(
        "[delete_record] id is nil [2]: number of matching records is '#{Enum.count(recs)}' - recs='#{Utils.to_string(recs)}"
      )

      cond do
        Enum.count(recs) == 1 ->
          delete_record(List.first(recs), multiple_match_behavior, opts)

        multiple_match_behavior == :delete_all_matching ->
          delete_records(recs, multiple_match_behavior, opts)

        true ->
          Logger.error(
            __ENV__,
            ": When retrieving record ID for a record that we are deleting, got either zero or more than one matching record.  Because of this it's ambiguous which record should be deleted.  The only safe thing to do is delete nothing but raise an error.  If you wish to delete all matching records, either use #delete_records or pass :delete_all_matching"
          )
      end
    else
      {:error, :missing_zone_id} = err ->
        Logger.error("[delete_record]: missing zone id for record='#{Utils.to_string(record)}'")

        err
    end
  end

  # Returns {:ok, _} | {:error, errs}
  def delete_record(record, _multiple_match_behavior, opts) do
    Logger.warning("[delete_record]: record='#{Utils.to_string(record)}'")

    with {:ok, zone_id} <- require_zone_id(record.zone_id) do
      record = ensure_zone_id(record, zone_id)

      Logger.notice(__ENV__, "Dropping record for '#{record.hostname}' from cache")
      Cache.delete_records(record.hostname)

      with {:ok, resp} = result <-
             cloudflare_client().delete_a_record(client(), zone_id, record.id) do
        notify_change(:deleted, record, %{response: resp}, opts)

        result
      end
    else
      {:error, :missing_zone_id} = err ->
        Logger.error("[delete_record]: missing zone id for record='#{Utils.to_string(record)}'")

        err
    end
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
  def delete_records(records, multiple_match_behavior \\ :log_error, opts \\ [])
  def delete_records(records, multiple_match_behavior, opts) when is_list(records) do
    Logger.debug(
      "[delete_records]: multiple_match_behavior='#{multiple_match_behavior}', records='#{Utils.to_string(records)}'"
    )

    success =
      records
      |> Enum.map(fn r -> delete_record(r, multiple_match_behavior, opts) end)
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

  def delete_records(zone_id, host, domain), do: delete_records(zone_id, host, domain, [])

  def delete_records(zone_id, host, domain, opts) do
    Logger.warning("[delete_records]: zone_id='#{zone_id}', host='#{host}', domain='#{domain}'")

    with {:ok, zone_id} <- require_zone_id(zone_id) do
      zone_id
      |> get_a_records(host, domain)
      |> delete_records(:log_error, opts)
    else
      {:error, :missing_zone_id} = err ->
        Logger.error("[delete_records/3]: missing zone id for host='#{host}', domain='#{domain}'")
        err
    end
  end

  defp host_for_lookup(%CloudflareApi.DnsRecord{hostname: hostname, zone_name: zone_name}) do
    suffix =
      case zone_name do
        z when is_binary(z) and z != "" -> "." <> z
        _ -> nil
      end

    cond do
      is_binary(hostname) && is_binary(suffix) && String.ends_with?(hostname, suffix) ->
        String.trim_trailing(hostname, suffix)

      true ->
        hostname
    end
  end

  defp event_record(original, response) do
    original
    |> resolve_response_record(response)
    |> ensure_zone_id(original.zone_id)
  end

  defp resolve_response_record(_original, %CloudflareApi.DnsRecord{} = response), do: response

  defp resolve_response_record(original, response) when is_map(response) do
    try do
      CloudflareApi.DnsRecord.from_cf_json(response)
    rescue
      _ -> original
    end
  end

  defp resolve_response_record(original, _response), do: original

  defp notify_change(action, record, metadata, opts) do
    if Keyword.get(opts, :notify?, true) do
      event = %Event{action: action, record: record, metadata: normalize_metadata(metadata)}

      case Notifier.notify(event) do
        :ok ->
          :ok

        {:error, reason} ->
          Logger.error(__ENV__, "Notifier failed for #{action}: #{Utils.to_string(reason)}")
          :ok
      end
    else
      :ok
    end
  end

  defp normalize_metadata(metadata) when is_map(metadata), do: metadata
  defp normalize_metadata(metadata) when is_list(metadata), do: Map.new(metadata)
  defp normalize_metadata(_metadata), do: %{}

  defp record_exists?(recs, record) do
    Logger.debug("[record_exists?]: record='#{Utils.to_string(record)}'")

    Enum.any?(recs, fn r ->
      # For now, don't check the zone ID as it may not get returned by the Cloudflare API
      # r.zone_id == record.zone_id && r.hostname == record.hostname && r.ip == record.ip &&
      #   r.proxied == record.proxied
      r.hostname == record.hostname && r.ip == record.ip &&
        r.proxied == record.proxied
    end)
  end

  defp client do
    api_token = Application.fetch_env!(:domain_name_operator, :cloudflare_api_token)
    cloudflare_client().new_client(api_token)
  end

  defp cloudflare_client do
    Application.get_env(:domain_name_operator, :cloudflare_client, CloudflareClient)
  end

  defp require_zone_id(zone_id) do
    case zone_id_or_default(zone_id) do
      z when is_binary(z) and z != "" ->
        {:ok, z}

      _ ->
        Logger.error(
          __ENV__,
          "Missing Cloudflare zone id; set one on the record or configure a default"
        )

        {:error, :missing_zone_id}
    end
  end

  defp ensure_zone_id(%CloudflareApi.DnsRecord{zone_id: zone_id} = record, _fallback)
       when is_binary(zone_id) and zone_id != "" do
    record
  end

  defp ensure_zone_id(%CloudflareApi.DnsRecord{} = record, fallback_zone_id)
       when is_binary(fallback_zone_id) and fallback_zone_id != "" do
    %{record | zone_id: fallback_zone_id}
  end

  defp ensure_zone_id(record, _fallback) do
    case default_zone_id() do
      nil -> record
      "" -> record
      zone_id -> %{record | zone_id: zone_id}
    end
  end

  defp zone_id_or_default(zone_id) do
    cond do
      is_binary(zone_id) and zone_id != "" -> zone_id
      true -> default_zone_id()
    end
  end

  defp default_zone_id do
    Application.get_env(:domain_name_operator, :cloudflare_default_zone_id)
  end
end
