defmodule ProvChain.KnowledgeGraph.MilkSupplyChain do
  @moduledoc """
  Knowledge Graph module for creating and managing milk supply chain traces.
  Generates complete PROV-O compliant supply chain data for testing and demo purposes.
  """

  alias ProvChain.Test.ProvOData
  alias ProvChain.BlockDag.Transaction
  alias ProvChain.RDF.Converter
  alias ProvChain.KnowledgeGraph.GraphStore

  @doc """
  Creates a complete milk supply chain trace starting from a given batch ID.
  Returns RDF triples representing the entire farm-to-consumer journey.
  """
  @spec create_milk_trace(String.t()) :: list(String.t())
  def create_milk_trace(batch_id) do
    # Generate complete supply chain trace
    trace_transactions = generate_complete_trace(batch_id)

    # Convert to RDF triples and store in GraphStore
    all_triples =
      trace_transactions
      |> Enum.flat_map(&Converter.transaction_to_rdf_triples/1)
      |> Enum.uniq()

    GraphStore.store_triples(all_triples)
    all_triples
  end

  @doc """
  Creates a comprehensive milk supply chain with all stages.
  """
  @spec generate_complete_trace(String.t()) :: list(map())
  def generate_complete_trace(batch_id) do
    timestamp = :os.system_time(:millisecond)

    # Stage 1: Milk Collection
    collection_tx = create_collection_transaction(batch_id, timestamp)

    # Stage 2: Transportation to Processing Plant
    transport_tx = create_transport_transaction(batch_id, timestamp + 3600)

    # Stage 3: Milk Processing (Pasteurization)
    processing_tx = create_processing_transaction(batch_id, timestamp + 7200)
    processed_id = processing_tx["prov:entity"]["id"]

    # Stage 4: UHT Treatment
    uht_tx = create_uht_treatment_transaction(processed_id, timestamp + 10800)
    uht_id = uht_tx["prov:entity"]["id"]

    # Stage 5: Packaging
    packaging_tx = create_packaging_transaction(uht_id, timestamp + 14400)
    package_id = packaging_tx["prov:entity"]["id"]

    # Stage 6: Quality Control
    qc_tx = create_quality_control_transaction(package_id, timestamp + 18000)

    # Stage 7: Distribution to Retail
    distribution_tx = create_distribution_transaction(package_id, timestamp + 21600)
    shipment_id = distribution_tx["prov:entity"]["id"]

    # Stage 8: Retail Sale
    retail_tx = create_retail_transaction(shipment_id, timestamp + 25200)

    [collection_tx, transport_tx, processing_tx, uht_tx, packaging_tx, qc_tx, distribution_tx, retail_tx]
  end

  @doc """
  Finds contamination impact by tracing all products derived from a contaminated batch.
  """
  @spec find_contamination_impact(String.t()) :: list(map())
  def find_contamination_impact(contaminated_batch_id) do
    # Generate trace and find all derived products
    trace = generate_complete_trace(contaminated_batch_id)

    # Extract all entity IDs that could be affected
    affected_entities =
      trace
      |> Enum.map(&extract_entity_id/1)
      |> Enum.uniq()

    # Create impact report
    Enum.map(affected_entities, fn entity_id ->
      %{
        "entity_id" => entity_id,
        "contamination_source" => contaminated_batch_id,
        "impact_level" => calculate_impact_level(entity_id, contaminated_batch_id),
        "recommended_action" => get_recommended_action(entity_id)
      }
    end)
  end

  # Private helper functions

  defp create_collection_transaction(batch_id, timestamp) do
    entity = create_milk_batch_entity(batch_id, timestamp)
    activity = create_collection_activity(timestamp)
    agent = create_farmer_agent(timestamp)
    relations = create_basic_relations(entity["id"], activity["id"], agent["id"], timestamp)

    supply_chain_data = %{
      "event_type" => "milk_collection",
      "farm_id" => "farm:#{div(timestamp, 1000)}",
      "tank_id" => "tank:456",
      "temperature" => 4.2,
      "volume_collected" => 1000.5,
      "collection_method" => "automated_milking_system"
    }

    Transaction.new(entity, activity, agent, relations, supply_chain_data, timestamp)
  end

  defp create_transport_transaction(batch_id, timestamp) do
    entity = create_transport_entity(batch_id, timestamp)
    activity = create_transport_activity(timestamp)
    agent = create_transporter_agent(timestamp)
    relations = create_transport_relations(entity["id"], activity["id"], agent["id"], batch_id, timestamp)

    supply_chain_data = %{
      "event_type" => "transportation",
      "vehicle_id" => "truck:#{div(timestamp, 1000)}",
      "route" => "Farm_A_to_Processing_Plant",
      "temperature_maintained" => 4.0,
      "travel_time_minutes" => 45
    }

    Transaction.new(entity, activity, agent, relations, supply_chain_data, timestamp)
  end

  defp create_processing_transaction(batch_id, timestamp) do
    entity = create_processed_entity(batch_id, timestamp)
    activity = create_processing_activity(timestamp)
    agent = create_processor_agent(timestamp)
    relations = create_processing_relations(entity["id"], activity["id"], agent["id"], batch_id, timestamp)

    supply_chain_data = %{
      "event_type" => "pasteurization",
      "process_type" => "LTLT", # Low Temperature Long Time
      "temperature" => 63.0,
      "duration_minutes" => 30,
      "equipment_id" => "pasteurizer:#{div(timestamp, 1000)}"
    }

    Transaction.new(entity, activity, agent, relations, supply_chain_data, timestamp)
  end

  defp create_uht_treatment_transaction(processed_id, timestamp) do
    entity = create_uht_entity(processed_id, timestamp)
    activity = create_uht_activity(timestamp)
    agent = create_processor_agent(timestamp)
    relations = create_processing_relations(entity["id"], activity["id"], agent["id"], processed_id, timestamp)

    supply_chain_data = %{
      "event_type" => "uht_treatment",
      "temperature" => 135.0,
      "duration_seconds" => 2,
      "equipment_id" => "uht_system:#{div(timestamp, 1000)}",
      "cooling_temperature" => 4.0
    }

    Transaction.new(entity, activity, agent, relations, supply_chain_data, timestamp)
  end

  defp create_packaging_transaction(uht_id, timestamp) do
    entity = create_package_entity(uht_id, timestamp)
    activity = create_packaging_activity(timestamp)
    agent = create_packager_agent(timestamp)
    relations = create_processing_relations(entity["id"], activity["id"], agent["id"], uht_id, timestamp)

    supply_chain_data = %{
      "event_type" => "packaging",
      "package_type" => "Tetra_Pak",
      "package_size" => "1L",
      "packages_produced" => 950,
      "line_id" => "packaging_line:#{div(timestamp, 1000)}"
    }

    Transaction.new(entity, activity, agent, relations, supply_chain_data, timestamp)
  end

  defp create_quality_control_transaction(package_id, timestamp) do
    entity = create_qc_entity(package_id, timestamp)
    activity = create_qc_activity(timestamp)
    agent = create_qc_agent(timestamp)
    relations = create_basic_relations(entity["id"], activity["id"], agent["id"], timestamp)

    supply_chain_data = %{
      "event_type" => "quality_control",
      "test_results" => %{
        "microbiological" => "pass",
        "chemical" => "pass",
        "sensory" => "pass",
        "shelf_life" => "90_days"
      },
      "batch_released" => true
    }

    Transaction.new(entity, activity, agent, relations, supply_chain_data, timestamp)
  end

  defp create_distribution_transaction(package_id, timestamp) do
    entity = create_shipment_entity(package_id, timestamp)
    activity = create_distribution_activity(timestamp)
    agent = create_distributor_agent(timestamp)
    relations = create_processing_relations(entity["id"], activity["id"], agent["id"], package_id, timestamp)

    supply_chain_data = %{
      "event_type" => "distribution",
      "destination" => "SuperMarket_Chain_XYZ",
      "vehicle_id" => "delivery_truck:#{div(timestamp, 1000)}",
      "cold_chain_maintained" => true,
      "delivery_time" => timestamp + 14400
    }

    Transaction.new(entity, activity, agent, relations, supply_chain_data, timestamp)
  end

  defp create_retail_transaction(shipment_id, timestamp) do
    entity = create_retail_entity(shipment_id, timestamp)
    activity = create_retail_activity(timestamp)
    agent = create_retailer_agent(timestamp)
    relations = create_processing_relations(entity["id"], activity["id"], agent["id"], shipment_id, timestamp)

    supply_chain_data = %{
      "event_type" => "retail_sale",
      "store_id" => "store:#{div(timestamp, 1000)}",
      "shelf_placement" => "dairy_section",
      "price_per_unit" => 2.99,
      "inventory_count" => 500
    }

    Transaction.new(entity, activity, agent, relations, supply_chain_data, timestamp)
  end

  # Entity creation helpers

  defp create_milk_batch_entity(batch_id, timestamp) do
    ProvOData.milk_batch_entity(batch_id)
    |> Map.put("timestamp", timestamp)
  end

  defp create_transport_entity(batch_id, timestamp) do
    %{
      "id" => "transport:#{batch_id}:#{timestamp}",
      "type" => "prov:Entity",
      "attributes" => %{
        "prov:type" => "MilkTransport",
        "source_batch" => batch_id,
        "transport_container" => "refrigerated_tank",
        "temperature_range" => "2-6°C"
      },
      "hash" => :crypto.hash(:sha256, "transport:#{batch_id}:#{timestamp}")
    }
  end

  defp create_processed_entity(batch_id, timestamp) do
    %{
      "id" => "processed:#{batch_id}:#{timestamp}",
      "type" => "prov:Entity",
      "attributes" => %{
        "prov:type" => "PasteurizedMilk",
        "source_batch" => batch_id,
        "pasteurization_method" => "LTLT",
        "fat_content" => 3.8,
        "protein_content" => 3.2
      },
      "hash" => :crypto.hash(:sha256, "processed:#{batch_id}:#{timestamp}")
    }
  end

  defp create_uht_entity(processed_id, timestamp) do
    %{
      "id" => "uht:#{processed_id}:#{timestamp}",
      "type" => "prov:Entity",
      "attributes" => %{
        "prov:type" => "UHTMilk",
        "source_processed" => processed_id,
        "shelf_life_days" => 90,
        "treatment_temperature" => 135.0,
        "sterility_level" => "commercial_sterile"
      },
      "hash" => :crypto.hash(:sha256, "uht:#{processed_id}:#{timestamp}")
    }
  end

  defp create_package_entity(uht_id, timestamp) do
    %{
      "id" => "package:#{uht_id}:#{timestamp}",
      "type" => "prov:Entity",
      "attributes" => %{
        "prov:type" => "PackagedUHTMilk",
        "source_uht" => uht_id,
        "package_material" => "Tetra_Pak",
        "volume_ml" => 1000,
        "barcode" => "#{timestamp}_UHT_1L"
      },
      "hash" => :crypto.hash(:sha256, "package:#{uht_id}:#{timestamp}")
    }
  end

  defp create_qc_entity(package_id, timestamp) do
    %{
      "id" => "qc:#{package_id}:#{timestamp}",
      "type" => "prov:Entity",
      "attributes" => %{
        "prov:type" => "QualityControlRecord",
        "tested_package" => package_id,
        "test_status" => "passed",
        "certification" => "food_safety_certified"
      },
      "hash" => :crypto.hash(:sha256, "qc:#{package_id}:#{timestamp}")
    }
  end

  defp create_shipment_entity(package_id, timestamp) do
    %{
      "id" => "shipment:#{package_id}:#{timestamp}",
      "type" => "prov:Entity",
      "attributes" => %{
        "prov:type" => "MilkShipment",
        "source_package" => package_id,
        "shipment_size" => 1000,
        "destination_type" => "retail"
      },
      "hash" => :crypto.hash(:sha256, "shipment:#{package_id}:#{timestamp}")
    }
  end

  defp create_retail_entity(shipment_id, timestamp) do
    %{
      "id" => "retail:#{shipment_id}:#{timestamp}",
      "type" => "prov:Entity",
      "attributes" => %{
        "prov:type" => "RetailInventory",
        "source_shipment" => shipment_id,
        "shelf_location" => "dairy_cooler",
        "sell_by_date" => timestamp + (90 * 24 * 60 * 60 * 1000) # 90 days
      },
      "hash" => :crypto.hash(:sha256, "retail:#{shipment_id}:#{timestamp}")
    }
  end

  # Activity creation helpers

  defp create_collection_activity(timestamp) do
    ProvOData.milk_collection_activity("collection:#{timestamp}")
  end

  defp create_transport_activity(timestamp) do
    %{
      "id" => "transport_activity:#{timestamp}",
      "type" => "prov:Activity",
      "attributes" => %{
        "prov:type" => "MilkTransportation",
        "prov:startTime" => timestamp,
        "prov:endTime" => timestamp + 2700, # 45 minutes
        "transport_method" => "refrigerated_truck"
      },
      "hash" => :crypto.hash(:sha256, "transport_activity:#{timestamp}")
    }
  end

  defp create_processing_activity(timestamp) do
    %{
      "id" => "processing_activity:#{timestamp}",
      "type" => "prov:Activity",
      "attributes" => %{
        "prov:type" => "MilkPasteurization",
        "prov:startTime" => timestamp,
        "prov:endTime" => timestamp + 1800, # 30 minutes
        "process_parameters" => %{
          "temperature" => 63.0,
          "duration" => 30
        }
      },
      "hash" => :crypto.hash(:sha256, "processing_activity:#{timestamp}")
    }
  end

  defp create_uht_activity(timestamp) do
    %{
      "id" => "uht_activity:#{timestamp}",
      "type" => "prov:Activity",
      "attributes" => %{
        "prov:type" => "UHTTreatment",
        "prov:startTime" => timestamp,
        "prov:endTime" => timestamp + 300, # 5 minutes
        "treatment_parameters" => %{
          "temperature" => 135.0,
          "duration_seconds" => 2
        }
      },
      "hash" => :crypto.hash(:sha256, "uht_activity:#{timestamp}")
    }
  end

  defp create_packaging_activity(timestamp) do
    %{
      "id" => "packaging_activity:#{timestamp}",
      "type" => "prov:Activity",
      "attributes" => %{
        "prov:type" => "MilkPackaging",
        "prov:startTime" => timestamp,
        "prov:endTime" => timestamp + 3600, # 1 hour
        "packaging_line" => "line_3"
      },
      "hash" => :crypto.hash(:sha256, "packaging_activity:#{timestamp}")
    }
  end

  defp create_qc_activity(timestamp) do
    %{
      "id" => "qc_activity:#{timestamp}",
      "type" => "prov:Activity",
      "attributes" => %{
        "prov:type" => "QualityControl",
        "prov:startTime" => timestamp,
        "prov:endTime" => timestamp + 1800, # 30 minutes
        "test_protocol" => "standard_dairy_qc"
      },
      "hash" => :crypto.hash(:sha256, "qc_activity:#{timestamp}")
    }
  end

  defp create_distribution_activity(timestamp) do
    %{
      "id" => "distribution_activity:#{timestamp}",
      "type" => "prov:Activity",
      "attributes" => %{
        "prov:type" => "ProductDistribution",
        "prov:startTime" => timestamp,
        "prov:endTime" => timestamp + 14400, # 4 hours
        "distribution_network" => "regional"
      },
      "hash" => :crypto.hash(:sha256, "distribution_activity:#{timestamp}")
    }
  end

  defp create_retail_activity(timestamp) do
    %{
      "id" => "retail_activity:#{timestamp}",
      "type" => "prov:Activity",
      "attributes" => %{
        "prov:type" => "RetailStocking",
        "prov:startTime" => timestamp,
        "prov:endTime" => timestamp + 1800, # 30 minutes
        "stocking_location" => "dairy_section"
      },
      "hash" => :crypto.hash(:sha256, "retail_activity:#{timestamp}")
    }
  end

  # Agent creation helpers

  defp create_farmer_agent(timestamp) do
    ProvOData.farmer_agent("farmer:#{timestamp}")
  end

  defp create_transporter_agent(timestamp) do
    %{
      "id" => "transporter:#{timestamp}",
      "type" => "prov:Agent",
      "attributes" => %{
        "prov:type" => "MilkTransporter",
        "name" => "Cold Chain Logistics Ltd",
        "license" => "transport_#{div(timestamp, 1000)}",
        "specialization" => "dairy_products"
      },
      "hash" => :crypto.hash(:sha256, "transporter:#{timestamp}")
    }
  end

  defp create_processor_agent(timestamp) do
    ProvOData.processor_agent("processor:#{timestamp}")
  end

  defp create_packager_agent(timestamp) do
    %{
      "id" => "packager:#{timestamp}",
      "type" => "prov:Agent",
      "attributes" => %{
        "prov:type" => "PackagingCompany",
        "name" => "TetraPak Packaging Solutions",
        "certification" => "food_packaging_certified_#{div(timestamp, 1000)}",
        "specialization" => "aseptic_packaging"
      },
      "hash" => :crypto.hash(:sha256, "packager:#{timestamp}")
    }
  end

  defp create_qc_agent(timestamp) do
    %{
      "id" => "qc_agent:#{timestamp}",
      "type" => "prov:Agent",
      "attributes" => %{
        "prov:type" => "QualityControlInspector",
        "name" => "Food Safety Inspector",
        "certification" => "food_safety_#{div(timestamp, 1000)}",
        "authority" => "national_food_safety_agency"
      },
      "hash" => :crypto.hash(:sha256, "qc_agent:#{timestamp}")
    }
  end

  defp create_distributor_agent(timestamp) do
    %{
      "id" => "distributor:#{timestamp}",
      "type" => "prov:Agent",
      "attributes" => %{
        "prov:type" => "FoodDistributor",
        "name" => "Regional Food Distribution Co",
        "license" => "distribution_#{div(timestamp, 1000)}",
        "coverage_area" => "metropolitan_region"
      },
      "hash" => :crypto.hash(:sha256, "distributor:#{timestamp}")
    }
  end

  defp create_retailer_agent(timestamp) do
    %{
      "id" => "retailer:#{timestamp}",
      "type" => "prov:Agent",
      "attributes" => %{
        "prov:type" => "RetailStore",
        "name" => "SuperMarket Chain XYZ",
        "store_number" => "store_#{div(timestamp, 1000)}",
        "location" => "city_center_branch"
      },
      "hash" => :crypto.hash(:sha256, "retailer:#{timestamp}")
    }
  end

  # Relations creation helpers

  defp create_basic_relations(entity_id, activity_id, agent_id, timestamp) do
    ProvOData.generate_relationships(entity_id, activity_id, agent_id)
    |> Map.put("timestamp", timestamp)
  end

  defp create_transport_relations(entity_id, activity_id, agent_id, source_entity_id, timestamp) do
    basic_relations = create_basic_relations(entity_id, activity_id, agent_id, timestamp)

    basic_relations
    |> Map.put("used", %{
      "id" => "relation:usage:#{timestamp}",
      "activity" => activity_id,
      "entity" => source_entity_id,
      "attributes" => %{"prov:time" => timestamp, "prov:role" => "source"}
    })
    |> Map.put("wasDerivedFrom", %{
      "id" => "relation:derivation:#{timestamp}",
      "generatedEntity" => entity_id,
      "usedEntity" => source_entity_id,
      "activity" => activity_id,
      "attributes" => %{"prov:type" => "prov:Revision"}
    })
  end

  defp create_processing_relations(entity_id, activity_id, agent_id, source_entity_id, timestamp) do
    create_transport_relations(entity_id, activity_id, agent_id, source_entity_id, timestamp)
  end

  # Helper functions for contamination analysis

  defp extract_entity_id(transaction) do
    transaction["prov:entity"]["id"]
  end

  defp calculate_impact_level(entity_id, _contaminated_batch_id) do
    # Simple impact calculation based on entity type
    cond do
      String.contains?(entity_id, "retail") -> "high"
      String.contains?(entity_id, "package") -> "medium"
      String.contains?(entity_id, "processed") -> "medium"
      true -> "low"
    end
  end

  defp get_recommended_action(entity_id) do
    cond do
      String.contains?(entity_id, "retail") -> "immediate_recall"
      String.contains?(entity_id, "package") -> "quarantine_batch"
      String.contains?(entity_id, "processed") -> "reprocess_required"
      true -> "monitor_closely"
    end
  end
end
