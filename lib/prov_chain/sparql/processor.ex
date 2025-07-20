defmodule ProvChain.SPARQL.Processor do
  @moduledoc """
  Simple SPARQL query processor for ProvChain RDF data.
  Handles basic SELECT queries for supply chain traceability.
  """

  alias ProvChain.Storage.BlockStore

  @doc """
  Processes a SPARQL query against the blockchain data.
  """
  @spec query(String.t()) :: {:ok, list(map())} | {:error, term()}
  def query(sparql_query) do
    case parse_query(sparql_query) do
      {:ok, parsed} ->
        execute_query(parsed)
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Executes a predefined traceability query.
  """
  @spec trace_entity(String.t()) :: {:ok, list(map())} | {:error, term()}
  def trace_entity(entity_id) do
    # Find all transactions that reference this entity
    case find_transactions_for_entity(entity_id) do
      {:ok, transactions} ->
        trace = build_trace_from_transactions(transactions, entity_id)
        {:ok, trace}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Finds all products derived from a source entity.
  """
  @spec find_derived_products(String.t()) :: {:ok, list(map())} | {:error, term()}
  def find_derived_products(source_entity_id) do
    case find_all_transactions() do
      {:ok, transactions} ->
        derived = find_derivation_chain(transactions, source_entity_id)
        {:ok, derived}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Finds all supply chain participants for a product.
  """
  @spec find_participants(String.t()) :: {:ok, list(map())} | {:error, term()}
  def find_participants(entity_id) do
    case trace_entity(entity_id) do
      {:ok, trace} ->
        participants =
          trace
          |> Enum.map(& &1["agent"])
          |> Enum.uniq_by(& &1["id"])
        {:ok, participants}
      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private functions

  defp parse_query(sparql_query) do
    # Simple SPARQL parser for basic SELECT queries
    # This is a simplified implementation
    cond do
      String.contains?(sparql_query, "prov:wasDerivedFrom*") ->
        entity_id = extract_entity_id(sparql_query)
        {:ok, {:trace_query, entity_id}}

      String.contains?(sparql_query, "prov:wasDerivedFrom+") ->
        entity_id = extract_entity_id(sparql_query)
        {:ok, {:forward_trace_query, entity_id}}

      true ->
        {:error, :unsupported_query}
    end
  end

  defp execute_query({:trace_query, entity_id}) do
    trace_entity(entity_id)
  end

  defp execute_query({:forward_trace_query, entity_id}) do
    find_derived_products(entity_id)
  end

  defp extract_entity_id(sparql_query) do
    # Extract entity ID from SPARQL query
    # This is a simplified regex-based extraction
    case Regex.run(~r/<([^>]+)>/, sparql_query) do
      [_, entity_id] -> entity_id
      _ -> nil
    end
  end

  defp find_transactions_for_entity(entity_id) do
    case find_all_transactions() do
      {:ok, transactions} ->
        matching_transactions =
          transactions
          |> Enum.filter(&transaction_references_entity?(&1, entity_id))
        {:ok, matching_transactions}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp find_all_transactions do
    # This is a simplified approach - in production you'd want to optimize this
    try do
      all_transactions = collect_all_transactions_from_blocks()
      {:ok, all_transactions}
    rescue
      error ->
        {:error, error}
    end
  end

  defp collect_all_transactions_from_blocks do
    # Get all blocks from storage and extract transactions
    # This is inefficient but works for demonstration
    blocks = get_all_blocks_from_storage()

    blocks
    |> Enum.flat_map(& &1.transactions)
    |> Enum.filter(&is_prov_o_transaction?/1)
  end

  defp get_all_blocks_from_storage do
    # This is a very simplified approach
    # In production, you'd want proper indexing
    try do
      # Get blocks by height starting from 0
      get_blocks_by_height_range(0, 1000) # Arbitrary upper limit
    rescue
      _ -> []
    end
  end

  defp get_blocks_by_height_range(start_height, end_height) do
    start_height..end_height
    |> Enum.flat_map(fn height ->
      case BlockStore.get_blocks_by_height(height) do
        {:ok, blocks} -> blocks
        {:error, _} -> []
      end
    end)
  end

  defp is_prov_o_transaction?(transaction) do
    Map.has_key?(transaction, "prov:entity") and
    Map.has_key?(transaction, "prov:activity") and
    Map.has_key?(transaction, "prov:agent")
  end

  defp transaction_references_entity?(transaction, entity_id) do
    transaction["prov:entity"]["id"] == entity_id or
    entity_referenced_in_relations?(transaction["prov:relations"], entity_id)
  end

  defp entity_referenced_in_relations?(relations, entity_id) when is_map(relations) do
    relations
    |> Map.values()
    |> Enum.any?(fn relation ->
      relation["entity"] == entity_id or
      relation["usedEntity"] == entity_id or
      relation["generatedEntity"] == entity_id
    end)
  end
  defp entity_referenced_in_relations?(_, _), do: false

  defp build_trace_from_transactions(transactions, target_entity_id) do
    # Build a chronological trace from the transactions
    transactions
    |> Enum.sort_by(&get_transaction_timestamp/1)
    |> Enum.map(&extract_trace_info/1)
    |> build_derivation_chain(target_entity_id)
  end

  defp find_derivation_chain(transactions, source_entity_id) do
    # Find all entities derived from the source
    derived_map = build_derivation_map(transactions)
    find_all_derived_entities(derived_map, source_entity_id, [])
  end

  defp build_derivation_map(transactions) do
    transactions
    |> Enum.reduce(%{}, fn tx, acc ->
      case get_in(tx, ["prov:relations", "wasDerivedFrom"]) do
        %{"generatedEntity" => generated, "usedEntity" => used} ->
          Map.update(acc, used, [generated], &[generated | &1])
        _ ->
          acc
      end
    end)
  end

  defp find_all_derived_entities(derivation_map, entity_id, visited) do
    if entity_id in visited do
      []
    else
      direct_derived = Map.get(derivation_map, entity_id, [])

      indirect_derived =
        direct_derived
        |> Enum.flat_map(&find_all_derived_entities(derivation_map, &1, [entity_id | visited]))

      direct_derived ++ indirect_derived
    end
  end

  defp build_derivation_chain(trace_infos, target_entity_id) do
    # Build a chain of derivations leading to the target entity
    trace_infos
    |> Enum.reverse()
    |> build_chain_recursive(target_entity_id, [])
  end

  defp build_chain_recursive([], _target, acc), do: Enum.reverse(acc)
  defp build_chain_recursive([trace_info | rest], target, acc) do
    if trace_info["entity"]["id"] == target do
      # Found the target, include it and look for its source
      new_target = get_used_entity_from_trace(trace_info)
      build_chain_recursive(rest, new_target, [trace_info | acc])
    else
      build_chain_recursive(rest, target, acc)
    end
  end

  defp get_transaction_timestamp(transaction) do
    transaction["timestamp"] || 0
  end

  defp extract_trace_info(transaction) do
    %{
      "entity" => transaction["prov:entity"],
      "activity" => transaction["prov:activity"],
      "agent" => transaction["prov:agent"],
      "timestamp" => get_transaction_timestamp(transaction),
      "relations" => transaction["prov:relations"]
    }
  end

  defp get_used_entity_from_trace(trace_info) do
    case get_in(trace_info, ["relations", "used", "entity"]) do
      nil -> nil
      entity_id -> entity_id
    end
  end
end
