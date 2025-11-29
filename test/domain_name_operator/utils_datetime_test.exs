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

  test "utc_now_trunc/0 returns time truncated to seconds" do
    t = DateUtils.utc_now_trunc()
    assert t.microsecond == {0, 0}
  end

  test "distant_future/0 returns a time far in the future" do
    future = DateUtils.distant_future()
    now = DateTime.utc_now()
    assert DateTime.compare(future, now) == :gt
  end
end
