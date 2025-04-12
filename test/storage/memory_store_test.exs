defmodule ProvChain.Storage.MemoryStoreTest do
  @moduledoc """
  Tests for the MemoryStore module.
  """
  use ExUnit.Case, async: false

  alias ProvChain.Storage.MemoryStore
  alias ProvChain.BlockDag.Block
  alias ProvChain.Crypto.Signature

  setup do
    # Clear ETS tables if they exist
    for table <- [:provchain_blocks, :provchain_transactions, :provchain_tip_set] do
      if :ets.whereis(table) != :undefined do
        :ets.delete_all_objects(table)
      end
    end
    # Reset tip set to empty list
    MemoryStore.update_tip_set([])
    :ok
  end

  describe "block operations" do
    test "put_block/2 and get_block/1" do
      {_, validator} = Signature.generate_key_pair()
      block = %Block{
        hash: :crypto.hash(:sha256, "block_1"),
        prev_hashes: [],
        timestamp: 1_744_420_650_662,
        height: 1,
        validator: validator,
        signature: nil,
        transactions: [%{"test" => "transaction"}],
        merkle_root: :crypto.hash(:sha256, "merkle_1"),
        supply_chain_type: "milk_collection",
        dag_weight: 2,
        metadata: %{"test" => true}
      }
      hash = block.hash

      assert :ok = MemoryStore.put_block(hash, block)
      assert {:ok, ^block} = MemoryStore.get_block(hash)
    end

    test "get_block/1 returns error for non-existent block" do
      non_existent_hash = :crypto.hash(:sha256, "non_existent")
      assert {:error, :not_found} = MemoryStore.get_block(non_existent_hash)
    end

    test "has_block?/1 returns true for existing block" do
      hash = :crypto.hash(:sha256, "block_2")
      block = %Block{
        hash: hash,
        prev_hashes: [],
        timestamp: 1_744_420_650_662,
        height: 1,
        validator: :crypto.hash(:sha256, "validator"),
        signature: nil,
        transactions: [%{"test" => "transaction"}],
        merkle_root: :crypto.hash(:sha256, "merkle_2"),
        supply_chain_type: "milk_collection",
        dag_weight: 2,
        metadata: %{"test" => true}
      }

      assert :ok = MemoryStore.put_block(hash, block)
      assert MemoryStore.has_block?(hash) == true
    end

    test "has_block?/1 returns false for non-existent block" do
      non_existent_hash = :crypto.hash(:sha256, "non_existent")
      assert MemoryStore.has_block?(non_existent_hash) == false
    end
  end

  describe "transaction operations" do
    test "put_transaction/2 and get_transaction/1" do
      tx = %{
        hash: :crypto.hash(:sha256, "tx_1"),
        data: "test transaction data"
      }
      hash = tx.hash

      assert :ok = MemoryStore.put_transaction(hash, tx)
      assert {:ok, ^tx} = MemoryStore.get_transaction(hash)
    end

    test "get_transaction/1 returns error for non-existent transaction" do
      non_existent_hash = :crypto.hash(:sha256, "non_existent")
      assert {:error, :not_found} = MemoryStore.get_transaction(non_existent_hash)
    end

    test "has_transaction?/1 returns true for existing transaction" do
      hash = :crypto.hash(:sha256, "tx_2")
      tx = %{
        hash: hash,
        data: "test transaction data"
      }

      assert :ok = MemoryStore.put_transaction(hash, tx)
      assert MemoryStore.has_transaction?(hash) == true
    end

    test "has_transaction?/1 returns false for non-existent transaction" do
      non_existent_hash = :crypto.hash(:sha256, "non_existent")
      assert MemoryStore.has_transaction?(non_existent_hash) == false
    end
  end

  describe "tip set operations" do
    test "update_tip_set/1 and get_tip_set/0" do
      tip_set = [
        :crypto.hash(:sha256, "block_1"),
        :crypto.hash(:sha256, "block_2"),
        :crypto.hash(:sha256, "block_3")
      ]

      assert :ok = MemoryStore.update_tip_set(tip_set)
      assert MemoryStore.get_tip_set() == tip_set
    end

    test "get_tip_set/0 returns empty list by default" do
      assert MemoryStore.get_tip_set() == []
    end

    test "update_tip_set/1 replaces previous tip set" do
      initial_tip_set = [
        :crypto.hash(:sha256, "block_1"),
        :crypto.hash(:sha256, "block_2")
      ]
      new_tip_set = [
        :crypto.hash(:sha256, "block_3"),
        :crypto.hash(:sha256, "block_4"),
        :crypto.hash(:sha256, "block_5")
      ]

      assert :ok = MemoryStore.update_tip_set(initial_tip_set)
      assert MemoryStore.get_tip_set() == initial_tip_set

      assert :ok = MemoryStore.update_tip_set(new_tip_set)
      assert MemoryStore.get_tip_set() == new_tip_set
    end
  end

  test "concurrent access to ETS tables" do
    block = %Block{
      hash: :crypto.hash(:sha256, "concurrent_block"),
      prev_hashes: [],
      timestamp: 1_744_420_650_662,
      height: 1,
      validator: :crypto.hash(:sha256, "validator"),
      signature: nil,
      transactions: [%{"test" => "transaction"}],
      merkle_root: :crypto.hash(:sha256, "merkle_concurrent"),
      supply_chain_type: "milk_collection",
      dag_weight: 2,
      metadata: %{"test" => true}
    }
    hash = block.hash

    tasks =
      for _ <- 1..10 do
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
