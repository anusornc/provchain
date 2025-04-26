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
    # read all transaction records from Mnesia
    {:atomic, records} =
      :mnesia.transaction(fn ->
        :mnesia.match_object({:transactions, :_, :_})
      end)

    # Extract and decode each transaction map
    tx_list =
      records
      |> Enum.map(fn {_, _hash, bin} ->
        :erlang.binary_to_term(bin)
      end)

    # Fold all transactions into one graph
    Enum.reduce(tx_list, Graph.new([], prefixes: Builder.prefixes()), fn tx, acc ->
      Builder.build_graph(tx)
      |> then(&RDF.Data.merge(acc, &1))
    end)
  end
end
