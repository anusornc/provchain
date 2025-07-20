defmodule ProvChain.BlockDag.TipSelectionTest do
  use ExUnit.Case, async: true

  alias ProvChain.BlockDag.TipSelection
  alias ProvChain.Storage.MemoryStore
  alias ProvChain.BlockDag.Block
  alias ProvChain.Test.ProvOData

  setup do
    # Ensure the memory store is clean for each test
    MemoryStore.clear_cache()
    MemoryStore.clear_tables()
    :ok
  end

  test "selects the single tip when one block exists after genesis" do
    # 1. Create a genesis block and a successor block
    {:ok, {_, pub_key}} = ProvChain.Crypto.Signature.generate_key_pair()
    genesis_tx = ProvOData.milk_collection_transaction()
    genesis_block = Block.new([], [genesis_tx], pub_key, "genesis", %{})

    tip_tx = ProvOData.milk_processing_transaction()
    tip_block = Block.new([genesis_block.hash], [tip_tx], pub_key, "test", %{})

    # 2. Manually set the tip set for the test
    :ok = MemoryStore.set_tips([tip_block.hash])

    # 3. Assert that the selection algorithm returns the correct tip
    assert {:ok, [tip_hash]} = TipSelection.select_tips()
    assert tip_hash == tip_block.hash
  end

  test "selects genesis block when no other tips exist" do
    assert {:ok, :genesis_block_hash} == TipSelection.select_tips()
  end
end
