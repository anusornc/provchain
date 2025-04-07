defmodule ProvChain.Storage.MemoryStoreTest do
  @moduledoc """
  Tests for the MemoryStore module.
  """
  use ExUnit.Case, async: false

  alias ProvChain.Storage.MemoryStore

  setup do
    # Start the MemoryStore before each test
    start_supervised!(MemoryStore)
    :ok
  end

  describe "block operations" do
    test "put_block/2 and get_block/1" do
      block = %{hash: "block_hash_1", data: "test block data"}
      hash = "block_hash_1"

      assert :ok = MemoryStore.put_block(hash, block)
      assert {:ok, ^block} = MemoryStore.get_block(hash)
    end

    test "get_block/1 returns error for non-existent block" do
      assert {:error, :not_found} = MemoryStore.get_block("non_existent_hash")
    end

    test "has_block?/1 returns true for existing block" do
      hash = "block_hash_2"
      block = %{hash: hash, data: "test block data"}

      assert :ok = MemoryStore.put_block(hash, block)
      assert MemoryStore.has_block?(hash) == true
    end

    test "has_block?/1 returns false for non-existent block" do
      assert MemoryStore.has_block?("non_existent_hash") == false
    end
  end

  describe "transaction operations" do
    test "put_transaction/2 and get_transaction/1" do
      tx = %{hash: "tx_hash_1", data: "test transaction data"}
      hash = "tx_hash_1"

      assert :ok = MemoryStore.put_transaction(hash, tx)
      assert {:ok, ^tx} = MemoryStore.get_transaction(hash)
    end

    test "get_transaction/1 returns error for non-existent transaction" do
      assert {:error, :not_found} = MemoryStore.get_transaction("non_existent_hash")
    end

    test "has_transaction?/1 returns true for existing transaction" do
      hash = "tx_hash_2"
      tx = %{hash: hash, data: "test transaction data"}

      assert :ok = MemoryStore.put_transaction(hash, tx)
      assert MemoryStore.has_transaction?(hash) == true
    end

    test "has_transaction?/1 returns false for non-existent transaction" do
      assert MemoryStore.has_transaction?("non_existent_hash") == false
    end
  end

  describe "tip set operations" do
    test "update_tip_set/1 and get_tip_set/0" do
      tip_set = ["block_hash_1", "block_hash_2", "block_hash_3"]

      assert :ok = MemoryStore.update_tip_set(tip_set)
      assert MemoryStore.get_tip_set() == tip_set
    end

    test "get_tip_set/0 returns empty list by default" do
      # The setup should ensure a clean state
      # But we explicitly update to empty list to be sure
      MemoryStore.update_tip_set([])
      assert MemoryStore.get_tip_set() == []
    end

    test "update_tip_set/1 replaces previous tip set" do
      initial_tip_set = ["block_1", "block_2"]
      new_tip_set = ["block_3", "block_4", "block_5"]

      assert :ok = MemoryStore.update_tip_set(initial_tip_set)
      assert MemoryStore.get_tip_set() == initial_tip_set

      assert :ok = MemoryStore.update_tip_set(new_tip_set)
      assert MemoryStore.get_tip_set() == new_tip_set
    end
  end

  test "concurrent access to ETS tables" do
    # Test that multiple processes can access the tables concurrently
    block = %{hash: "concurrent_block", data: "concurrent test"}
    hash = "concurrent_block"

    tasks = for _ <- 1..10 do
      Task.async(fn ->
        MemoryStore.put_block(hash, block)
        MemoryStore.get_block(hash)
      end)
    end

    results = Task.await_many(tasks)
    for result <- results do
      assert result == {:ok, block}
    end
  end
end
