defmodule DomainNameOperator.Controller.V1.CloudflareDnsRecordStatusTest do
  use ExUnit.Case, async: false

  alias Bonny.Axn
  alias CloudflareApi.DnsRecord
  alias DomainNameOperator.Controller.V1.CloudflareDnsRecord

  defmodule CloudflareOpsSuccessMock do
    def add_or_update_record(%DnsRecord{} = record), do: {:ok, %{record | id: "cf-id"}}
    def delete_record(%DnsRecord{} = record), do: {:ok, %{record | id: record.id || "cf-id"}}
  end

  defmodule CloudflareOpsFailureMock do
    def add_or_update_record(_record), do: {:error, :boom}
    def delete_record(_record), do: {:error, :boom}
  end

  setup do
    original_ops = Application.get_env(:domain_name_operator, :cloudflare_ops)
    original_k8s = Application.get_env(:domain_name_operator, :k8s_client)

    on_exit(fn ->
      Application.put_env(:domain_name_operator, :cloudflare_ops, original_ops)
      Application.put_env(:domain_name_operator, :k8s_client, original_k8s)
    end)

    Application.put_env(:domain_name_operator, :k8s_client, DomainNameOperator.K8sClient.Mock)
    :ok
  end

  describe "status updates on success" do
    setup do
      Application.put_env(:domain_name_operator, :cloudflare_ops, CloudflareOpsSuccessMock)
      :ok
    end

    test "records cloudflare snapshot and history on add" do
      resource = base_resource()

      axn =
        resource
        |> axn_for(:add)
        |> CloudflareDnsRecord.handle_event([])

      status = axn.status

      assert status["observedGeneration"] == 3
      assert get_in(status, ["cloudflare", "state"]) == "present"
      assert get_in(status, ["cloudflare", "hostname"]) == "app.example.com"
      assert get_in(status, ["cloudflare", "recordId"]) == "cf-id"
      assert get_in(status, ["sync", "lastError"]) == %{}

      [latest | _] = status["history"]
      assert latest["status"] == "success"
      assert latest["action"] == "add"
      assert latest["hostname"] == "app.example.com"

      assert Enum.any?(status["conditions"], fn c ->
               c["type"] == "Synced" and c["status"] == "True"
             end)
    end

    test "truncates history and keeps most recent first" do
      resource = base_resource()

      final_status =
        1..12
        |> Enum.reduce(%{"resource" => resource, "status" => nil}, fn idx, acc ->
          updated_resource =
            acc["resource"]
            |> Map.put("status", acc["status"])
            |> Map.put("metadata", %{
              "name" => "my-dns",
              "namespace" => "default",
              "generation" => 3 + idx
            })

          axn =
            updated_resource
            |> axn_for(:reconcile)
            |> CloudflareDnsRecord.handle_event([])

          %{"resource" => updated_resource, "status" => axn.status}
        end)
        |> Map.fetch!("status")

      assert length(final_status["history"]) <= 10
      [latest | _] = final_status["history"]
      assert latest["action"] == "reconcile"
      assert latest["status"] == "success"
    end
  end

  describe "status updates on failure" do
    setup do
      Application.put_env(:domain_name_operator, :cloudflare_ops, CloudflareOpsFailureMock)
      :ok
    end

    test "captures error details and marks condition false" do
      resource = base_resource()

      axn =
        resource
        |> axn_for(:modify)
        |> CloudflareDnsRecord.handle_event([])

      status = axn.status

      assert get_in(status, ["sync", "lastError", "reason"]) == "boom"
      assert get_in(status, ["cloudflare", "state"]) == "error"

      assert Enum.any?(status["conditions"], fn c ->
               c["type"] == "Synced" and c["status"] == "False"
             end)

      [latest | _] = status["history"]
      assert latest["status"] == "error"
      assert latest["action"] == "modify"
    end
  end

  defp base_resource(overrides \\ %{}) do
    Map.merge(
      %{
        "metadata" => %{
          "name" => "my-dns",
          "namespace" => "default",
          "generation" => 3
        },
        "spec" => %{
          "namespace" => "default",
          "serviceName" => "existing-service",
          "hostName" => "app",
          "domain" => "example.com",
          "zoneId" => "zone-123",
          "proxied" => true
        }
      },
      overrides
    )
  end

  defp axn_for(resource, action) do
    Axn.new!(
      action: action,
      conn: :test_conn,
      operator: DomainNameOperator.Operator,
      resource: resource
    )
  end
end
