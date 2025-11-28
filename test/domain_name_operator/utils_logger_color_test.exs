defmodule DomainNameOperator.UtilsLoggerColorTest do
  use ExUnit.Case, async: true

  alias DomainNameOperator.Utils.LoggerColor

  test "severity helpers return expected atoms" do
    assert LoggerColor.error() == :red
    assert LoggerColor.warning() == :yellow
    assert LoggerColor.info() == :green
    assert LoggerColor.debug() == :cyan
  end
end

