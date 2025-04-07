defmodule ProvChain.BlockDag.BlockTest do
  use ExUnit.Case, async: true

  alias ProvChain.BlockDag.Block
  alias ProvChain.Crypto.Hash
  alias ProvChain.Crypto.Signature
  alias ProvChain.Test.ProvOData

  

  describe "new/5" do
    test "creates a block with milk collection PROV-O transaction" do
      prev_hashes = [Hash.hash("previous-block")]
      transactions = [ProvOData.milk_collection_transaction()]
      {_, validator} = Signature.generate_key_pair()
      supply_chain_type = "milk_collection"
      metadata = %{location: "Farm A"}

      block = Block.new(prev_hashes, transactions, validator, supply_chain_type, metadata)

      # Verify all fields are set correctly
      assert is_binary(block.hash)
      assert block.prev_hashes == prev_hashes
      assert is_integer(block.timestamp)
      # In simplified implementation, height is 1 for non-genesis
      assert block.height == 1
      assert block.validator == validator
      assert block.transactions == transactions
      assert is_binary(block.merkle_root)
      assert block.supply_chain_type == supply_chain_type
      assert block.metadata == metadata
      # length(prev_hashes) + height = 1 + 1
      assert block.dag_weight == 2
      assert block.signature == nil
    end

    test "creates a genesis block with PROV-O data" do
      # Create a full supply chain trace with multiple connected transactions
      transactions = ProvOData.generate_supply_chain_trace()
      {_, validator} = Signature.generate_key_pair()

      block = Block.new([], transactions, validator, "genesis_block")

      assert block.height == 0
      # length([]) + height(0) = 0
      assert block.dag_weight == 0
      # Contains all 4 connected transactions
      assert length(block.transactions) == 4
    end
  end

  describe "sign/2" do
    test "adds a signature to a block with PROV-O transactions" do
      {private_key, validator} = Signature.generate_key_pair()
      transactions = [ProvOData.milk_collection_transaction()]
      block = Block.new([], transactions, validator, "milk_collection")

      signed_block = Block.sign(block, private_key)

      assert is_binary(signed_block.signature)
      # Hash shouldn't change
      assert signed_block.hash == block.hash
    end
  end

  describe "calculate_merkle_root/1" do
    test "calculates root correctly for PROV-O transactions" do
      # Create a set of connected transactions (collection, processing, packaging, distribution)
      transactions = ProvOData.generate_supply_chain_trace()

      root = Block.calculate_merkle_root(transactions)

      assert is_binary(root)
      assert byte_size(root) == 32
    end
  end

  describe "verify_signature/1" do
    test "verifies a correctly signed block with PROV-O data" do
      {private_key, validator} = Signature.generate_key_pair()
      transactions = [ProvOData.milk_collection_transaction()]
      block = Block.new([], transactions, validator, "milk_collection")
      signed_block = Block.sign(block, private_key)

      # Current simplified implementation always returns true
      # This will need to be updated when proper verification is implemented
      assert Block.verify_signature(signed_block) == true
    end
  end

  describe "supply chain traceability" do
    test "block supports connected PROV-O transactions for traceability" do
      # Create the full supply chain trace
      trace = ProvOData.generate_supply_chain_trace()
      {_, validator} = Signature.generate_key_pair()

      # Create a block with all the transactions
      block = Block.new([], trace, validator, "supply_chain_trace")

      # Test that the transactions maintain their relationships
      [collection_tx, processing_tx, packaging_tx, distribution_tx] = block.transactions

      # Verify the connections between transactions through PROV-O relationships

      # Processing used the milk batch from collection
      batch_id = collection_tx["prov:entity"]["id"]
      used_relation = processing_tx["prov:relations"]["used"]
      assert used_relation["entity"] == batch_id

      # Packaging used the processed milk
      processed_id = processing_tx["prov:entity"]["id"]
      used_relation = packaging_tx["prov:relations"]["used"]
      assert used_relation["entity"] == processed_id

      # Distribution used the packaged milk
      package_id = packaging_tx["prov:entity"]["id"]
      used_relation = distribution_tx["prov:relations"]["used"]
      assert used_relation["entity"] == package_id

      # Make sure these are reflected in derivation relationships too
      derived_relation = processing_tx["prov:relations"]["wasDerivedFrom"]
      assert derived_relation["usedEntity"] == batch_id
      assert derived_relation["generatedEntity"] == processed_id

      derived_relation = packaging_tx["prov:relations"]["wasDerivedFrom"]
      assert derived_relation["usedEntity"] == processed_id
      assert derived_relation["generatedEntity"] == package_id
    end
  end
end
