defmodule DomainNameOperator.Controller.V1.CloudflareDnsRecordTest do
  @moduledoc false
  use ExUnit.Case, async: false
  alias DomainNameOperator.Controller.V1.CloudflareDnsRecord

  describe "add/1" do
    test "returns :ok" do
      event = %{}
      result = CloudflareDnsRecord.add(event)
      assert result == :ok
    end
  end

  describe "modify/1" do
    test "returns :ok" do
      event = %{}
      result = CloudflareDnsRecord.modify(event)
      assert result == :ok
    end
  end

  describe "delete/1" do
    test "returns :ok" do
      event = %{}
      result = CloudflareDnsRecord.delete(event)
      assert result == :ok
    end
  end

  describe "reconcile/1" do
    test "returns :ok" do
      event = %{}
      result = CloudflareDnsRecord.reconcile(event)
      assert result == :ok
    end
  end
end
