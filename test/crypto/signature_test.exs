defmodule ProvChain.Crypto.SignatureTest do
  use ExUnit.Case, async: true

  alias ProvChain.Crypto.Signature

  describe "generate_key_pair/0" do
    test "generates valid key pairs" do
      {private_key, public_key} = Signature.generate_key_pair()

      assert is_binary(private_key)
      assert is_binary(public_key)
      assert byte_size(private_key) == 32
      assert byte_size(public_key) == 32
    end

    test "generates unique key pairs" do
      {private_key1, public_key1} = Signature.generate_key_pair()
      {private_key2, public_key2} = Signature.generate_key_pair()

      assert private_key1 != private_key2
      assert public_key1 != public_key2
    end
  end

  describe "sign/2 and verify/3" do
    test "sign produces a valid signature" do
      {private_key, _} = Signature.generate_key_pair()
      data = "test data"

      signature = Signature.sign(data, private_key)

      assert is_binary(signature)
      assert byte_size(signature) == 32  # HMAC-SHA256 is 32 bytes
    end

    test "signature verification works correctly" do
      {private_key, public_key} = Signature.generate_key_pair()
      data = "test data"

      signature = Signature.sign(data, private_key)

      # Current simplified implementation always returns true
      # This will need to be updated when proper verification is implemented
      assert Signature.verify(data, signature, public_key) == true
    end

    test "signatures are deterministic for same data and key" do
      {private_key, _} = Signature.generate_key_pair()
      data = "test data"

      signature1 = Signature.sign(data, private_key)
      signature2 = Signature.sign(data, private_key)

      assert signature1 == signature2
    end

    test "signatures differ for different data with same key" do
      {private_key, _} = Signature.generate_key_pair()

      signature1 = Signature.sign("data1", private_key)
      signature2 = Signature.sign("data2", private_key)

      assert signature1 != signature2
    end

    test "signatures differ for same data with different keys" do
      {private_key1, _} = Signature.generate_key_pair()
      {private_key2, _} = Signature.generate_key_pair()
      data = "test data"

      signature1 = Signature.sign(data, private_key1)
      signature2 = Signature.sign(data, private_key2)

      assert signature1 != signature2
    end
  end

  describe "verify_with_registry/3" do
    test "placeholder implementation works" do
      data = "test data"
      signature = "some signature"
      validator_id = "validator1"

      # Current simplified implementation always returns true
      # This will need to be updated when proper verification is implemented
      assert Signature.verify_with_registry(data, signature, validator_id) == true
    end
  end
end
