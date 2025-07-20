defmodule ProvChain.KnowledgeGraph.QueryEngine do
  @moduledoc """
  Simple SPARQL-like query engine for ProvChain knowledge graphs.
  Uses internal graph storage instead of external RDF libraries.
  """

  alias ProvChain.KnowledgeGraph.GraphStore

  @doc """
  Executes a simple query against the knowledge graph.
  """
  def execute_query(query_map) when is_map(query_map) do
    select = Map.get(query_map, :select, [])
    where = Map.get(query_map, :where, [])

    # Simple query execution using our graph store
    results = execute_where_patterns(where)

    %{
      results: results,
      count: length(results),
      bindings: select
    }
  end

  @doc """
  Executes a SPARQL-like query string.
  """
  def execute_sparql(sparql_query) when is_binary(sparql_query) do
    # Simple SPARQL parsing and execution
    cond do
      String.contains?(sparql_query, "SELECT") and String.contains?(sparql_query, "COUNT") ->
        execute_count_query(sparql_query)

      String.contains?(sparql_query, "SELECT") ->
        execute_select_query(sparql_query)

      String.contains?(sparql_query, "ASK") ->
        execute_ask_query(sparql_query)

      true ->
        %{results: [], count: 0, type: :unknown}
    end
  end

  @doc """
  Finds entities by type.
  """
  def find_entities_by_type(entity_type) do
    type_patterns = [
      "rdf:type",
      "http://www.w3.org/1999/02/22-rdf-syntax-ns#type",
      "type"
    ]

    # Find all triples that define entity types
    all_triples = GraphStore.get_all_triples()

    entities =
      all_triples
      |> Enum.filter(fn {_s, p, o} ->
        type_match = Enum.any?(type_patterns, &String.contains?(to_string(p), &1))
        entity_match = String.contains?(to_string(o), entity_type)
        type_match and entity_match
      end)
      |> Enum.map(fn {s, _p, _o} -> s end)
      |> Enum.uniq()

    %{entities: entities, count: length(entities)}
  end

  @doc """
  Traces relationships from a starting entity.
  """
  def trace_relationships(entity_uri, relationship_type \\ :any) do
    relationships = GraphStore.query_pattern(entity_uri, relationship_type, :any)

    %{
      entity: entity_uri,
      relationships: relationships,
      count: length(relationships)
    }
  end

  @doc """
  Finds the derivation chain for an entity.
  """
  def find_derivation_chain(entity_uri) do
    all_triples = GraphStore.get_all_triples()

    derivation_patterns = [
      "wasDerivedFrom",
      "prov:wasDerivedFrom",
      "http://www.w3.org/ns/prov#wasDerivedFrom"
    ]

    chain = do_find_derivation_chain(all_triples, entity_uri, [], derivation_patterns)

    %{
      entity: entity_uri,
      derivation_chain: chain,
      total_steps: length(chain)
    }
  end

  defp do_find_derivation_chain(_all_triples, nil, chain, _derivation_patterns), do: Enum.reverse(chain)
  defp do_find_derivation_chain(all_triples, current_entity, chain, derivation_patterns) do
    direct_derivation =
      all_triples
      |> Enum.find(fn {s, p, _o} ->
        s == current_entity and Enum.any?(derivation_patterns, &String.contains?(to_string(p), &1))
      end)

    if direct_derivation do
      {s, p, o} = direct_derivation
      do_find_derivation_chain(all_triples, o, [{s, p, o} | chain], derivation_patterns)
    else
      Enum.reverse(chain)
    end
  end

  @doc """
  Finds all entities that were derived from a source entity.
  """
  def find_derived_entities(source_entity_uri) do
    derivation_patterns = [
      "wasDerivedFrom",
      "prov:wasDerivedFrom",
      "http://www.w3.org/ns/prov#wasDerivedFrom"
    ]

    all_triples = GraphStore.get_all_triples()

    derived =
      all_triples
      |> Enum.filter(fn {_s, p, o} ->
        object_match = o == source_entity_uri
        predicate_match = Enum.any?(derivation_patterns, &String.contains?(to_string(p), &1))
        object_match and predicate_match
      end)
      |> Enum.map(fn {s, _p, _o} -> s end)
      |> Enum.uniq()

    %{
      source_entity: source_entity_uri,
      derived_entities: derived,
      count: length(derived)
    }
  end

  @doc """
  Gets graph statistics.
  """
  def get_graph_stats do
    GraphStore.get_stats()
  end

  @doc """
  Gets the complete supply chain network for a given entity.
  This is a placeholder and needs a proper implementation.
  """
  def get_supply_chain_network(entity_iri) do
    # Placeholder implementation: return all triples for now
    all_triples = GraphStore.get_all_triples()
    %{entity: entity_iri, network: all_triples, count: length(all_triples)}
  end

  # Private functions

  defp execute_where_patterns(patterns) when is_list(patterns) do
    # Execute each pattern and intersect results
    Enum.reduce(patterns, [], fn pattern, acc ->
      pattern_results = execute_pattern(pattern)
      if acc == [], do: pattern_results, else: intersect_results(acc, pattern_results)
    end)
  end

  defp execute_pattern({subject, predicate, object}) do
    GraphStore.query_pattern(subject, predicate, object)
  end
  defp execute_pattern(_), do: []

  defp intersect_results(results1, results2) do
    # Simple intersection - in real implementation would be more sophisticated
    results1 ++ results2
  end

  defp execute_count_query(sparql_query) do
    # Extract entity type from query if possible
    entity_type = extract_entity_type(sparql_query)
    result = find_entities_by_type(entity_type)

    %{
      count: result.count,
      type: :count,
      entity_type: entity_type
    }
  end

  defp execute_select_query(sparql_query) do
    cond do
      String.contains?(sparql_query, "wasDerivedFrom") ->
        # Extract entity from query
        entity_uri = extract_entity_uri(sparql_query)
        if entity_uri do
          find_derivation_chain(entity_uri)
        else
          %{results: [], count: 0, type: :select}
        end

      true ->
        %{results: [], count: 0, type: :select}
    end
  end

  defp execute_ask_query(_sparql_query) do
    # Simple ASK query implementation
    %{answer: false, type: :ask}
  end

  defp extract_entity_type(sparql_query) do
    # Simple regex to extract entity type
    case Regex.run(~r/prov:(\w+)|(\w+)/, sparql_query) do
      [_, type] when type != "" -> type
      [_, _, type] when type != "" -> type
      _ -> "Entity"
    end
  end

  defp extract_entity_uri(sparql_query) do
    # Simple regex to extract entity URI
    case Regex.run(~r/<([^>]+)>/, sparql_query) do
      [_, uri] -> uri
      _ -> nil
    end
  end

  
end
