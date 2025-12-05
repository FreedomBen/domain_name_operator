defmodule DomainNameOperator.Notifiers.Slack do
  @moduledoc """
  Slack notifier that posts DNS change events to a chat webhook.

  Configure with:

      config :domain_name_operator, :notifier, DomainNameOperator.Notifiers.Slack
      config :domain_name_operator, :slack_notifier,
        token: System.get_env("SLACK_TOKEN"),
        channel: System.get_env("SLACK_CHANNEL"),
        username: System.get_env("SLACK_USERNAME") || "domain-name-operator",
        icon_emoji: System.get_env("SLACK_ICON_EMOJI") || ":ameelio_blue:"
  """

  @behaviour DomainNameOperator.Notifier

  alias DomainNameOperator.Notifier.Event
  alias DomainNameOperator.Utils
  alias DomainNameOperator.Utils.Logger

  @path "/api/chat.postMessage"

  @impl true
  def notify(%Event{} = event) do
    with {:ok, payload} <- build_payload(event),
         {:ok, response} <- http_client().post(@path, payload, headers: headers()),
         :ok <- normalize_response(response) do
      :ok
    else
      {:error, reason} = err ->
        Logger.error(__ENV__, "Failed to deliver Slack notification: #{Utils.to_string(reason)}")
        err
    end
  end

  defp build_payload(%Event{action: action, record: record, metadata: metadata}) do
    config = slack_config()

    with {:ok, token} <- fetch_required(config, :token),
         {:ok, channel} <- fetch_required(config, :channel),
         {:ok, text} <- format_text(action, record, metadata) do
      {:ok,
       %{
         token: token,
         channel: channel,
         text: text,
         username: Keyword.get(config, :username, "domain-name-operator"),
         icon_emoji: Keyword.get(config, :icon_emoji, ":ameelio_blue:")
       }}
    end
  end

  defp slack_config do
    Application.get_env(:domain_name_operator, :slack_notifier, [])
  end

  defp fetch_required(config, key) do
    case Keyword.get(config, key) do
      val when is_binary(val) and val != "" -> {:ok, val}
      _ -> {:error, {:missing_config, key}}
    end
  end

  defp format_text(action, record, metadata) do
    action_str =
      case action do
        :created -> "Created"
        :updated -> "Updated"
        :deleted -> "Deleted"
      end

    previous_ips =
      metadata
      |> Map.get(:previous_records, [])
      |> Enum.map(& &1.ip)
      |> Enum.reject(&is_nil/1)

    zone =
      case {record.zone_name, record.zone_id} do
        {name, _} when is_binary(name) and name != "" -> name
        {_, id} when is_binary(id) and id != "" -> id
        _ -> "unknown zone"
      end

    proxied =
      case record.proxied do
        true -> "proxied"
        false -> "not proxied"
        _ -> "proxied state unknown"
      end

    parts = [
      "#{action_str} DNS A record",
      blank_fallback(record.hostname, "unknown host"),
      "->",
      blank_fallback(record.ip, "unknown ip"),
      "(#{proxied}, zone #{zone})"
    ]

    extra =
      if previous_ips == [] do
        []
      else
        ["previous IPs: #{Enum.join(previous_ips, ", ")}"]
      end

    {:ok, Enum.join(parts ++ extra, " ")}
  end

  defp blank_fallback(nil, fallback), do: fallback
  defp blank_fallback("", fallback), do: fallback
  defp blank_fallback(val, _fallback), do: to_string(val)

  defp headers do
    [{"content-type", "application/x-www-form-urlencoded"}]
  end

  defp normalize_response(%Tesla.Env{status: status} = env) when status in 200..299 do
    case env.body do
      %{"ok" => true} -> :ok
      %{"ok" => false, "error" => error} -> {:error, {:slack_error, error}}
      %{"ok" => false} -> {:error, :slack_error}
      _ -> :ok
    end
  end

  defp normalize_response(%Tesla.Env{status: status, body: body}),
    do: {:error, {:http_error, status, body}}

  defp normalize_response({:error, reason}), do: {:error, reason}

  defp http_client do
    Application.get_env(
      :domain_name_operator,
      :slack_http_client,
      DomainNameOperator.Notifiers.Slack.HttpClient
    )
  end
end

defmodule DomainNameOperator.Notifiers.Slack.HttpClient do
  @moduledoc false

  @callback post(String.t(), map(), keyword()) ::
              {:ok, Tesla.Env.t()} | {:error, term()}

  def post(path, body, opts \\ []) do
    Tesla.post(client(), path, body, opts)
  end

  defp client do
    middleware = [
      {Tesla.Middleware.BaseUrl, "https://slack.com"},
      Tesla.Middleware.FormUrlencoded,
      Tesla.Middleware.JSON
    ]

    Tesla.client(middleware)
  end
end
