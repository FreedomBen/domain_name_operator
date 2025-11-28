defmodule DomainNameOperator.K8sOpenapiTest do
  use ExUnit.Case, async: true

  alias DomainNameOperator.K8sOpenapi

  test "spec/0 returns nil or a decoded spec map" do
    spec = K8sOpenapi.spec()

    assert is_nil(spec) or is_map(spec)
  end

  test "example_service/3 builds a service-shaped map" do
    svc = K8sOpenapi.example_service("default", "svc-name", "198.51.100.5")

    assert svc["apiVersion"] == "v1"
    assert svc["kind"] == "Service"
    assert svc["metadata"]["name"] == "svc-name"
    assert svc["metadata"]["namespace"] == "default"

    [ingress | _] = svc["status"]["loadBalancer"]["ingress"]
    assert ingress["ip"] == "198.51.100.5"
  end
end

