defmodule DomainNameOperator.Notifiers.SlackTest do
  use ExUnit.Case, async: false

  alias DomainNameOperator.Notifier.Event
  alias DomainNameOperator.Notifiers.Slack
  alias CloudflareApi.DnsRecord

  defmodule SlackHttpClientStub do
    @behaviour DomainNameOperator.Notifiers.Slack.HttpClient

    def put_response(resp), do: Process.put({__MODULE__, :response}, resp)

    @impl true
    def post(path, body, opts) do
      send(self(), {:http_post, path, body, opts})
      Process.get({__MODULE__, :response}, {:ok, %Tesla.Env{status: 200, body: %{"ok" => true}}})
    end
  end

  setup do
    original_http = Application.get_env(:domain_name_operator, :slack_http_client)
    original_config = Application.get_env(:domain_name_operator, :slack_notifier)

    Application.put_env(:domain_name_operator, :slack_http_client, SlackHttpClientStub)

    Application.put_env(:domain_name_operator, :slack_notifier,
      token: "slack-token",
      channel: "#dns-alerts",
      username: "dns-operator",
      icon_emoji: ":robot_face:"
    )

    on_exit(fn ->
      Application.put_env(:domain_name_operator, :slack_http_client, original_http)
      Application.put_env(:domain_name_operator, :slack_notifier, original_config)
    end)

    :ok
  end

  test "posts formatted payload and returns :ok on success" do
    event = %Event{action: :created, record: dns_record(), metadata: %{}}

    assert :ok = Slack.notify(event)

    assert_receive {:http_post, "/api/chat.postMessage", body, opts}

    assert body[:token] == "slack-token"
    assert body[:channel] == "#dns-alerts"
    assert body[:username] == "dns-operator"
    assert body[:icon_emoji] == ":robot_face:"
    assert String.contains?(body[:text], "Created DNS A record example.com")

    assert Enum.any?(Keyword.get(opts, :headers), fn {key, _} ->
             String.downcase(key) == "content-type"
           end)
  end

  test "surfaces Slack API error responses" do
    SlackHttpClientStub.put_response(
      {:ok, %Tesla.Env{status: 200, body: %{"ok" => false, "error" => "channel_not_found"}}}
    )

    event = %Event{action: :updated, record: dns_record(), metadata: %{}}

    assert {:error, {:slack_error, "channel_not_found"}} = Slack.notify(event)
  end

  test "returns http_error tuple on non-2xx responses" do
    SlackHttpClientStub.put_response({:ok, %Tesla.Env{status: 500, body: "internal"}})

    event = %Event{action: :deleted, record: dns_record(), metadata: %{}}

    assert {:error, {:http_error, 500, "internal"}} = Slack.notify(event)
  end

  test "returns missing_config when required fields are absent" do
    Application.put_env(:domain_name_operator, :slack_notifier,
      token: "",
      channel: nil
    )

    event = %Event{action: :created, record: dns_record(), metadata: %{}}

    assert {:error, {:missing_config, :token}} = Slack.notify(event)
  end

  defp dns_record do
    %DnsRecord{
      id: "dns-123",
      zone_id: "zone-1",
      hostname: "example.com",
      zone_name: "example.com",
      ip: "203.0.113.10",
      proxied: true
    }
  end
end
