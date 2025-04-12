defmodule ProvChain.Crypto.SignatureTest do
  use ExUnit.Case, async: true

  alias ProvChain.Crypto.Signature

  describe "generate_key_pair/0" do
    test "generates valid key pairs" do
      {:ok, {private_key, public_key}} = Signature.generate_key_pair()
      assert is_binary(private_key)
      assert is_binary(public_key)
      assert byte_size(private_key) == 32
      assert byte_size(public_key) == 32
    end

    test "generates unique key pairs" do
      {:ok, {private_key1, public_key1}} = Signature.generate_key_pair()
      {:ok, {private_key2, public_key2}} = Signature.generate_key_pair()
      assert private_key1 != private_key2
      assert public_key1 != public_key2
    end
  end

  describe "sign/2 and verify/3" do
    test "sign produces a valid signature" do
      {:ok, {private_key, _}} = Signature.generate_key_pair()
      data = "test data"
      {:ok, signature} = Signature.sign(data, private_key)
      assert is_binary(signature)
      assert byte_size(signature) == 64  # Ed25519 signature is 64 bytes
    end

    test "signature verification works correctly" do
      {:ok, {private_key, public_key}} = Signature.generate_key_pair()
      data = "test data"
      {:ok, signature} = Signature.sign(data, private_key)
      assert Signature.verify(data, signature, public_key) == true
    end

    test "signatures are deterministic for same data and key" do
      {:ok, {private_key, _}} = Signature.generate_key_pair()
      data = "test data"
      {:ok, signature1} = Signature.sign(data, private_key)
      {:ok, signature2} = Signature.sign(data, private_key)
      assert signature1 == signature2
    end

    test "signatures differ for different data with same key" do
      {:ok, {private_key, _}} = Signature.generate_key_pair()
      {:ok, signature1} = Signature.sign("data1", private_key)
      {:ok, signature2} = Signature.sign("data2", private_key)
      assert signature1 != signature2
    end

    test "signatures differ for same data with different keys" do
      {:ok, {private_key1, _}} = Signature.generate_key_pair()
      {:ok, {private_key2, _}} = Signature.generate_key_pair()
      data = "test data"
      {:ok, signature1} = Signature.sign(data, private_key1)
      {:ok, signature2} = Signature.sign(data, private_key2)
      assert signature1 != signature2
    end
  end

  describe "verify_with_registry/3" do
    test "placeholder implementation works" do
      data = "test data"
      signature = "some signature"
      validator_id = "validator1"
      assert Signature.verify_with_registry(data, signature, validator_id) == true
    end
  end
end
