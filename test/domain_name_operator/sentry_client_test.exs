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

  test "falls back to environment when config is missing" do
    Enum.each(Application.get_all_env(:sentry), fn {key, _value} ->
      Application.delete_env(:sentry, key)
    end)

    original_dsn = System.get_env("SENTRY_DSN")

    try do
      System.put_env("SENTRY_DSN", "   ")
      refute SentryClient.enabled?()

      System.put_env("SENTRY_DSN", "https://public@o0.ingest.sentry.io/1")
      assert SentryClient.enabled?()
    after
      case original_dsn do
        nil -> System.delete_env("SENTRY_DSN")
        value -> System.put_env("SENTRY_DSN", value)
      end
    end
  end
end
