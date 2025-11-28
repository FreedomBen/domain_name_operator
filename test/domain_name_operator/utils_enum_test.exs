defmodule DomainNameOperator.UtilsEnumTest do
  use ExUnit.Case, async: true

  alias DomainNameOperator.Utils.Enum, as: UtilsEnum

  test "none?/2 returns true when predicate is false for all" do
    assert UtilsEnum.none?([1, 2, 3], fn x -> x > 3 end)
  end

  test "none?/2 returns false when predicate is true for some" do
    refute UtilsEnum.none?([1, 2, 3], fn x -> x == 2 end)
  end
end

