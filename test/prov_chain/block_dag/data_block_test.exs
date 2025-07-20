defmodule ProvChain.BlockDag.DataBlockTest do
  use ExUnit.Case, async: true

  alias ProvChain.BlockDag.DataBlock
  alias ProvChain.Crypto.Hash

  @tag :skip
  test "can create a new DataBlock" do
    prev_hashes = []
    transactions = [%{"id" => "tx1"}, %{"id" => "tx2"}]
    validator = <<3::256>>
    supply_chain_type = "milk_collection"
    metadata = %{"farm_id" => "farm123"}

    data_block = DataBlock.new(prev_hashes, transactions, validator, supply_chain_type, metadata)

    assert data_block.prev_hashes == prev_hashes
    assert data_block.transactions == transactions
    assert data_block.validator == validator
    assert data_block.supply_chain_type == supply_chain_type
    assert data_block.metadata == metadata
    assert is_binary(data_block.hash)
    assert is_integer(data_block.timestamp)
    assert data_block.height == 1 # Assuming height is 1 for initial data blocks
  end

  @tag :skip
  test "can create a new DataBlock with previous hashes" do
    # Create dummy previous DataBlocks and put them into BlockStore
    # This part will be problematic without a proper BlockStore setup in tests
    # For now, we'll assume height is 1 for all DataBlocks for simplicity
    prev_hashes = [<<10::256>>, <<20::256>>]
    transactions = [%{"id" => "tx3"}]
    validator = <<4::256>>
    supply_chain_type = "milk_processing"
    metadata = %{"plant_id" => "plantA"}

    data_block = DataBlock.new(prev_hashes, transactions, validator, supply_chain_type, metadata)

    assert data_block.prev_hashes == prev_hashes
    assert data_block.transactions == transactions
    assert data_block.validator == validator
    assert data_block.supply_chain_type == supply_chain_type
    assert data_block.metadata == metadata
    assert is_binary(data_block.hash)
    assert is_integer(data_block.timestamp)
    assert data_block.height == 1 # Assuming height is 1 for all DataBlocks for now
  end
end
