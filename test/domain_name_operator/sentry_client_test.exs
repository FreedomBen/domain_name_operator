defmodule DomainNameOperator.SentryClientTest do
  use ExUnit.Case, async: false

  alias DomainNameOperator.SentryClient

  setup do
    original_env = Application.get_all_env(:sentry)

    on_exit(fn ->
      Enum.each(Application.get_all_env(:sentry), fn {key, _value} ->
        Application.delete_env(:sentry, key)
      end)

      Enum.each(original_env, fn {key, value} ->
        Application.put_env(:sentry, key, value)
      end)
    end)

    :ok
  end

  test "disables sentry when config is missing" do
    Enum.each(Application.get_all_env(:sentry), fn {key, _value} ->
      Application.delete_env(:sentry, key)
    end)

    refute SentryClient.enabled?()
    assert {:ok, :disabled} = SentryClient.capture_exception(%RuntimeError{message: "boom"}, [])
  end

  test "disables sentry when dsn is blank" do
    Application.put_env(:sentry, :dsn, "   ")

    refute SentryClient.enabled?()
    assert {:ok, :disabled} = SentryClient.capture_exception(%RuntimeError{message: "boom"}, [])
  end
end
