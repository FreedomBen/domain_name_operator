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

  describe "parse/1 defaulting behavior" do
    test "fills in missing zoneId from default" do
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
          "proxied" => true
        }
      }

      assert {:ok, %CloudflareApi.DnsRecord{} = record} = CloudflareDnsRecord.parse(payload)
      assert record.zone_id == "zone-123"
    end

    test "fills in missing domain from hostname using default when extraction fails" do
      Application.put_env(:domain_name_operator, :cloudflare_default_domain, "fallback.com")

      payload = %{
        "metadata" => %{
          "name" => "my-dns",
          "namespace" => "default"
        },
        "spec" => %{
          "namespace" => "default",
          "serviceName" => "existing-service",
          # no domain component
          "hostName" => "app",
          "proxied" => true,
          "zoneId" => "zone-123"
        }
      }

      assert {:ok, %CloudflareApi.DnsRecord{} = record} = CloudflareDnsRecord.parse(payload)
      assert record.hostname == "app.fallback.com"
      assert record.zone_name == "fallback.com"
    end

    test "defaults namespace from metadata when missing in spec" do
      payload = %{
        "metadata" => %{
          "name" => "my-dns",
          "namespace" => "ns-from-metadata"
        },
        "spec" => %{
          "serviceName" => "existing-service",
          "hostName" => "app",
          "proxied" => true,
          "zoneId" => "zone-123",
          "domain" => "example.com"
        }
      }

      assert {:ok, %CloudflareApi.DnsRecord{} = record} = CloudflareDnsRecord.parse(payload)
      # The mock uses the namespace it is called with; if we got here, it means
      # parse/1 passed the metadata namespace through to the k8s client.
      assert record.zone_name == "example.com"
    end

    test "defaults proxied to false when missing" do
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
          "zoneId" => "zone-123"
        }
      }

      assert {:ok, %CloudflareApi.DnsRecord{} = record} = CloudflareDnsRecord.parse(payload)
      assert record.proxied == false
    end
  end

  describe "parse/1 error handling via mocked k8s client" do
    defmodule NoIpK8sClientMock do
      @behaviour DomainNameOperator.K8sClient

      @impl true
      def get_service(namespace, name) do
        service = %{
          "apiVersion" => "v1",
          "kind" => "Service",
          "metadata" => %{
            "name" => name,
            "namespace" => namespace
          },
          "status" => %{
            "loadBalancer" => %{
              "ingress" => []
            }
          }
        }

        {:ok, service}
      end
    end

    test "returns :no_ip when Service has no ingress addresses" do
      Application.put_env(:domain_name_operator, :k8s_client, NoIpK8sClientMock)

      payload = %{
        "metadata" => %{
          "name" => "my-dns",
          "namespace" => "default"
        },
        "spec" => %{
          "namespace" => "default",
          "serviceName" => "any-service",
          "hostName" => "app",
          "domain" => "example.com",
          "zoneId" => "zone-123",
          "proxied" => true
        }
      }

      assert {:error, :no_ip, %{namespace: "default", name: "any-service"}} =
               CloudflareDnsRecord.parse(payload)
    end
  end
end
