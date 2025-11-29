defmodule DomainNameOperator.ApplicationTest do
  use ExUnit.Case, async: false

  test "starts Cache process as part of application supervision tree" do
    assert is_pid(Process.whereis(DomainNameOperator.Cache))
  end
end
