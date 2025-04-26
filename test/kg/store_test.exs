defmodule ProvChain.KG.StoreTest do
  use ExUnit.Case, async: false

  alias ProvChain.KG.Store
  alias ProvChain.Test.ProvOData
  alias ProvChain.Storage.BlockStore
  require Logger

  setup do
    # Stop any running processes (just in case)
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

    stop_with_retry.(Store)
    stop_with_retry.(BlockStore)

    # Reset Mnesia
    :mnesia.stop()
    :mnesia.delete_schema([node()])
    mnesia_dir = Application.fetch_env!(:mnesia, :dir) |> to_string()
    File.rm_rf!(mnesia_dir)
    File.mkdir_p!(mnesia_dir)
    :mnesia.create_schema([node()])
    :mnesia.start()
    :mnesia.wait_for_tables([:schema], 30_000)

    # Create BlockStore tables
    storage = [ram_copies: [node()]]
    :mnesia.create_table(BlockStore.blocks_table(), [attributes: [:hash, :data], type: :set] ++ storage)
    :mnesia.create_table(BlockStore.transactions_table(), [attributes: [:hash, :data], type: :set] ++ storage)
    :mnesia.create_table(BlockStore.height_index_table(), [attributes: [:height, :hash, :timestamp], type: :bag] ++ storage)
    :mnesia.create_table(BlockStore.type_index_table(), [attributes: [:type, :hash, :timestamp], type: :bag] ++ storage)
    :mnesia.wait_for_tables(
      [
        BlockStore.blocks_table(),
        BlockStore.transactions_table(),
        BlockStore.height_index_table(),
        BlockStore.type_index_table()
      ],
      30_000
    )

    # Start processes
    {:ok, block_pid} = BlockStore.start_link([])
    {:ok, store_pid} = Store.start_link([])

    # Cleanup on exit
    on_exit(fn ->
      if Process.alive?(store_pid), do: GenServer.stop(store_pid, :normal, 5000)
      if Process.alive?(block_pid), do: GenServer.stop(block_pid, :normal, 5000)
      :mnesia.stop()
    end)

    {:ok, %{store_pid: store_pid, block_pid: block_pid}}
  end

  describe "add_transaction/1 and graph/0" do
    test "adding transactions increases the triple count" do
      tx1 = ProvOData.milk_collection_transaction()
      assert :ok == Store.add_transaction(tx1)

      g1 = Store.graph()
      count1 = RDF.Graph.triple_count(g1)
      assert count1 > 0

      tx2 = ProvOData.milk_processing_transaction(tx1["prov:entity"]["id"])
      assert :ok == Store.add_transaction(tx2)

      g2 = Store.graph()
      count2 = RDF.Graph.triple_count(g2)
      assert count2 > count1
    end
  end
end
