defmodule ProvChain.Storage.BlockStoreTest do
  use ExUnit.Case, async: false
  require Logger

  alias ProvChain.Storage.BlockStore
  alias ProvChain.BlockDag.Block
  alias ProvChain.Crypto.Signature

  setup do
    # Stop any running processes
    stop_with_retry = fn name ->
      case Process.whereis(name) do
        pid when is_pid(pid) ->
          Logger.debug("Stopping #{name}")
          try do
            GenServer.stop(name, :normal, 5000)
            Logger.debug("Successfully stopped #{name}")
          catch
            :exit, reason ->
              Logger.debug("Failed to stop #{name}: #{inspect(reason)}")
              :ok
          end
        _ ->
          Logger.debug("#{name} not running")
          :ok
      end
    end

    stop_with_retry.(BlockStore)

    # Clean DAG directory
    dag_path = Application.get_env(:provchain, :dag_storage_path, "data/test/dag")
    File.rm_rf!(dag_path)
    File.mkdir_p!(dag_path)

    # Clean Mnesia directory
    mnesia_dir = Application.get_env(:mnesia, :dir, "data/test/mnesia") |> to_string()
    File.rm_rf!(mnesia_dir)
    File.mkdir_p!(mnesia_dir)

    # Start Mnesia and create schema
    :mnesia.stop()
    :ok = :mnesia.delete_schema([node()])
    :ok = :mnesia.create_schema([node()])
    :ok = :mnesia.start()

    # Create tables
    storage = [ram_copies: [node()]]
    tables = [
      {BlockStore.blocks_table(), [attributes: [:hash, :data], type: :set]},
      {BlockStore.transactions_table(), [attributes: [:hash, :data], type: :set]},
      {BlockStore.height_index_table(), [attributes: [:height, :hash, :timestamp], type: :bag]},
      {BlockStore.type_index_table(), [attributes: [:type, :hash, :timestamp], type: :bag]}
    ]

    for {table, opts} <- tables do
      case :mnesia.create_table(table, opts ++ storage) do
        {:atomic, :ok} -> Logger.info("Created Mnesia table #{table}")
        {:aborted, {:already_exists, _}} -> Logger.debug("Mnesia table #{table} already exists")
        {:aborted, reason} -> flunk("Failed to create Mnesia table #{table}: #{inspect(reason)}")
      end
    end

    # Wait for tables
    tables = [
      :schema,
      BlockStore.blocks_table(),
      BlockStore.transactions_table(),
      BlockStore.height_index_table(),
      BlockStore.type_index_table()
    ]

    case :mnesia.wait_for_tables(tables, 30_000) do
      :ok -> :ok
      {:timeout, missing_tables} -> flunk("Mnesia tables not available: #{inspect(missing_tables)}")
      {:error, reason} -> flunk("Mnesia error: #{inspect(reason)}")
    end

    # Start BlockStore
    {:ok, block_pid} = BlockStore.start_link([])

    # Clear data for fresh test
    :ok = BlockStore.clear_tables()

    # Cleanup on exit
    on_exit(fn ->
      if Process.alive?(block_pid), do: GenServer.stop(block_pid, :normal, 5000)
      :mnesia.stop()
      File.rm_rf!(dag_path)
      File.rm_rf!(mnesia_dir)
    end)

    {:ok, %{block_pid: block_pid}}
  end

  describe "block operations" do
    test "put_block/1 and get_block/1" do
      {:ok, {_, validator}} = Signature.generate_key_pair()
      prev_hash = :crypto.hash(:sha256, "prev_block_1")

      block =
        Block.new(
          [prev_hash],
          [%{"test" => "transaction"}],
          validator,
          "milk_collection",
          %{"test" => true}
        )
        |> Map.put(:height, 1)

      assert :ok = BlockStore.put_block(block)
      assert {:ok, fetched} = BlockStore.get_block(block.hash)

      assert fetched.hash == block.hash
      assert fetched.height == block.height
      assert fetched.supply_chain_type == block.supply_chain_type
      assert fetched.metadata == block.metadata
      assert fetched.validator == block.validator
      assert fetched.merkle_root == block.merkle_root
      assert fetched.transactions == block.transactions
      assert fetched.prev_hashes == [prev_hash]
    end

    test "get_block/1 returns error for non-existent block" do
      hash = :crypto.hash(:sha256, "nonexistent")
      assert {:error, :not_found} = BlockStore.get_block(hash)
    end

    test "put_block/1 returns error for invalid block" do
      invalid = %{hash: "not_binary"}
      assert {:error, _} = BlockStore.put_block(invalid)
    end
  end

  describe "transaction operations" do
    test "put_transaction/1 and get_transaction/1" do
      tx_hash = :crypto.hash(:sha256, "tx_hash_1")
      tx = %{"hash" => tx_hash, "type" => "milk_collection", "data" => "data"}

      assert :ok = BlockStore.put_transaction(tx)
      assert {:ok, fetched} = BlockStore.get_transaction(tx_hash)
      assert fetched == tx
    end

    test "get_transaction/1 returns error for non-existent transaction" do
      hash = :crypto.hash(:sha256, "nonexistent")
      assert {:error, :not_found} = BlockStore.get_transaction(hash)
    end

    test "put_transaction/1 returns error for invalid transaction" do
      assert {:error, _} = BlockStore.put_transaction(%{"no_hash" => "x"})
    end
  end

  describe "index operations" do
    test "get_blocks_by_height/1 returns blocks at specific height" do
      {:ok, {_, validator}} = Signature.generate_key_pair()
      prev1 = :crypto.hash(:sha256, "p1")
      prev2 = :crypto.hash(:sha256, "p2")
      height = 5

      b1 = %{
        Block.new([prev1], [%{"a" => 1}], validator, "t1", %{})
        | height: height
      }

      b2 = %{
        Block.new([prev2], [%{"b" => 2}], validator, "t2", %{})
        | height: height
      }

      assert :ok = BlockStore.put_block(b1)
      assert :ok = BlockStore.put_block(b2)
      assert {:ok, list} = BlockStore.get_blocks_by_height(height)
      assert length(list) == 2
    end

    test "get_blocks_by_height/1 returns empty list for missing height" do
      assert {:ok, []} = BlockStore.get_blocks_by_height(-1)
    end

    test "get_blocks_by_type/1 returns blocks of a type" do
      {:ok, {_, validator}} = Signature.generate_key_pair()
      prev = :crypto.hash(:sha256, "p")

      b1 = Block.new([prev], [%{"x" => 1}], validator, "T1", %{}) |> Map.put(:height, 1)
      b2 = Block.new([prev], [%{"y" => 2}], validator, "T1", %{}) |> Map.put(:height, 1)
      b3 = Block.new([prev], [%{"z" => 3}], validator, "T2", %{}) |> Map.put(:height, 1)

      assert :ok = BlockStore.put_block(b1)
      assert :ok = BlockStore.put_block(b2)
      assert :ok = BlockStore.put_block(b3)

      assert {:ok, t1} = BlockStore.get_blocks_by_type("T1")
      assert {:ok, t2} = BlockStore.get_blocks_by_type("T2")
      assert length(t1) == 2
      assert length(t2) == 1
    end

    test "get_blocks_by_type/1 returns empty list for missing type" do
      assert {:ok, []} = BlockStore.get_blocks_by_type("NONE")
    end
  end

  describe "concurrent access" do
    test "concurrent block and transaction operations" do
      {:ok, {_, validator}} = Signature.generate_key_pair()
      prev = :crypto.hash(:sha256, "p_con")
      block = Block.new([prev], [%{"k" => "v"}], validator, "TY", %{}) |> Map.put(:height, 1)
      tx = %{"hash" => :crypto.hash(:sha256, "tx_con"), "type" => "TY", "data" => "D"}

      tasks =
        for i <- 1..10 do
          Task.async(fn ->
            if rem(i, 2) == 0,
              do: BlockStore.put_block(block),
              else: BlockStore.put_transaction(tx)
          end)
        end

      results = Task.await_many(tasks, 10_000)
      assert Enum.all?(results, fn
               :ok -> true
               {:ok, _} -> true
               _ -> false
             end)
    end
  end
end
