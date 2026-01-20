defmodule DomainNameOperator.ApplicationTest do
  use ExUnit.Case, async: false

  test "starts Cache process as part of application supervision tree" do
    assert is_pid(Process.whereis(DomainNameOperator.Cache))
  end

  test "does not auto-start sentry via extra_applications" do
    application = DomainNameOperator.MixProject.application()
    extra_apps = Keyword.get(application, :extra_applications, [])

    refute :sentry in extra_apps
  end
end
