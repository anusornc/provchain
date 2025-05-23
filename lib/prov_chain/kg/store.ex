defmodule ProvChain.KG.Store do
  @moduledoc """
  GenServer that holds an in-memory RDF.Graph built from
  PROV-O transactions stored in Mnesia. On startup, it
  rebuilds the graph from all existing transactions, and
  supports adding new transactions dynamically.
  """

  use GenServer
  alias ProvChain.KG.Builder
  alias RDF.Graph
  alias ProvChain.Storage.BlockStore # Added alias
  require Logger # Added require

  # Public API

  @doc "Start the KG Store process"
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "Get the current RDF graph"
  @spec graph() :: RDF.Graph.t()
  def graph do
    GenServer.call(__MODULE__, :graph)
  end

  @doc "Add a PROV-O transaction map to the graph"
  @spec add_transaction(map()) :: :ok
  def add_transaction(tx) do
    GenServer.call(__MODULE__, {:add, tx})
  end

  # GenServer callbacks

  @impl true
  def init(_args) do
    # Build initial graph from existing Mnesia transactions
    initial_graph = rebuild_graph()
    {:ok, initial_graph}
  end

  @impl true
  def handle_call(:graph, _from, graph) do
    {:reply, graph, graph}
  end

  @impl true
  def handle_call({:add, tx}, _from, graph) do
    # Build a graph for this transaction and merge
    tx_graph = Builder.build_graph(tx)
    new_graph = RDF.Data.merge(graph, tx_graph)
    {:reply, :ok, new_graph}
  end

  # Private helpers

  defp rebuild_graph do
    Logger.info("Rebuilding graph from Mnesia...")

    table_name = BlockStore.transactions_table()
    Logger.debug("Attempting to read from Mnesia table: #{inspect(table_name)}")

    mnesia_result =
      :mnesia.transaction(fn ->
        :mnesia.match_object({table_name, :_, :_})
      end)

    Logger.debug("Mnesia match_object result for table #{inspect(table_name)}: #{inspect(mnesia_result)}")

    case mnesia_result do
      {:atomic, records} ->
        Logger.info(
          "Found #{length(records)} records in Mnesia for table #{inspect(table_name)}."
        )

        tx_list =
          records
          |> Enum.map(fn
            {^table_name, _hash, bin} -> # Changed hash to _hash
              # Logger.debug("Processing record from table #{inspect(table_name)} with hash #{inspect(hash)}")
              :erlang.binary_to_term(bin)
            {other_table, _, _} ->
              Logger.warning("Skipping record from unexpected table: #{inspect(other_table)}") # Changed Logger.warn to Logger.warning
              nil
          end)
          |> Enum.reject(&is_nil/1)

        Logger.info("Successfully decoded #{length(tx_list)} transactions from table #{inspect(table_name)}.")

        final_graph =
          Enum.reduce(tx_list, Graph.new([], prefixes: Builder.prefixes()), fn tx, acc ->
            single_tx_graph = Builder.build_graph(tx)
            RDF.Data.merge(acc, single_tx_graph)
          end)

        Logger.info(
          "Finished rebuilding graph. Total triples: #{RDF.Graph.triple_count(final_graph)}"
        )

        final_graph

      {:aborted, reason} ->
        Logger.error(
          "Mnesia transaction aborted in rebuild_graph for table #{inspect(table_name)}: #{inspect(reason)}"
        )

        Graph.new([], prefixes: Builder.prefixes())
    end
  end
end
