defmodule DomainNameOperator.Controller.V1.CloudflareDnsRecordParseTest do
  @moduledoc false
  use ExUnit.Case, async: false

  alias DomainNameOperator.Controller.V1.CloudflareDnsRecord

  setup do
    # Ensure we are using the mock k8s client in tests.
    Application.put_env(:domain_name_operator, :k8s_client, DomainNameOperator.K8sClient.Mock)

    Application.put_env(:domain_name_operator, :cloudflare_default_domain, "example.com")
    Application.put_env(:domain_name_operator, :cloudflare_default_zone_id, "zone-123")

    :ok
  end

  describe "parse/1 with full spec and mocked k8s service" do
    test "returns a Cloudflare DnsRecord using the Service IP" do
      payload = %{
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

      assert {:ok, %CloudflareApi.DnsRecord{} = record} = CloudflareDnsRecord.parse(payload)

      # Hostname should be combined with domain if it does not already end with it.
      assert record.hostname == "app.example.com"

      assert record.zone_id == "zone-123"
      assert record.zone_name == "example.com"
      # IP is taken from the mocked Service object.
      assert record.ip == "203.0.113.10"
      assert record.proxied == true
    end
  end
end

