defmodule DomainNameOperator.UtilsNumberTest do
  use ExUnit.Case, async: true

  alias DomainNameOperator.Utils.Number, as: Num

  describe "format/2 and format_us/2" do
    test "formats integers with US defaults" do
      assert Num.format(1000) == "1,000"
      assert Num.format_us(1234567) == "1,234,567"
    end

    test "formats floats with US defaults" do
      assert Num.format(1234.5) == "1,234.50"
      assert Num.format_us(1234.5) == "1,234.50"
    end
  end

  describe "format_intl/2" do
    test "formats integers with international defaults" do
      assert Num.format_intl(1000) == "1.000"
    end

    test "formats floats with international defaults" do
      assert Num.format_intl(1234.5) == "1.234,50"
    end
  end

  describe "private-but-testable option helpers" do
    test "get_int_opts/1 merges overrides with defaults" do
      opts = Num.get_int_opts(precision: 3)
      assert opts[:precision] == 3
      assert opts[:delimiter] == ","
      assert opts[:separator] == "."
    end

    test "get_float_opts/1 merges overrides with defaults" do
      opts = Num.get_float_opts(precision: 4)
      assert opts[:precision] == 4
      assert opts[:delimiter] == ","
      assert opts[:separator] == "."
    end

    test "get_intl_int_opts/1 merges overrides with defaults" do
      opts = Num.get_intl_int_opts(precision: 1)
      assert opts[:precision] == 1
      assert opts[:delimiter] == "."
      assert opts[:separator] == ","
    end

    test "get_intl_float_opts/1 merges overrides with defaults" do
      opts = Num.get_intl_float_opts(precision: 3)
      assert opts[:precision] == 3
      assert opts[:delimiter] == "."
      assert opts[:separator] == ","
    end
  end
end
