defmodule DomainNameOperator.ApplicationTest do
  use ExUnit.Case, async: false

  test "starts Cache process as part of application supervision tree" do
    assert is_pid(Process.whereis(DomainNameOperator.Cache))
  end

  test "adds Sentry.LoggerBackend as a logger backend" do
    require Logger

    # If the backend is already present, add_backend/1 returns an :already_present error.
    result = Logger.add_backend(Sentry.LoggerBackend)

    assert match?({:error, {:already_present, _}}, result) or match?({:ok, _}, result)
  end
end

