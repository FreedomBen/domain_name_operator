defmodule DomainNameOperatorTest do
  use ExUnit.Case
  doctest DomainNameOperator

  test "greets the world" do
    assert DomainNameOperator.hello() == :world
  end
end
