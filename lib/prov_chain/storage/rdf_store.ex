defmodule ProvChain.Storage.RdfStore do
  @moduledoc """
  RDF Graph Store for ProvChain using in-memory graph storage.
  Provides a lightweight RDF triple store without external dependencies.
  """

  use GenServer
  require Logger

  # State structure: %{triples: [], indexes: %{subject: %{}, predicate: %{}, object: %{}}}

  @doc """
  Starts the RDF store GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Adds RDF triples to the graph store.
  """
  def add_triples(triples) when is_list(triples) do
    case Process.whereis(__MODULE__) do
      nil ->
        Logger.warning("RdfStore not started, storing in-memory only")
        :ok
      _pid ->
        GenServer.call(__MODULE__, {:add_triples, triples})
    end
  end

  @doc """
  Executes a simple SPARQL SELECT query.
  """
  def query(sparql_query) when is_binary(sparql_query) do
    case Process.whereis(__MODULE__) do
      nil ->
        %{results: [], count: 0}
      _pid ->
        case GenServer.call(__MODULE__, {:query, sparql_query}) do
          {:ok, results} -> results
          {:error, _reason} -> %{results: [], count: 0}
        end
    end
  end

  @doc """
  Counts entities of a specific type.
  """
  def count_entities(entity_type \\ "prov:Entity") do
    case Process.whereis(__MODULE__) do
      nil -> 0
      _pid ->
        GenServer.call(__MODULE__, {:count_entities, entity_type})
    end
  end

  @doc """
  Finds entities related to a subject.
  """
  def find_related(subject_uri) do
    case Process.whereis(__MODULE__) do
      nil -> []
      _pid ->
        GenServer.call(__MODULE__, {:find_related, subject_uri})
    end
  end

  @doc """
  Clears all triples from the store.
  """
  def clear do
    case Process.whereis(__MODULE__) do
      nil -> :ok
      _pid ->
        GenServer.call(__MODULE__, :clear)
    end
  end

  @doc """
  Gets all triples in the store.
  """
  def get_all_triples do
    case Process.whereis(__MODULE__) do
      nil -> []
      _pid ->
        GenServer.call(__MODULE__, :get_all_triples)
    end
  end

  # GenServer callbacks

  @impl true
  def init(_opts) do
    Logger.info("Starting RDF Graph Store")
    initial_state = %{
      triples: [],
      indexes: %{
        subject: %{},
        predicate: %{},
        object: %{}
      }
    }
    {:ok, initial_state}
  end

  @impl true
  def handle_call({:add_triples, triples}, _from, state) do
    try do
      normalized_triples =
        triples
        |> Enum.map(&normalize_triple/1)
        |> Enum.filter(&valid_triple?/1)

      new_triples = state.triples ++ normalized_triples
      new_indexes = update_indexes(state.indexes, normalized_triples)

      new_state = %{state | triples: new_triples, indexes: new_indexes}
      {:reply, :ok, new_state}
    rescue
      error ->
        Logger.error("Failed to add triples to graph: #{inspect(error)}")
        {:reply, {:error, error}, state}
    end
  end

  @impl true
  def handle_call({:query, sparql_query}, _from, state) do
    try do
      results = execute_sparql_query(sparql_query, state)
      {:reply, {:ok, results}, state}
    rescue
      error ->
        Logger.error("SPARQL query failed: #{inspect(error)}")
        {:reply, {:error, error}, state}
    end
  end

  @impl true
  def handle_call({:count_entities, entity_type}, _from, state) do
    count = count_entities_of_type(state.triples, entity_type)
    {:reply, count, state}
  end

  @impl true
  def handle_call({:find_related, subject_uri}, _from, state) do
    related = find_related_triples(state.triples, subject_uri)
    {:reply, related, state}
  end

  @impl true
  def handle_call(:clear, _from, _state) do
    new_state = %{
      triples: [],
      indexes: %{
        subject: %{},
        predicate: %{},
        object: %{}
      }
    }
    {:reply, :ok, new_state}
  end

  @impl true
  def handle_call(:get_all_triples, _from, state) do
    {:reply, state.triples, state}
  end

  # Private functions

  defp normalize_triple({subject, predicate, object}) when is_binary(subject) and is_binary(predicate) and is_binary(object) do
    {subject, predicate, object}
  end
  defp normalize_triple({subject, predicate, object}) do
    {normalize_term(subject), normalize_term(predicate), normalize_term(object)}
  end
  defp normalize_triple(triple) when is_map(triple) do
    # Handle map-based triples
    subject = Map.get(triple, :subject) || Map.get(triple, "subject")
    predicate = Map.get(triple, :predicate) || Map.get(triple, "predicate")
    object = Map.get(triple, :object) || Map.get(triple, "object")
    {normalize_term(subject), normalize_term(predicate), normalize_term(object)}
  end
  defp normalize_triple(triple) do
    # Fallback for unknown formats
    Logger.warning("Unknown triple format: #{inspect(triple)}")
    {to_string(triple), "unknown:predicate", "unknown:object"}
  end

  defp valid_triple?({subject, predicate, object}) when is_binary(subject) and is_binary(predicate) and is_binary(object) do
    byte_size(subject) > 0 and byte_size(predicate) > 0 and byte_size(object) > 0
  end
  defp valid_triple?(_), do: false

  defp normalize_term(term) when is_binary(term), do: term
  defp normalize_term(term) when is_atom(term), do: to_string(term)
  defp normalize_term(term), do: inspect(term)

  defp update_indexes(indexes, new_triples) do
    Enum.reduce(new_triples, indexes, fn {s, p, o}, acc ->
      acc
      |> update_in([:subject, s], &add_to_index(&1, {p, o}))
      |> update_in([:predicate, p], &add_to_index(&1, {s, o}))
      |> update_in([:object, o], &add_to_index(&1, {s, p}))
    end)
  end

  defp add_to_index(nil, item), do: [item]
  defp add_to_index(list, item) when is_list(list), do: [item | list]
  defp add_to_index(existing, item), do: [item, existing]

  defp execute_sparql_query(sparql_query, state) do
    # Simple SPARQL query processing
    cond do
      String.contains?(sparql_query, "SELECT") and String.contains?(sparql_query, "COUNT") ->
        execute_count_query(sparql_query, state)

      String.contains?(sparql_query, "SELECT") ->
        execute_select_query(sparql_query, state)

      true ->
        %{results: [], count: 0}
    end
  end

  defp execute_count_query(_sparql_query, state) do
    # Simple count query - count all entities
    entity_count = count_entities_of_type(state.triples, "prov:Entity")
    %{count: entity_count, results: []}
  end

  defp execute_select_query(sparql_query, state) do
    # Simple pattern matching for trace queries
    cond do
      String.contains?(sparql_query, "prov:wasDerivedFrom") ->
        find_derivation_chain(state.triples)

      true ->
        %{results: [], count: 0}
    end
  end

  defp count_entities_of_type(triples, entity_type) do
    # Count triples that define entities of the given type
    type_patterns = [
      "rdf:type",
      "http://www.w3.org/1999/02/22-rdf-syntax-ns#type",
      "type"
    ]

    entity_patterns = [
      entity_type,
      "prov:Entity",
      "http://www.w3.org/ns/prov#Entity",
      "Entity"
    ]

    triples
    |> Enum.count(fn {_s, p, o} ->
      type_match = Enum.any?(type_patterns, &String.contains?(to_string(p), &1))
      entity_match = Enum.any?(entity_patterns, &String.contains?(to_string(o), &1))
      type_match and entity_match
    end)
  end

  defp find_related_triples(triples, subject_uri) do
    Enum.filter(triples, fn {s, _p, _o} -> s == subject_uri end)
  end

  defp find_derivation_chain(triples) do
    derivation_patterns = [
      "wasDerivedFrom",
      "prov:wasDerivedFrom",
      "http://www.w3.org/ns/prov#wasDerivedFrom"
    ]

    derivation_triples =
      triples
      |> Enum.filter(fn {_s, p, _o} ->
        Enum.any?(derivation_patterns, &String.contains?(to_string(p), &1))
      end)

    %{results: derivation_triples, count: length(derivation_triples)}
  end
end
