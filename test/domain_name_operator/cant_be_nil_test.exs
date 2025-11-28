defmodule DomainNameOperator.CantBeNilTest do
  use ExUnit.Case, async: true

  alias DomainNameOperator.CantBeNil

  test "exception/1 with varname builds helpful message" do
    ex = CantBeNil.exception(varname: "my_var")
    assert %CantBeNil{} = ex
    assert ex.message =~ "my_var"
  end

  test "exception/1 without varname uses default message" do
    ex = CantBeNil.exception([])
    assert %CantBeNil{} = ex
    assert ex.message =~ "value was set to nil"
  end
end

