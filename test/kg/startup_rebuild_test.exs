defmodule ProvChain.KG.StartupRebuildTest do
  use ExUnit.Case, async: false

  alias ProvChain.KG.Store
  alias ProvChain.Test.ProvOData
  alias ProvChain.Storage.BlockStore
  import RDF.Sigils
  require Logger

  @sparql """
  PREFIX prov: <http://www.w3.org/ns/prov#>
  SELECT ?s WHERE {
    ?s a prov:Entity .
  }
  """

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

    :mnesia.create_table(
      BlockStore.blocks_table(),
      [attributes: [:hash, :data], type: :set] ++ storage
    )

    :mnesia.create_table(
      BlockStore.transactions_table(),
      [attributes: [:hash, :data], type: :set] ++ storage
    )

    :mnesia.create_table(
      BlockStore.height_index_table(),
      [attributes: [:height, :hash, :timestamp], type: :bag] ++ storage
    )

    :mnesia.create_table(
      BlockStore.type_index_table(),
      [attributes: [:type, :hash, :timestamp], type: :bag] ++ storage
    )

    :mnesia.wait_for_tables(
      [
        BlockStore.blocks_table(),
        BlockStore.transactions_table(),
        BlockStore.height_index_table(),
        BlockStore.type_index_table()
      ],
      30_000
    )

    # Start BlockStore
    {:ok, block_pid} = BlockStore.start_link([])

    # Write sample transaction
    tx = ProvOData.milk_collection_transaction()

    :mnesia.transaction(fn ->
      :mnesia.write({BlockStore.transactions_table(), tx["hash"], :erlang.term_to_binary(tx)})
    end)

    # Remove snapshot
    File.rm_rf!("data/graph.ttl")

    # Start Store
    {:ok, store_pid} = Store.start_link([])

    # Cleanup on exit
    on_exit(fn ->
      if Process.alive?(store_pid), do: GenServer.stop(store_pid, :normal, 5000)
      if Process.alive?(block_pid), do: GenServer.stop(block_pid, :normal, 5000)
      :mnesia.stop()
    end)

    {:ok, %{store_pid: store_pid, block_pid: block_pid, tx: tx}}
  end

  test "on startup, Store rebuilds graph from existing Mnesia transactions", %{tx: tx} do
    graph = Store.graph()

    # Should have at least one prov:Entity triple
    {:ok, result} = ProvChain.SPARQL.Engine.query(@sparql, graph)
    [%{"s" => subject}] = result.results

    assert subject == ~i<prov:#{tx["prov:entity"]["id"]}>
  end
end
