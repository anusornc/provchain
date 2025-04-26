defmodule ProvChain.Crypto.HashTest do
  use ExUnit.Case, async: true

  alias ProvChain.Crypto.Hash

  describe "hash/1" do
    test "produces consistent hashes for the same input" do
      data = "test data"

      hash1 = Hash.hash(data)
      hash2 = Hash.hash(data)

      assert hash1 == hash2
      # SHA-256 is 32 bytes (256 bits)
      assert byte_size(hash1) == 32
    end

    test "produces different hashes for different inputs" do
      hash1 = Hash.hash("data1")
      hash2 = Hash.hash("data2")

      assert hash1 != hash2
    end

    test "works with non-binary data" do
      data = %{key: "value", number: 123}

      hash = Hash.hash(data)

      assert is_binary(hash)
      assert byte_size(hash) == 32
    end
  end

  describe "merkle_root/1" do
    test "handles empty list" do
      root = Hash.merkle_root([])
      assert is_binary(root)
      assert byte_size(root) == 32
    end

    test "handles single hash" do
      hash = Hash.hash("test")
      root = Hash.merkle_root([hash])

      assert root == hash
    end

    test "combines multiple hashes correctly" do
      hash1 = Hash.hash("data1")
      hash2 = Hash.hash("data2")
      hash3 = Hash.hash("data3")
      hash4 = Hash.hash("data4")

      # Manual calculation for verification
      combined1 = Hash.hash(hash1 <> hash2)
      combined2 = Hash.hash(hash3 <> hash4)
      expected_root = Hash.hash(combined1 <> combined2)

      root = Hash.merkle_root([hash1, hash2, hash3, hash4])

      assert root == expected_root
    end

    test "handles odd number of hashes by duplicating last one" do
      hash1 = Hash.hash("data1")
      hash2 = Hash.hash("data2")
      hash3 = Hash.hash("data3")

      # Manual calculation for verification (with duplication)
      combined1 = Hash.hash(hash1 <> hash2)
      # Last one duplicated
      combined2 = Hash.hash(hash3 <> hash3)
      expected_root = Hash.hash(combined1 <> combined2)

      root = Hash.merkle_root([hash1, hash2, hash3])

      assert root == expected_root
    end
  end

  describe "double_hash/1" do
    test "applies hash twice" do
      data = "test data"

      # Manual double hash
      expected = Hash.hash(Hash.hash(data))

      result = Hash.double_hash(data)

      assert result == expected
    end
  end

  describe "to_hex/1 and from_hex/1" do
    test "converts binary hash to hex and back" do
      original_hash = Hash.hash("test data")

      hex = Hash.to_hex(original_hash)
      # 32 bytes = 64 hex chars
      assert String.length(hex) == 64

      # Should only contain hex characters
      assert hex =~ ~r/^[0-9a-f]+$/

      # Convert back to binary
      binary = Hash.from_hex(hex)
      assert binary == original_hash
    end

    test "from_hex works with mixed case" do
      hex = "AbCdEf1234567890" <> "AbCdEf1234567890" <> "AbCdEf1234567890" <> "AbCdEf1234567890"

      binary = Hash.from_hex(hex)

      assert byte_size(binary) == 32
      assert Hash.to_hex(binary) == String.downcase(hex)
    end
  end
end
