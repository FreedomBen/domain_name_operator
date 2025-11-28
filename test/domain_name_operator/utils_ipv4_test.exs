defmodule DomainNameOperator.UtilsIPv4Test do
  use ExUnit.Case, async: true

  alias DomainNameOperator.Utils.IPv4

  test "to_s/1 converts IPv4 tuple to string" do
    assert IPv4.to_s({127, 0, 0, 1}) == "127.0.0.1"
  end
end

