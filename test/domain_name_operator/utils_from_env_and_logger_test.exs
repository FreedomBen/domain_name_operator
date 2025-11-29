defmodule DomainNameOperator.UtilsFromEnvAndLoggerTest do
  use ExUnit.Case, async: true

  alias DomainNameOperator.Utils.FromEnv
  alias DomainNameOperator.Utils.Logger, as: DLogger

  import ExUnit.CaptureLog

  test "FromEnv helpers format module and function" do
    env = __ENV__

    mod = FromEnv.mod_str(env)
    func = FromEnv.func_str(env)
    mfa = FromEnv.mfa_str(env)
    log_mfa = FromEnv.log_str(env)
    log_func = FromEnv.log_str(env, :func_only)

    assert mod =~ "DomainNameOperator.UtilsFromEnvAndLoggerTest"
    assert String.contains?(func, "#test ")
    assert String.contains?(mfa, "DomainNameOperator.UtilsFromEnvAndLoggerTest")
    assert log_mfa =~ "["
    assert String.contains?(log_func, "#test ")
  end

  test "Logger wrappers include mfa prefix and message" do
    log =
      capture_log(fn ->
        DLogger.error(__ENV__, "something went wrong")
      end)

    assert log =~ "something went wrong"
    assert log =~ "DomainNameOperator.UtilsFromEnvAndLoggerTest"
    assert String.contains?(log, "#test ")
  end
end
