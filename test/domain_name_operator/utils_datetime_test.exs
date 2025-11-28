defmodule DomainNameOperator.UtilsDateTimeTest do
  use ExUnit.Case, async: true

  alias DomainNameOperator.Utils.DateTime, as: DateUtils

  test "adjust_time/3 adds seconds correctly" do
    now = DateTime.utc_now()
    future = DateUtils.adjust_time(now, 60, :seconds)
    assert future == DateTime.add(now, 60, :second)
  end

  test "in_the_past?/2 and expired?/2 behave as expected" do
    now = DateTime.utc_now()
    past = DateTime.add(now, -60, :second)
    future = DateTime.add(now, 60, :second)

    assert DateUtils.in_the_past?(past, now)
    refute DateUtils.in_the_past?(future, now)

    assert DateUtils.expired?(past, now)
    refute DateUtils.expired?(future, now)
  end
end

