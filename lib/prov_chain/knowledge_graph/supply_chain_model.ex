defmodule ProvChain.KnowledgeGraph.SupplyChainModel do
  @moduledoc """
  Supply Chain Model for creating and managing PROV-O knowledge graphs.
  Uses local URIs instead of external RDF libraries to avoid dependency issues.
  """

  alias ProvChain.Storage.RdfStore

  # Define PROV-O namespace URIs as constants
  @prov_ns "http://www.w3.org/ns/prov#"
  @rdf_ns "http://www.w3.org/1999/02/22-rdf-syntax-ns#"
  @pc_ns "http://provchain.org/ns#"

  # PROV-O terms as string constants (not function calls)
  @prov_entity @prov_ns <> "Entity"
  @prov_activity @prov_ns <> "Activity"
  @prov_agent @prov_ns <> "Agent"
  @prov_generated_at_time @prov_ns <> "generatedAtTime"
  @prov_started_at_time @prov_ns <> "startedAtTime"
  @prov_ended_at_time @prov_ns <> "endedAtTime"
  @prov_was_generated_by @prov_ns <> "wasGeneratedBy"
  @prov_was_attributed_to @prov_ns <> "wasAttributedTo"
  @prov_was_associated_with @prov_ns <> "wasAssociatedWith"
  @prov_used @prov_ns <> "used"
  @prov_was_derived_from @prov_ns <> "wasDerivedFrom"
  @rdf_type @rdf_ns <> "type"

  @doc """
  Creates a complete milk supply chain knowledge graph.
  """
  def create_milk_supply_chain(batch_id, timestamp \\ nil) do
    timestamp = timestamp || :os.system_time(:millisecond)

    # Create entity IRIs
    milk_batch_iri = "#{@pc_ns}batch/#{batch_id}"
    processed_milk_iri = "#{@pc_ns}processed/#{batch_id}_processed"
    packaged_milk_iri = "#{@pc_ns}package/#{batch_id}_packaged"

    # Create activity IRIs
    collection_iri = "#{@pc_ns}activity/collection_#{timestamp}"
    processing_iri = "#{@pc_ns}activity/processing_#{timestamp}"
    packaging_iri = "#{@pc_ns}activity/packaging_#{timestamp}"

    # Create agent IRIs
    farmer_iri = "#{@pc_ns}agent/farmer_#{timestamp}"
    processor_iri = "#{@pc_ns}agent/processor_#{timestamp}"
    packager_iri = "#{@pc_ns}agent/packager_#{timestamp}"

    # Generate all triples
    entity_triples = create_entity_triples(milk_batch_iri, processed_milk_iri, packaged_milk_iri, timestamp)
    activity_triples = create_activity_triples(collection_iri, processing_iri, packaging_iri, timestamp)
    agent_triples = create_agent_triples(farmer_iri, processor_iri, packager_iri)
    relationship_triples = create_relationship_triples(
      {milk_batch_iri, processed_milk_iri, packaged_milk_iri},
      {collection_iri, processing_iri, packaging_iri},
      {farmer_iri, processor_iri, packager_iri}
    )

    all_triples = entity_triples ++ activity_triples ++ agent_triples ++ relationship_triples

    # Add to RDF store
    case RdfStore.add_triples(all_triples) do
      :ok -> {:ok, all_triples}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Queries the milk supply chain for traceability information.
  """
  def query_milk_trace(batch_id) do
    query = """
    SELECT ?entity ?activity ?agent ?time
    WHERE {
      ?entity prov:wasDerivedFrom* <#{@pc_ns}batch/#{batch_id}> .
      ?entity prov:wasGeneratedBy ?activity .
      ?activity prov:wasAssociatedWith ?agent .
      ?activity prov:startedAtTime ?time .
    }
    ORDER BY ?time
    """

    RdfStore.query(query)
  end

  @doc """
  Counts entities in the knowledge graph.
  """
  def count_entities do
    RdfStore.count_entities(@prov_entity)
  end

  # Private functions for creating triples

  defp create_entity_triples(milk_batch_iri, processed_milk_iri, packaged_milk_iri, timestamp) do
    [
      # Milk batch entity
      {milk_batch_iri, @rdf_type, @prov_entity},
      {milk_batch_iri, @rdf_type, "#{@pc_ns}MilkBatch"},
      {milk_batch_iri, "#{@pc_ns}volume", literal("1000.5", "xsd:double")},
      {milk_batch_iri, "#{@pc_ns}quality", literal("Grade A", "xsd:string")},
      {milk_batch_iri, @prov_generated_at_time, literal(format_datetime(timestamp), "xsd:dateTime")},

      # Processed milk entity
      {processed_milk_iri, @rdf_type, @prov_entity},
      {processed_milk_iri, @rdf_type, "#{@pc_ns}ProcessedMilk"},
      {processed_milk_iri, "#{@pc_ns}processType", literal("UHT", "xsd:string")},
      {processed_milk_iri, @prov_generated_at_time, literal(format_datetime(timestamp + 3600), "xsd:dateTime")},

      # Packaged milk entity
      {packaged_milk_iri, @rdf_type, @prov_entity},
      {packaged_milk_iri, @rdf_type, "#{@pc_ns}PackagedMilk"},
      {packaged_milk_iri, "#{@pc_ns}packageType", literal("Tetra Pak", "xsd:string")},
      {packaged_milk_iri, "#{@pc_ns}volume", literal("1.0", "xsd:double")},
      {packaged_milk_iri, @prov_generated_at_time, literal(format_datetime(timestamp + 7200), "xsd:dateTime")}
    ]
  end

  defp create_activity_triples(collection_iri, processing_iri, packaging_iri, timestamp) do
    [
      # Collection activity
      {collection_iri, @rdf_type, @prov_activity},
      {collection_iri, @rdf_type, "#{@pc_ns}MilkCollection"},
      {collection_iri, @prov_started_at_time, literal(format_datetime(timestamp), "xsd:dateTime")},
      {collection_iri, @prov_ended_at_time, literal(format_datetime(timestamp + 1800), "xsd:dateTime")},
      {collection_iri, "#{@pc_ns}location", literal("Farm A", "xsd:string")},

      # Processing activity
      {processing_iri, @rdf_type, @prov_activity},
      {processing_iri, @rdf_type, "#{@pc_ns}MilkProcessing"},
      {processing_iri, @prov_started_at_time, literal(format_datetime(timestamp + 1800), "xsd:dateTime")},
      {processing_iri, @prov_ended_at_time, literal(format_datetime(timestamp + 3600), "xsd:dateTime")},
      {processing_iri, "#{@pc_ns}temperature", literal("135.0", "xsd:double")},

      # Packaging activity
      {packaging_iri, @rdf_type, @prov_activity},
      {packaging_iri, @rdf_type, "#{@pc_ns}Packaging"},
      {packaging_iri, @prov_started_at_time, literal(format_datetime(timestamp + 3600), "xsd:dateTime")},
      {packaging_iri, @prov_ended_at_time, literal(format_datetime(timestamp + 7200), "xsd:dateTime")},
      {packaging_iri, "#{@pc_ns}packagingLine", literal("Line 3", "xsd:string")}
    ]
  end

  defp create_agent_triples(farmer_iri, processor_iri, packager_iri) do
    [
      # Farmer agent
      {farmer_iri, @rdf_type, @prov_agent},
      {farmer_iri, @rdf_type, "#{@pc_ns}Farmer"},
      {farmer_iri, "#{@pc_ns}name", literal("John Smith", "xsd:string")},
      {farmer_iri, "#{@pc_ns}certification", literal("Organic Certified", "xsd:string")},

      # Processor agent
      {processor_iri, @rdf_type, @prov_agent},
      {processor_iri, @rdf_type, "#{@pc_ns}Processor"},
      {processor_iri, "#{@pc_ns}name", literal("Dairy Processing Co.", "xsd:string")},
      {processor_iri, "#{@pc_ns}certification", literal("ISO 9001", "xsd:string")},

      # Packager agent
      {packager_iri, @rdf_type, @prov_agent},
      {packager_iri, @rdf_type, "#{@pc_ns}Packager"},
      {packager_iri, "#{@pc_ns}name", literal("Packaging Solutions Ltd.", "xsd:string")},
      {packager_iri, "#{@pc_ns}certification", literal("Food Safety Certified", "xsd:string")}
    ]
  end

  defp create_relationship_triples({milk_batch_iri, processed_milk_iri, packaged_milk_iri},
                                  {collection_iri, processing_iri, packaging_iri},
                                  {farmer_iri, processor_iri, packager_iri}) do
    [
      # Generation relationships
      {milk_batch_iri, @prov_was_generated_by, collection_iri},
      {processed_milk_iri, @prov_was_generated_by, processing_iri},
      {packaged_milk_iri, @prov_was_generated_by, packaging_iri},

      # Attribution relationships
      {milk_batch_iri, @prov_was_attributed_to, farmer_iri},
      {processed_milk_iri, @prov_was_attributed_to, processor_iri},
      {packaged_milk_iri, @prov_was_attributed_to, packager_iri},

      # Association relationships
      {collection_iri, @prov_was_associated_with, farmer_iri},
      {processing_iri, @prov_was_associated_with, processor_iri},
      {packaging_iri, @prov_was_associated_with, packager_iri},

      # Usage relationships
      {processing_iri, @prov_used, milk_batch_iri},
      {packaging_iri, @prov_used, processed_milk_iri},

      # Derivation relationships
      {processed_milk_iri, @prov_was_derived_from, milk_batch_iri},
      {packaged_milk_iri, @prov_was_derived_from, processed_milk_iri}
    ]
  end

  defp literal(value, datatype) do
    "\"#{value}\"^^#{datatype}"
  end

  defp format_datetime(timestamp) when is_integer(timestamp) do
    datetime = DateTime.from_unix!(timestamp, :millisecond)
    DateTime.to_iso8601(datetime)
  end
end
