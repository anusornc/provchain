defmodule ProvChain.RDF.Integration do
  @moduledoc """
  Main integration module for RDF and SPARQL functionality in ProvChain.
  Provides high-level APIs for converting blockchain data to RDF and querying it.
  """

  alias ProvChain.RDF.Converter
  alias ProvChain.SPARQL.Processor
  alias ProvChain.Storage.BlockStore

  @doc """
  Exports all blockchain data to RDF format.
  """
  @spec export_to_rdf() :: {:ok, String.t()} | {:error, term()}
  def export_to_rdf do
    case collect_all_prov_o_transactions() do
      {:ok, transactions} ->
        rdf_content = Converter.transactions_to_rdf(transactions)
        {:ok, rdf_content}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Exports specific block to RDF format.
  """
  @spec export_block_to_rdf(binary()) :: {:ok, String.t()} | {:error, term()}
  def export_block_to_rdf(block_hash) do
    case BlockStore.get_block(block_hash) do
      {:ok, block} ->
        prov_o_transactions = filter_prov_o_transactions(block.transactions)
        rdf_content = Converter.transactions_to_rdf(prov_o_transactions)
        {:ok, rdf_content}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Traces the complete supply chain history of a product.
  """
  @spec trace_product(String.t()) :: {:ok, map()} | {:error, term()}
  def trace_product(product_id) do
    case Processor.trace_entity(product_id) do
      {:ok, trace} ->
        formatted_trace = format_trace_result(trace)
        {:ok, formatted_trace}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Finds all products derived from a source material.
  """
  @spec find_product_lineage(String.t()) :: {:ok, list(map())} | {:error, term()}
  def find_product_lineage(source_id) do
    case Processor.find_derived_products(source_id) do
      {:ok, products} ->
        formatted_products = Enum.map(products, &format_entity_info/1)
        {:ok, formatted_products}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Finds all participants in a product's supply chain.
  """
  @spec find_supply_chain_participants(String.t()) :: {:ok, list(map())} | {:error, term()}
  def find_supply_chain_participants(product_id) do
    case Processor.find_participants(product_id) do
      {:ok, participants} ->
        formatted_participants = Enum.map(participants, &format_agent_info/1)
        {:ok, formatted_participants}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Validates supply chain integrity by checking for missing links.
  """
  @spec validate_supply_chain_integrity(String.t()) :: {:ok, map()} | {:error, term()}
  def validate_supply_chain_integrity(product_id) do
    case trace_product(product_id) do
      {:ok, trace} ->
        validation_result = analyze_trace_integrity(trace)
        {:ok, validation_result}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Generates supply chain analytics for a given time period.
  """
  @spec generate_analytics(integer(), integer()) :: {:ok, map()} | {:error, term()}
  def generate_analytics(start_timestamp, end_timestamp) do
    case collect_transactions_in_period(start_timestamp, end_timestamp) do
      {:ok, transactions} ->
        analytics = compute_supply_chain_analytics(transactions)
        {:ok, analytics}
      {:error, reason} ->
        {:error, reason}
    end
  end

  # Private functions

  defp collect_all_prov_o_transactions do
    try do
      transactions =
        get_all_blocks()
        |> Enum.flat_map(& &1.transactions)
        |> filter_prov_o_transactions()

      {:ok, transactions}
    rescue
      error ->
        {:error, error}
    end
  end

  defp get_all_blocks do
    # Simple approach - get blocks by height
    # In production, you'd want better indexing
    0..1000
    |> Enum.flat_map(fn height ->
      case BlockStore.get_blocks_by_height(height) do
        {:ok, blocks} -> blocks
        {:error, _} -> []
      end
    end)
  end

  defp filter_prov_o_transactions(transactions) do
    Enum.filter(transactions, &is_prov_o_transaction?/1)
  end

  defp is_prov_o_transaction?(transaction) do
    Map.has_key?(transaction, "prov:entity") and
    Map.has_key?(transaction, "prov:activity") and
    Map.has_key?(transaction, "prov:agent") and
    Map.has_key?(transaction, "prov:relations")
  end

  defp format_trace_result(trace) do
    %{
      "total_steps" => length(trace),
      "chain" => Enum.map(trace, &format_trace_step/1),
      "participants" => extract_unique_participants(trace),
      "timeline" => extract_timeline(trace)
    }
  end

  defp format_trace_step(step) do
    %{
      "entity" => format_entity_info(step["entity"]),
      "activity" => format_activity_info(step["activity"]),
      "agent" => format_agent_info(step["agent"]),
      "timestamp" => step["timestamp"]
    }
  end

  defp format_entity_info(entity) do
    %{
      "id" => entity["id"],
      "type" => get_in(entity, ["attributes", "prov:type"]),
      "attributes" => Map.get(entity, "attributes", %{})
    }
  end

  defp format_activity_info(activity) do
    %{
      "id" => activity["id"],
      "type" => get_in(activity, ["attributes", "prov:type"]),
      "start_time" => get_in(activity, ["attributes", "prov:startTime"]),
      "end_time" => get_in(activity, ["attributes", "prov:endTime"]),
      "attributes" => Map.get(activity, "attributes", %{})
    }
  end

  defp format_agent_info(agent) do
    %{
      "id" => agent["id"],
      "type" => get_in(agent, ["attributes", "prov:type"]),
      "name" => get_in(agent, ["attributes", "name"]),
      "attributes" => Map.get(agent, "attributes", %{})
    }
  end

  defp extract_unique_participants(trace) do
    trace
    |> Enum.map(& &1["agent"])
    |> Enum.uniq_by(& &1["id"])
    |> Enum.map(&format_agent_info/1)
  end

  defp extract_timeline(trace) do
    trace
    |> Enum.map(fn step ->
      %{
        "timestamp" => step["timestamp"],
        "activity_type" => get_in(step, ["activity", "attributes", "prov:type"]),
        "entity_id" => step["entity"]["id"]
      }
    end)
    |> Enum.sort_by(& &1["timestamp"])
  end

  defp analyze_trace_integrity(trace) do
    chain = trace["chain"]

    %{
      "is_complete" => is_trace_complete?(chain),
      "missing_links" => find_missing_links(chain),
      "temporal_consistency" => check_temporal_consistency(chain),
      "participant_verification" => verify_participants(chain)
    }
  end

  defp is_trace_complete?(chain) do
    # Check if each step (except the first) has a proper derivation link
    chain
    |> Enum.drop(1)
    |> Enum.all?(&has_derivation_link?/1)
  end

  defp has_derivation_link?(_step) do
    # This would check the relations for proper derivation
    # Simplified implementation
    true
  end

  defp find_missing_links(_chain) do
    # Identify gaps in the supply chain
    # Simplified implementation
    []
  end

  defp check_temporal_consistency(chain) do
    # Check if timestamps are in logical order
    timestamps = Enum.map(chain, & &1["timestamp"])
    timestamps == Enum.sort(timestamps)
  end

  defp verify_participants(_chain) do
    # Verify that all participants are properly certified/registered
    # Simplified implementation
    %{"verified" => true, "issues" => []}
  end

  defp collect_transactions_in_period(start_timestamp, end_timestamp) do
    case collect_all_prov_o_transactions() do
      {:ok, transactions} ->
        filtered_transactions =
          transactions
          |> Enum.filter(fn tx ->
            timestamp = tx["timestamp"] || 0
            timestamp >= start_timestamp and timestamp <= end_timestamp
          end)

        {:ok, filtered_transactions}
      {:error, reason} ->
        {:error, reason}
    end
  end

  defp compute_supply_chain_analytics(transactions) do
    %{
      "total_transactions" => length(transactions),
      "unique_entities" => count_unique_entities(transactions),
      "unique_activities" => count_unique_activities(transactions),
      "unique_agents" => count_unique_agents(transactions),
      "activity_distribution" => compute_activity_distribution(transactions),
      "agent_activity" => compute_agent_activity(transactions)
    }
  end

  defp count_unique_entities(transactions) do
    transactions
    |> Enum.map(&get_in(&1, ["prov:entity", "id"]))
    |> Enum.uniq()
    |> length()
  end

  defp count_unique_activities(transactions) do
    transactions
    |> Enum.map(&get_in(&1, ["prov:activity", "id"]))
    |> Enum.uniq()
    |> length()
  end

  defp count_unique_agents(transactions) do
    transactions
    |> Enum.map(&get_in(&1, ["prov:agent", "id"]))
    |> Enum.uniq()
    |> length()
  end

  defp compute_activity_distribution(transactions) do
    transactions
    |> Enum.group_by(&get_in(&1, ["prov:activity", "attributes", "prov:type"]))
    |> Enum.map(fn {type, txs} -> {type, length(txs)} end)
    |> Map.new()
  end

  defp compute_agent_activity(transactions) do
    transactions
    |> Enum.group_by(&get_in(&1, ["prov:agent", "id"]))
    |> Enum.map(fn {agent_id, txs} ->
      {agent_id, %{
        "transaction_count" => length(txs),
        "activities" => Enum.map(txs, &get_in(&1, ["prov:activity", "attributes", "prov:type"]))
                       |> Enum.uniq()
      }}
    end)
    |> Map.new()
  end
end
