defmodule DomainNameOperator.Controller.V1.CloudflareDnsRecordRbacTest do
  @moduledoc false
  use ExUnit.Case, async: true

  alias DomainNameOperator.Controller.V1.CloudflareDnsRecord

  test "rbac_rules include permissions to emit events" do
    rules = CloudflareDnsRecord.rbac_rules()

    assert Enum.member?(rules, %{
             apiGroups: [""],
             resources: ["events"],
             verbs: ["create", "patch", "update"]
           })

    assert Enum.member?(rules, %{
             apiGroups: ["events.k8s.io"],
             resources: ["events"],
             verbs: ["create", "patch", "update"]
           })
  end
end
