defmodule DomainNameOperator.Controller.V1.CloudflareDnsRecordTest do
  @moduledoc false
  use ExUnit.Case, async: false
  alias DomainNameOperator.Controller.V1.CloudflareDnsRecord

  def example_payload_full do
    %{
      "apiVersion" => "domain-name-operator.tamx.org/v1",
      "kind" => "CloudflareDnsRecord",
      "metadata" => %{
        "annotations" => %{
          "kubectl.kubernetes.io/last-applied-configuration" => %{
            "apiVersion" => "hello-operator.example.com/v1",
            "kind" => "Greeting",
            "metadata" => %{"annotations" => %{}, "name" => "hello-server", "namespace" => "default"},
            "spec" => %{"greeting" => "Howdy"}
          }
        },
        "clusterName" => "",
        "creationTimestamp" => "2018-12-30T17:17:58Z",
        "generation" => 1,
        "name" => "some-service-dns-record",
        "namespace" => "default",
        "resourceVersion" => "1359609",
        "selfLink" => "/apis/hello-operator.example.com/v1/namespaces/default/greetings/hello-server",
        "uid" => "daa7e59b-0c56-11e9-bd27-025000000001"
      },
      "spec" => %{
        "namespace" => "domain-name-operator-staging",
        "serviceName" => "Howdy",
        "hostName" => "domain-name-operator-staging",
        "domain" => "ameelio.xyz",
        "zoneId" => "abcdefg",
        "proxied" => true
      }
    }
  end

  def example_payload(metadata_overrides, spec_overrides) do
    %{
      "metadata" => %{
        "name" => "Jack Porter",
        "namespace" => "revenge"
      } |> Map.merge(metadata_overrides),
      "spec" => %{
        "namespace" => "domain-name-operator-staging",
        "serviceName" => "Howdy",
        "hostName" => "domain-name-operator-staging",
        "domain" => "ameelio.xyz",
        "zoneId" => "abcdefg",
        "proxied" => true
      } |> Map.merge(spec_overrides)
    }
  end

  def set_default_vals(domain, zone_id) do
    Application.put_env(:domain_name_operator, :cloudflare_default_domain, domain)
    Application.put_env(:domain_name_operator, :cloudflare_default_zone_id, zone_id)
  end

  describe "#extract_domain/1" do
    test "uses extracted if there" do
      assert "example.com" == CloudflareDnsRecord.extract_domain("hamilton.example.com")
    end

    test "uses default if can't extract" do
      set_default_vals("metallica.com", nil)
      assert "metallica.com" == CloudflareDnsRecord.extract_domain("hamilton")
    end
  end

  # describe "parse/1" do
  #   test "Raises if default domain isn't set" do
  #     assert_raise RuntimeError, fn ->
  #       CloudflareDnsRecord.parse(%{
  #         "metadata" => %{
  #           "name" => "Victoria Grayson"
  #         },
  #         "spec" => %{
  #           "namespace" => "Conrad Grayson",
  #           "serviceName" => "Daniel Grayson",
  #           "hostName" => ""
  #         }
  #       })
  #     end
  #   end

  #   test "Fills in default domain" do
  #     default_domain = "grayson.com"
  #     set_default_vals(default_domain, "notchecked")

  #     back =
  #       CloudflareDnsRecord.parse(%{
  #         "metadata" => %{
  #           "name" => "Victoria Grayson"
  #         },
  #         "spec" => %{
  #           "namespace" => "Conrad Grayson",
  #           "serviceName" => "Daniel Grayson",
  #           "hostName" => "",
  #           "zoneID" => ""
  #         }
  #       })

  #     assert false
  #   end

  #   test "Properly gets domain" do
  #     Application.put_env(:domain_name_operator, :cloudflare_default_domain, "somethign.com")

  #     back =
  #       CloudflareDnsRecord.parse(%{
  #         "metadata" => %{
  #           "name" => "Victoria Grayson"
  #         },
  #         "spec" => %{
  #           "namespace" => "Conrad Grayson",
  #           "serviceName" => "Daniel Grayson",
  #           "hostName" => "",
  #           "domain" => ""
  #         }
  #       })
  #     assert false
  #   end

  #   #test "Fills in default zone ID" do
  #   #  back =
  #   #    CloudflareDnsRecord.parse(%{
  #   #      "metadata" => %{
  #   #        "name" => "Victoria Grayson"
  #   #      },
  #   #      "spec" => %{
  #   #        "namespace" => "Conrad Grayson",
  #   #        "serviceName" => "Daniel Grayson",
  #   #        "hostName" => ""
  #   #      }
  #   #    })
  #   #  assert false
  #   #  require IEx; IEx.pry
  #   #end
  # end
end
