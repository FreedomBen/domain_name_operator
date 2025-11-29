defmodule DomainNameOperator.Controller.V1.CloudflareDnsRecordProcessTest do
  @moduledoc false
  use ExUnit.Case, async: false

  alias DomainNameOperator.Controller.V1.CloudflareDnsRecord

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

  setup do
    Application.put_env(:domain_name_operator, :k8s_client, DomainNameOperator.K8sClient.Mock)
    Application.put_env(:domain_name_operator, :cloudflare_ops, DomainNameOperator.CloudflareOps)
    Application.put_env(
      :domain_name_operator,
      :sentry_client,
      DomainNameOperator.SentryClient.Test
    )

    Application.put_env(:domain_name_operator, :cloudflare_default_domain, "example.com")
    Application.put_env(:domain_name_operator, :cloudflare_default_zone_id, "zone-123")

    :ok
  end

  defp base_payload(overrides \\ %{}) do
    Map.merge(
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
      },
      overrides
    )
  end

  describe "process_record/1 error branches" do
    test "handles :no_ip from parse/1" do
      Application.put_env(:domain_name_operator, :k8s_client, NoIpK8sClientMock)

      payload = base_payload(%{})

      assert {:error, :no_ip} = CloudflareDnsRecord.process_record(payload)
    end

    test "handles :service_not_found from get_service/2" do
      Application.put_env(:domain_name_operator, :k8s_client, DomainNameOperator.K8sClient.Mock)

      payload =
        base_payload(%{
          "spec" => %{
            "namespace" => "default",
            "serviceName" => "missing-service",
            "hostName" => "app",
            "domain" => "example.com",
            "zoneId" => "zone-123",
            "proxied" => true
          }
        })

      assert {:error, :service_not_found} = CloudflareDnsRecord.process_record(payload)
    end

    defmodule CloudflareOpsAuthMissingMock do
      def add_or_update_record(_record), do: {:error, [%{"code" => 9106}]}
    end

    defmodule CloudflareOpsGenericErrorMock do
      def add_or_update_record(_record), do: {:error, :some_error}
    end

    defmodule CloudflareOpsUnhandledErrorMock do
      def add_or_update_record(_record), do: :unexpected_error
    end

    test "handles Cloudflare auth missing error" do
      Application.put_env(:domain_name_operator, :cloudflare_ops, CloudflareOpsAuthMissingMock)

      payload = base_payload()

      assert {:error, :cloudflare_auth_missing} =
               CloudflareDnsRecord.process_record(payload)
    end

    test "handles generic {:error, err} from CloudflareOps" do
      Application.put_env(:domain_name_operator, :cloudflare_ops, CloudflareOpsGenericErrorMock)

      payload = base_payload()

      assert {:error, :some_error} = CloudflareDnsRecord.process_record(payload)
    end

    test "handles unexpected non-tuple errors via handle_process_record_error/2" do
      Application.put_env(:domain_name_operator, :cloudflare_ops, CloudflareOpsUnhandledErrorMock)

      payload = base_payload()

      assert {:error, _wrapped} = CloudflareDnsRecord.process_record(payload)
    end
  end

  describe "process_record_error/4 and parse_record_error/4 Sentry integration" do
    setup do
      Application.put_env(
        :domain_name_operator,
        :sentry_client,
        DomainNameOperator.SentryClient.Test
      )

      :ok
    end

    test "sends service_not_found details to sentry" do
      payload = base_payload()

      assert {:error, :service_not_found} =
               CloudflareDnsRecord.process_record_error(
                 :service_not_found,
                 "ns-1",
                 "svc-1",
                 payload
               )

      assert_receive {:sentry_called, %DomainNameOperator.ProcessRecordException{} = ex, opts}

      tags = Keyword.fetch!(opts, :tags)
      extra = Keyword.fetch!(opts, :extra)

      assert tags[:error_type] == :service_not_found
      assert extra[:type] == :service_not_found
      assert extra[:cloudflarednsrecord] == payload
      assert extra[:service_namespace] == "ns-1"
      assert extra[:service_name] == "svc-1"
      assert ex.message =~ "Service 'svc-1' was not found in namespace 'ns-1'"
    end

    test "sends no_ip details to sentry" do
      payload = base_payload()

      assert {:error, :no_ip} =
               CloudflareDnsRecord.parse_record_error(
                 :no_ip,
                 "ns-2",
                 "svc-2",
                 payload
               )

      assert_receive {:sentry_called, %DomainNameOperator.ProcessRecordException{} = _ex, opts}

      tags = Keyword.fetch!(opts, :tags)
      extra = Keyword.fetch!(opts, :extra)

      assert tags[:error_type] == :no_ip
      assert extra[:type] == :no_ip
      assert extra[:cloudflarednsrecord] == payload
    end

    test "logs when Sentry client fails" do
      Application.put_env(
        :domain_name_operator,
        :sentry_client,
        DomainNameOperator.SentryClient.FailingTest
      )

      payload = base_payload()

      log =
        ExUnit.CaptureLog.capture_log(fn ->
          CloudflareDnsRecord.process_record_error(:cloudflare_auth_missing, payload)
        end)

      assert log =~ "Couldn't send exception to sentry"
      assert log =~ "cloudflare_auth_missing"
    end
  end
end
