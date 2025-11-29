defmodule DomainNameOperator.UtilsTest do
  use ExUnit.Case, async: true

  alias DomainNameOperator.Utils

  describe "extract/2, process/2, transform/2" do
    test "extracts from list by index" do
      assert Utils.extract([:a, :b, :c], 1) == :b
    end

    test "extracts from tuple by index" do
      assert Utils.extract({:ok, 42}, 1) == 42
    end

    test "extracts from access by key" do
      assert Utils.extract(%{name: "Jeb"}, :name) == "Jeb"
    end

    test "extracts via function" do
      fun = fn m -> m[:age] * 2 end
      assert Utils.extract([age: 21], fun) == 42
      assert Utils.process([age: 21], fun) == 42
      assert Utils.transform([age: 21], fun) == 42
    end
  end

  describe "nil_or_empty?/1 and not_nil_or_empty?/1" do
    test "treats nil and empty string as empty" do
      assert Utils.nil_or_empty?(nil)
      assert Utils.nil_or_empty?("")
      refute Utils.nil_or_empty?(" value ")
      refute Utils.not_nil_or_empty?("")
    end
  end

  describe "map key helpers" do
    test "map_string_keys_to_atoms/1" do
      assert Utils.map_string_keys_to_atoms(%{"one" => 1, "two" => 2}) == %{one: 1, two: 2}
    end

    test "map_atom_keys_to_strings/1" do
      assert Utils.map_atom_keys_to_strings(%{one: 1, two: 2}) == %{"one" => 1, "two" => 2}
    end
  end

  describe "UUID helpers" do
    test "validates UUIDs and nil correctly" do
      assert Utils.is_uuid?("4c2fd8d3-a6e3-4e4b-a2ce-3f21456eeb85")
      refute Utils.is_uuid?("not-a-uuid")
      refute Utils.is_uuid?(nil)

      assert Utils.is_uuid_or_nil?(nil)
      assert Utils.is_uuid_or_nil?("4c2fd8d3-a6e3-4e4b-a2ce-3f21456eeb85")
      refute Utils.is_uuid_or_nil?("nope")
    end
  end

  describe "raise_if_nil!/2 and raise_if_nil!/1" do
    test "returns value when not nil" do
      assert Utils.raise_if_nil!("var", "value") == "value"
      assert Utils.raise_if_nil!("value") == "value"
    end

    test "raises CantBeNil with helpful message" do
      assert_raise DomainNameOperator.CantBeNil, fn ->
        Utils.raise_if_nil!("varname", nil)
      end

      assert_raise DomainNameOperator.CantBeNil, fn ->
        Utils.raise_if_nil!(nil)
      end
    end
  end

  describe "masking helpers" do
    test "mask_str/1 masks non-nil values" do
      assert Utils.mask_str(nil) == nil
      assert Utils.mask_str("secret") == "******"
    end

    test "mask_map_key_values/2 masks specified keys" do
      map = %{name: "Ben", title: "Lord"}
      masked = Utils.mask_map_key_values(map, [:title])
      assert masked.name == "Ben"
      assert masked.title == "****"
    end
  end

  describe "list_to_strings_and_atoms/1" do
    test "returns atoms and strings for each entry" do
      result = Utils.list_to_strings_and_atoms([:circle, "square"])
      assert :circle in result
      assert "circle" in result
      assert :square in result
      assert "square" in result
    end
  end

  describe "boolean-from-string helpers" do
    test "explicitly_true?/1 and explicitly_false?/1" do
      assert Utils.explicitly_true?("t")
      assert Utils.explicitly_true?("TRUE")
      refute Utils.explicitly_true?("no")

      assert Utils.explicitly_false?("f")
      assert Utils.explicitly_false?("FALSE")
      refute Utils.explicitly_false?("yes")
    end

    test "false_or_explicitly_true?/1" do
      assert Utils.false_or_explicitly_true?("true")
      refute Utils.false_or_explicitly_true?("no")
      assert Utils.false_or_explicitly_true?(true)
      refute Utils.false_or_explicitly_true?(false)
    end

    test "true_or_explicitly_false?/1" do
      refute Utils.true_or_explicitly_false?("false")
      assert Utils.true_or_explicitly_false?("yes")
      assert Utils.true_or_explicitly_false?(nil)
      assert Utils.true_or_explicitly_false?(true)
      refute Utils.true_or_explicitly_false?(false)
    end
  end

  describe "inspect_format/2 and inspect/3" do
    test "inspect_format/2 returns expected keys" do
      opts = Utils.inspect_format(false, 10)
      assert Keyword.has_key?(opts, :syntax_colors)
      assert Keyword.fetch!(opts, :structs) == false
      assert Keyword.fetch!(opts, :limit) == 10
    end

    test "inspect/3 returns a string representation" do
      s = Utils.inspect(%{a: 1}, true, 5)
      assert is_binary(s)
      assert String.contains?(s, "a")
    end
  end

  describe "trunc_str/2" do
    test "truncates strings longer than given length" do
      assert Utils.trunc_str("abcdef", 3) == "abc"
      assert Utils.trunc_str("ab", 5) == "ab"
    end
  end
end
