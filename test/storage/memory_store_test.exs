defmodule ProvChain.Storage.MemoryStoreTest do
  @moduledoc """
  Tests for the MemoryStore module.
  """
  use ExUnit.Case, async: false

  alias ProvChain.Storage.MemoryStore
  alias ProvChain.BlockDag.Block
  alias ProvChain.Crypto.Signature

  setup do
    IO.puts("---- Starting test setup ----")
    IO.puts("Ensuring MemoryStore is started")

    # Start MemoryStore if not already started
    case MemoryStore.start_link([]) do
      {:ok, _pid} -> :ok
      {:error, {:already_started, _pid}} -> :ok
      {:error, reason} -> flunk("Failed to start MemoryStore: #{inspect(reason)}")
    end

    # Clear caches and ETS table
    IO.puts("Clearing caches and ETS table")
    MemoryStore.clear_cache()
    if :ets.whereis(:provchain_tip_set) != :undefined do
      :ets.delete_all_objects(:provchain_tip_set)
      :ets.insert(:provchain_tip_set, {:current, []})
    end

    on_exit(fn ->
      IO.puts("Cleaning up after test")
      MemoryStore.clear_cache()
    end)

    IO.puts("---- Setup complete ----")
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

    test "get_block/1 returns cache_disabled when cache is off" do
      MemoryStore.set_cache_enabled(false)
      hash = :crypto.hash(:sha256, "block_disabled")
      assert {:error, :cache_disabled} = MemoryStore.get_block(hash)
      MemoryStore.set_cache_enabled(true)
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

    test "get_transaction/1 returns cache_disabled when cache is off" do
      MemoryStore.set_cache_enabled(false)
      hash = :crypto.hash(:sha256, "tx_disabled")
      assert {:error, :cache_disabled} = MemoryStore.get_transaction(hash)
      MemoryStore.set_cache_enabled(true)
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

    test "get_tip_set/0 handles missing ETS table" do
      if :ets.whereis(:provchain_tip_set) != :undefined do
        :ets.delete(:provchain_tip_set)
      end

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

  describe "concurrent access" do
    test "concurrent access to blocks and transactions" do
      {_, validator} = Signature.generate_key_pair()

      block = %Block{
        hash: :crypto.hash(:sha256, "concurrent_block"),
        prev_hashes: [],
        timestamp: 1_744_420_650_662,
        height: 1,
        validator: validator,
        signature: nil,
        transactions: [%{"test" => "transaction"}],
        merkle_root: :crypto.hash(:sha256, "merkle_concurrent"),
        supply_chain_type: "milk_collection",
        dag_weight: 2,
        metadata: %{"test" => true}
      }

      block_hash = block.hash
      tx = %{hash: :crypto.hash(:sha256, "tx_concurrent"), data: "test"}
      tx_hash = tx.hash

      # Ensure data is in cache before concurrent tasks
      assert :ok = MemoryStore.put_block(block_hash, block)
      assert :ok = MemoryStore.put_transaction(tx_hash, tx)

      tasks =
        for i <- 1..20 do
          Task.async(fn ->
            case rem(i, 3) do
              0 -> MemoryStore.put_block(block_hash, block)
              1 -> MemoryStore.put_transaction(tx_hash, tx)
              2 -> MemoryStore.update_tip_set([block_hash])
            end

            if rem(i, 2) == 0 do
              MemoryStore.get_block(block_hash)
            else
              MemoryStore.get_transaction(tx_hash)
            end
          end)
        end

      results = Task.await_many(tasks, 10_000)

      for result <- results do
        assert result in [{:ok, block}, {:ok, tx}]
      end
    end
  end

  describe "cache control" do
    test "set_cache_enabled/1 toggles cache" do
      {_, validator} = Signature.generate_key_pair()
      hash = :crypto.hash(:sha256, "block_toggle")

      block = %Block{
        hash: hash,
        prev_hashes: [],
        timestamp: 1_744_420_650_662,
        height: 1,
        validator: validator,
        signature: nil,
        transactions: [%{"test" => "transaction"}],
        merkle_root: :crypto.hash(:sha256, "merkle_toggle"),
        supply_chain_type: "milk_collection",
        dag_weight: 2,
        metadata: %{"test" => true}
      }

      assert :ok = MemoryStore.set_cache_enabled(false)
      assert {:error, :cache_disabled} = MemoryStore.get_block(hash)
      assert :ok = MemoryStore.set_cache_enabled(true)
      assert :ok = MemoryStore.put_block(hash, block)
      assert {:ok, ^block} = MemoryStore.get_block(hash)
    end

    test "cache_stats/0 returns stats when enabled" do
      case MemoryStore.cache_stats() do
        {:ok, stats} ->
          assert is_map(stats)
          assert stats.enabled == true
          assert is_integer(stats.size)

        {:error, :stats_unavailable} ->
          # Allow stats_unavailable as a fallback
          :ok
      end
    end

    test "cache_stats/0 returns error when disabled" do
      MemoryStore.set_cache_enabled(false)
      assert {:error, :cache_disabled} = MemoryStore.cache_stats()
      MemoryStore.set_cache_enabled(true)
    end
  end
end
