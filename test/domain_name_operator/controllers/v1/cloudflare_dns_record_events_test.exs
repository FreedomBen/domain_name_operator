defmodule DomainNameOperator.Controller.V1.CloudflareDnsRecordEventsTest do
  @moduledoc false
  use ExUnit.Case, async: false

  alias Bonny.Axn
  alias CloudflareApi.DnsRecord
  alias DomainNameOperator.Controller.V1.CloudflareDnsRecord

  defmodule CloudflareOpsEventStub do
    @moduledoc false

    def add_or_update_record(%DnsRecord{} = record) do
      send(self(), {:add_or_update_record, record})
      {:ok, %{id: "cf-created", hostname: record.hostname}}
    end

    def delete_record(%DnsRecord{} = record) do
      send(self(), {:delete_record, record})
      {:ok, %{id: "cf-deleted", hostname: record.hostname}}
    end
  end

  defmodule CloudflareOpsDeleteFailureStub do
    @moduledoc false

    def add_or_update_record(%DnsRecord{} = record) do
      {:ok, %{id: "cf-created", hostname: record.hostname}}
    end

    def delete_record(_record), do: {:error, :api_failure}
  end

  setup do
    # The configured mock client relies on priv/openapi/kubernetes/swagger.json via
    # DomainNameOperator.K8sOpenapi to build Service fixtures that match the real API.
    Application.put_env(:domain_name_operator, :k8s_client, DomainNameOperator.K8sClient.Mock)
    Application.put_env(:domain_name_operator, :cloudflare_ops, CloudflareOpsEventStub)
    Application.put_env(:domain_name_operator, :cloudflare_default_domain, "example.com")
    Application.put_env(:domain_name_operator, :cloudflare_default_zone_id, "zone-123")

    on_exit(fn ->
      Application.delete_env(:domain_name_operator, :k8s_client)
      Application.delete_env(:domain_name_operator, :cloudflare_ops)
      Application.delete_env(:domain_name_operator, :cloudflare_default_domain)
      Application.delete_env(:domain_name_operator, :cloudflare_default_zone_id)
    end)

    {:ok, payload: base_payload()}
  end

  describe "Bonny event callbacks" do
    test "add/1 reconciles a new CloudflareDnsRecord", %{payload: payload} do
      assert {:ok, %DnsRecord{} = record} = CloudflareDnsRecord.add(payload)

      assert record.hostname == "app.example.com"
      assert_receive {:add_or_update_record, ^record}
    end

    test "modify/1 reuses the same reconciliation pipeline", %{payload: payload} do
      assert {:ok, %DnsRecord{} = record} = CloudflareDnsRecord.modify(payload)
      assert_receive {:add_or_update_record, ^record}
    end

    test "reconcile/1 re-processes existing resources", %{payload: payload} do
      assert {:ok, %DnsRecord{} = record} = CloudflareDnsRecord.reconcile(payload)
      assert_receive {:add_or_update_record, ^record}
    end

    test "delete/1 removes the Cloudflare record built from the CR payload", %{
      payload: payload
    } do
      assert {:ok, %DnsRecord{} = record} = CloudflareDnsRecord.delete(payload)
      assert_receive {:delete_record, ^record}
    end
  end

  describe "handle_event/2 pipeline integration" do
    test "reconcile emits a success event and reconciles the DNS record", %{payload: payload} do
      Application.put_env(:domain_name_operator, :cloudflare_ops, CloudflareOpsEventStub)

      axn =
        payload
        |> axn_for(:reconcile)
        |> CloudflareDnsRecord.handle_event([])

      assert Enum.any?(axn.events, &(&1.reason == "CloudflareDnsRecordSynced"))
      assert_receive {:add_or_update_record, %DnsRecord{}}
    end

    test "delete failure emits a warning event", %{payload: payload} do
      Application.put_env(
        :domain_name_operator,
        :cloudflare_ops,
        CloudflareOpsDeleteFailureStub
      )

      axn =
        payload
        |> axn_for(:delete)
        |> CloudflareDnsRecord.handle_event([])

      assert Enum.any?(axn.events, &(&1.reason == "CloudflareDnsRecordDeleteFailed"))
    end
  end

  defp base_payload do
    %{
      "metadata" => %{
        "name" => "my-dns",
        "namespace" => "default"
      },
      "spec" => %{
        "namespace" => "default",
        "serviceName" => "existing-service",
        "hostName" => "app",
        "domain" => "example.com",
        "zoneId" => "zone-123",
        "proxied" => true
      }
    }
  end

  defp axn_for(payload, action) do
    Axn.new!(
      action: action,
      resource: payload,
      conn: DomainNameOperator.K8sConn.get!(),
      controller: {DomainNameOperator.Controller.V1.CloudflareDnsRecord, []},
      operator: DomainNameOperator.Operator
    )
  end
end
