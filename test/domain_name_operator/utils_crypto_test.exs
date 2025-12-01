defmodule DomainNameOperator.UtilsCryptoTest do
  use ExUnit.Case, async: true

  alias DomainNameOperator.Utils.Crypto

  test "strong_random_string/1 returns string of requested length" do
    s = Crypto.strong_random_string(16)
    assert is_binary(s)
    assert byte_size(s) == 16
    refute String.contains?(s, "+")
    refute String.contains?(s, "/")
  end

  test "hash_token/1 is deterministic" do
    h1 = Crypto.hash_token("token")
    h2 = Crypto.hash_token("token")
    assert h1 == h2
    refute h1 == Crypto.hash_token("different")
  end
end
