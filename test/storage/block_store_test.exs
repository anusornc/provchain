defmodule ProvChain.Storage.BlockStoreTest do
  @moduledoc """
  Tests for the BlockStore module.
  """
  use ExUnit.Case, async: false

  alias ProvChain.Storage.BlockStore
  alias ProvChain.BlockDag.Block
  alias ProvChain.Crypto.Signature

  setup do
    IO.puts("---- Starting test setup ----")

    # Clean test data directory before tests
    dag_path = Application.get_env(:provchain, :dag_storage_path)
    IO.puts("Cleaning directory: #{dag_path}")
    File.rm_rf!(dag_path)
    File.mkdir_p!(dag_path)

    # Ensure Mnesia is running and wait for tables
    IO.puts("Ensuring Mnesia is initialized")
    :mnesia.start()
    :mnesia.wait_for_tables([:schema, BlockStore.blocks_table(), BlockStore.transactions_table(), BlockStore.height_index_table(), BlockStore.type_index_table()], 5000)

    # Clear all tables to ensure a clean state for each test
    IO.puts("Clearing Mnesia tables")
    :mnesia.transaction(fn ->
      BlockStore.clear_tables()
    end)

    # Make sure we clean up after each test
    on_exit(fn ->
      IO.puts("Cleaning up after test")
      BlockStore.delete_schema()
    end)

    IO.puts("---- Setup complete ----")
    :ok
  end

  describe "block operations" do
    test "put_block/1 and get_block/1" do
      # Create a test block
      {_, validator} = Signature.generate_key_pair()
      prev_hash = :crypto.hash(:sha256, "prev_block_1")

      block =
        Block.new(
          [prev_hash],
          [%{"test" => "transaction"}],
          validator,
          "milk_collection",
          %{test: true}
        )

      # Store and retrieve the block
      assert :ok = BlockStore.put_block(block)
      assert {:ok, retrieved_block} = BlockStore.get_block(block.hash)

      # Convert atom keys to string keys for comparison
      expected_metadata = Map.new(block.metadata, fn {k, v} -> {to_string(k), v} end)

      # Compare key fields - comparing binary directly
      assert retrieved_block.hash == block.hash
      assert retrieved_block.height == block.height
      assert retrieved_block.supply_chain_type == block.supply_chain_type
      assert retrieved_block.metadata == expected_metadata
      assert retrieved_block.validator == block.validator
      assert retrieved_block.merkle_root == block.merkle_root
      assert retrieved_block.transactions == block.transactions
      assert retrieved_block.prev_hashes == [prev_hash]
    end

    test "get_block/1 returns error for non-existent block" do
      # Use a binary hash for consistency
      non_existent_hash = :crypto.hash(:sha256, "non_existent")
      assert {:error, :not_found} = BlockStore.get_block(non_existent_hash)
    end
  end

  describe "transaction operations" do
    test "put_transaction/1 and get_transaction/1" do
      # Create a test transaction
      tx_hash = :crypto.hash(:sha256, "tx_hash_1")
      tx = %{
        "hash" => tx_hash,
        "type" => "milk_collection",
        "data" => "test transaction data"
      }

      # Store and retrieve the transaction
      assert :ok = BlockStore.put_transaction(tx)
      assert {:ok, retrieved_tx} = BlockStore.get_transaction(tx["hash"])

      # Compare transaction - convert retrieved hash to binary
      assert Base.decode16!(retrieved_tx["hash"], case: :mixed) == tx["hash"]
      assert retrieved_tx["type"] == tx["type"]
      assert retrieved_tx["data"] == tx["data"]
    end

    test "get_transaction/1 returns error for non-existent transaction" do
      # Use a binary hash for consistency
      non_existent_hash = :crypto.hash(:sha256, "non_existent")
      assert {:error, :not_found} = BlockStore.get_transaction(non_existent_hash)
    end
  end

  describe "index operations" do
    test "get_blocks_by_height/1 returns blocks at specific height" do
      # Create multiple blocks at the same height
      {_, validator} = Signature.generate_key_pair()
      prev_hash1 = :crypto.hash(:sha256, "prev_block_1")
      prev_hash2 = :crypto.hash(:sha256, "prev_block_2")

      # Force height to ensure consistent test behavior
      height = 5

      block1 = %{
        Block.new(
          [prev_hash1],
          [%{"test" => "transaction1"}],
          validator,
          "milk_collection",
          %{test: true}
        )
        | height: height
      }

      block2 = %{
        Block.new(
          [prev_hash2],
          [%{"test" => "transaction2"}],
          validator,
          "milk_processing",
          %{test: true}
        )
        | height: height
      }

      # Store blocks
      assert :ok = BlockStore.put_block(block1)
      assert :ok = BlockStore.put_block(block2)

      # Query by height
      assert {:ok, blocks} = BlockStore.get_blocks_by_height(height)

      # Check that we got both blocks
      assert length(blocks) == 2

      # Verify block hashes - comparing binary
      block_hashes = Enum.map(blocks, & &1.hash)
      assert block1.hash in block_hashes
      assert block2.hash in block_hashes
    end

    test "get_blocks_by_type/1 returns blocks of specific type" do
      # Create multiple blocks with different types
      {_, validator} = Signature.generate_key_pair()
      prev_hash1 = :crypto.hash(:sha256, "prev_block_1")
      prev_hash2 = :crypto.hash(:sha256, "prev_block_2")
      prev_hash3 = :crypto.hash(:sha256, "prev_block_3")

      block1 =
        Block.new(
          [prev_hash1],
          [%{"test" => "transaction1"}],
          validator,
          "milk_collection",
          %{test: true}
        )

      block2 =
        Block.new(
          [prev_hash2],
          [%{"test" => "transaction2"}],
          validator,
          "milk_collection",
          %{test: true}
        )

      block3 =
        Block.new(
          [prev_hash3],
          [%{"test" => "transaction3"}],
          validator,
          "milk_processing",
          %{test: true}
        )

      # Store blocks
      assert :ok = BlockStore.put_block(block1)
      assert :ok = BlockStore.put_block(block2)
      assert :ok = BlockStore.put_block(block3)

      # Query by type
      assert {:ok, milk_collection_blocks} = BlockStore.get_blocks_by_type("milk_collection")
      assert {:ok, milk_processing_blocks} = BlockStore.get_blocks_by_type("milk_processing")

      # Check counts
      assert length(milk_collection_blocks) == 2
      assert length(milk_processing_blocks) == 1

      # Verify types
      assert Enum.all?(milk_collection_blocks, &(&1.supply_chain_type == "milk_collection"))
      assert Enum.all?(milk_processing_blocks, &(&1.supply_chain_type == "milk_processing"))
    end
  end
end
