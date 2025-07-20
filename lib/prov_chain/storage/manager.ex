defmodule ProvChain.Storage.Manager do
  @moduledoc """
  Storage manager for coordinating between different storage layers.
  Manages block and transaction storage across memory, disk, and RDF stores.
  """

  alias ProvChain.Storage.{BlockStore, MemoryStore, RdfStore}
  require Logger

  @doc """
  Stores a block across all storage layers.
  """
  def store_block(block) do
    with :ok <- BlockStore.put_block(block),
         :ok <- MemoryStore.put_block(block.hash, block),
         :ok <- store_block_in_rdf(block) do
      {:ok, block}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Stores a transaction across relevant storage layers.
  """
  def store_transaction(tx) when is_map(tx) and is_map_key(tx, "hash") do
    with :ok <- BlockStore.put_transaction(tx),
         :ok <- MemoryStore.put_transaction(tx["hash"], tx),
         :ok <- store_transaction_in_rdf(tx) do
      {:ok, tx}
    else
      {:error, reason} -> {:error, reason}
    end
  end
  def store_transaction(_), do: {:error, :invalid_transaction}

  @doc """
  Traces a product to its origin using RDF store.
  """
  def trace_to_origin(product_iri) do
    # Use RDF store for complex traceability queries
    case RdfStore.find_related(product_iri) do
      [] -> {:error, :not_found}
      relations -> {:ok, build_trace_from_relations(relations)}
    end
  end

  @doc """
  Analyzes contamination impact using RDF store.
  """
  def contamination_impact(batch_iri) do
    # Find all entities derived from the contaminated batch
    related = RdfStore.find_related(batch_iri)
    impact_analysis = analyze_contamination_impact(related)
    {:ok, impact_analysis}
  end

  @doc """
  Gets the supply chain network for an entity.
  """
  def get_supply_chain_network(entity_iri) do
    # Build network graph from RDF store
    case RdfStore.find_related(entity_iri) do
      [] -> {:ok, %{nodes: [], edges: []}}
      relations -> {:ok, build_network_graph(entity_iri, relations)}
    end
  end

  @doc """
  Gets blocks by height from appropriate storage layer.
  """
  def get_blocks_by_height(height) do
    # Try memory first, then disk
    case MemoryStore.get_tip_set() do
      [] -> BlockStore.get_blocks_by_height(height)
      _tips ->
        case BlockStore.get_blocks_by_height(height) do
          {:ok, blocks} -> {:ok, blocks}
          {:error, _} -> {:ok, []}
        end
    end
  end

  @doc """
  Gets blocks by type from block store.
  """
  def get_blocks_by_type(type) do
    BlockStore.get_blocks_by_type(type)
  end

  # Private functions

  defp store_block_in_rdf(block) do
    # Convert block to RDF triples if it contains PROV-O transactions
    try do
      if has_prov_o_transactions?(block.transactions) do
        rdf_triples = convert_block_to_rdf_triples(block)
        RdfStore.add_triples(rdf_triples)
      else
        :ok
      end
    rescue
      _error ->
        Logger.warning("Failed to store block #{block.hash} in RDF store")
        :ok # Don't fail the entire operation
    end
  end

  defp store_transaction_in_rdf(tx) do
    # Convert transaction to RDF triples if it's PROV-O compliant
    try do
      if is_prov_o_transaction?(tx) do
        rdf_triples = convert_transaction_to_rdf_triples(tx)
        RdfStore.add_triples(rdf_triples)
      else
        :ok
      end
    rescue
      _error ->
        Logger.warning("Failed to store transaction #{tx["hash"]} in RDF store")
        :ok # Don't fail the entire operation
    end
  end

  defp has_prov_o_transactions?(transactions) when is_list(transactions) do
    Enum.any?(transactions, &is_prov_o_transaction?/1)
  end
  defp has_prov_o_transactions?(_), do: false

  defp is_prov_o_transaction?(tx) when is_map(tx) do
    Map.has_key?(tx, "prov:entity") and
    Map.has_key?(tx, "prov:activity") and
    Map.has_key?(tx, "prov:agent") and
    Map.has_key?(tx, "prov:relations")
  end
  defp is_prov_o_transaction?(_), do: false

  defp convert_block_to_rdf_triples(block) do
    # Simple conversion of block to RDF triples
    block_iri = "provchain:block/#{Base.encode16(block.hash)}"

    [
      {block_iri, "rdf:type", "provchain:Block"},
      {block_iri, "provchain:height", "#{block.height}"},
      {block_iri, "provchain:timestamp", "#{block.timestamp}"},
      {block_iri, "provchain:supply_chain_type", block.supply_chain_type}
    ]
  end

  defp convert_transaction_to_rdf_triples(tx) do
    # Convert PROV-O transaction to RDF triples
    entity_iri = "provchain:entity/#{tx["prov:entity"]["id"]}"
    activity_iri = "provchain:activity/#{tx["prov:activity"]["id"]}"
    agent_iri = "provchain:agent/#{tx["prov:agent"]["id"]}"

    [
      # Entity triples
      {entity_iri, "rdf:type", "prov:Entity"},
      {entity_iri, "rdf:type", tx["prov:entity"]["attributes"]["prov:type"] || "Entity"},

      # Activity triples
      {activity_iri, "rdf:type", "prov:Activity"},
      {activity_iri, "rdf:type", tx["prov:activity"]["attributes"]["prov:type"] || "Activity"},

      # Agent triples
      {agent_iri, "rdf:type", "prov:Agent"},
      {agent_iri, "rdf:type", tx["prov:agent"]["attributes"]["prov:type"] || "Agent"},

      # Relationships
      {entity_iri, "prov:wasGeneratedBy", activity_iri},
      {entity_iri, "prov:wasAttributedTo", agent_iri},
      {activity_iri, "prov:wasAssociatedWith", agent_iri}
    ]
  end

  defp build_trace_from_relations(relations) do
    %{
      total_relations: length(relations),
      trace_chain: relations,
      summary: "Trace chain with #{length(relations)} relationships"
    }
  end

  defp analyze_contamination_impact(relations) do
    %{
      total_affected: length(relations),
      impact_level: if(length(relations) > 10, do: "high", else: "medium"),
      affected_entities: relations,
      recommended_actions: ["quarantine", "trace_forward", "notify_authorities"]
    }
  end

  defp build_network_graph(entity_iri, relations) do
    nodes = [%{id: entity_iri, type: "entity"}]
    edges = Enum.map(relations, fn {_s, p, o} ->
      %{source: entity_iri, target: o, relationship: p}
    end)

    %{
      nodes: nodes,
      edges: edges,
      total_nodes: length(nodes),
      total_edges: length(edges)
    }
  end
end
