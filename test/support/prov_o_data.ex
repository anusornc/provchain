defmodule ProvChain.Test.ProvOData do
  @moduledoc """
  Provides test data structured according to the PROV-O ontology for testing ProvChain components.

  This module contains helper functions to generate realistic PROV-O entities, activities,
  agents, and their relationships for the dairy supply chain use case.
  """

  alias ProvChain.Crypto.Hash

  # Generate binary hashes instead of hex strings
  defp generate_hash(prefix, id) do
    Hash.hash("#{prefix}:#{id}")
  end

  # Utility to ensure no double prefixing in IDs
  defp prefixed_id(type, id) do
    if String.starts_with?(id, type <> ":") do
      id
    else
      type <> ":" <> id
    end
  end

  @doc """
  Generates a sample PROV-O entity representing a milk batch.

  ## Parameters
    - batch_id: Identifier for the batch (optional)

  ## Returns
    A map representing a PROV-O entity
  """
  def milk_batch_entity(batch_id \\ nil) do
    batch_id = batch_id || "batch:#{:os.system_time(:millisecond)}"

    %{
      "id" => batch_id,
      "type" => "prov:Entity",
      "attributes" => %{
        "prov:type" => "MilkBatch",
        "farm" => "farm:123",
        "volume" => 1000.5,
        "quality" => %{
          "temperature" => 4.2,
          "fat_content" => 3.8,
          "protein_content" => 3.2,
          "somatic_cell_count" => 180_000
        }
      },
      "hash" => generate_hash("entity", batch_id)
    }
  end

  @doc """
  Generates a sample PROV-O activity representing milk collection.

  ## Parameters
    - activity_id: Identifier for the activity (optional)

  ## Returns
    A map representing a PROV-O activity
  """
  def milk_collection_activity(activity_id \\ nil) do
    activity_id = activity_id || "collection:#{:os.system_time(:millisecond)}"
    timestamp = :os.system_time(:millisecond)

    %{
      "id" => activity_id,
      "type" => "prov:Activity",
      "attributes" => %{
        "prov:type" => "MilkCollection",
        "prov:startTime" => timestamp,
        "prov:endTime" => timestamp + 3600,
        "location" => %{
          "latitude" => 51.5074,
          "longitude" => -0.1278,
          "name" => "Farm A Collection Point"
        },
        "equipment" => "tank:456",
        "temperature" => 4.0
      },
      "hash" => generate_hash("activity", activity_id)
    }
  end

  @doc """
  Generates a sample PROV-O agent representing a dairy farmer.

  ## Parameters
    - agent_id: Identifier for the agent (optional)

  ## Returns
    A map representing a PROV-O agent
  """
  def farmer_agent(agent_id \\ nil) do
    agent_id = agent_id || "farmer:#{:os.system_time(:millisecond)}"

    %{
      "id" => agent_id,
      "type" => "prov:Agent",
      "attributes" => %{
        "prov:type" => "DairyFarmer",
        "name" => "John Smith",
        "certification" => "organic-123",
        "contact" => "john@farmexample.com"
      },
      "hash" => generate_hash("agent", agent_id)
    }
  end

  @doc """
  Generates a sample PROV-O agent representing a dairy processor.

  ## Parameters
    - agent_id: Identifier for the agent (optional)

  ## Returns
    A map representing a PROV-O agent
  """
  def processor_agent(agent_id \\ nil) do
    agent_id = agent_id || "processor:#{:os.system_time(:millisecond)}"

    %{
      "id" => agent_id,
      "type" => "prov:Agent",
      "attributes" => %{
        "prov:type" => "DairyProcessor",
        "name" => "Acme Dairy Processing",
        "certification" => "iso9001-456",
        "facility" => "facility:789"
      },
      "hash" => generate_hash("agent", agent_id)
    }
  end

  @doc """
  Generates a set of PROV-O relationships between entities, activities, and agents.

  ## Parameters
    - entity_id: Identifier for the entity
    - activity_id: Identifier for the activity
    - agent_id: Identifier for the agent

  ## Returns
    A map of relationships
  """
  def generate_relationships(entity_id, activity_id, agent_id) do
    timestamp = :os.system_time(:millisecond)

    %{
      "wasGeneratedBy" => %{
        "id" => "relation:generation:#{timestamp}",
        "entity" => entity_id,
        "activity" => activity_id,
        "attributes" => %{
          "prov:time" => timestamp
        }
      },
      "wasAttributedTo" => %{
        "id" => "relation:attribution:#{timestamp}",
        "entity" => entity_id,
        "agent" => agent_id,
        "attributes" => %{
          "prov:role" => "producer"
        }
      },
      "wasAssociatedWith" => %{
        "id" => "relation:association:#{timestamp}",
        "activity" => activity_id,
        "agent" => agent_id,
        "attributes" => %{
          "prov:role" => "collector"
        }
      }
    }
  end

  @doc """
  Generates a complete PROV-O milk collection transaction with all components.

  ## Returns
    A map with entity, activity, agent, and relationships
  """
  def milk_collection_transaction do
    timestamp = :os.system_time(:millisecond)
    batch_id = prefixed_id("batch", Integer.to_string(timestamp))
    activity_id = prefixed_id("collection", Integer.to_string(timestamp))
    farmer_id = prefixed_id("farmer", Integer.to_string(timestamp))

    entity = milk_batch_entity(batch_id)
    activity = milk_collection_activity(activity_id)
    agent = farmer_agent(farmer_id)
    relationships = generate_relationships(batch_id, activity_id, farmer_id)

    %{
      "prov:entity" => entity,
      "prov:activity" => activity,
      "prov:agent" => agent,
      "prov:relations" => relationships,
      "supply_chain_data" => %{
        "event_type" => "milk_collection",
        "tank_id" => "tank:456",
        "temperature" => entity["attributes"]["quality"]["temperature"],
        "collection_time" => activity["attributes"]["prov:startTime"]
      },
      "hash" => generate_hash("transaction", "#{batch_id}:#{activity_id}")
    }
  end

  @doc """
  Generates a PROV-O milk processing transaction that uses a milk collection as input.

  ## Parameters
    - input_batch_id: The ID of the milk batch used as input

  ## Returns
    A map with entity, activity, agent, and relationships
  """
  def milk_processing_transaction(input_batch_id) do
    timestamp = :os.system_time(:millisecond)
    processed_batch_id = prefixed_id("processed", Integer.to_string(timestamp))
    activity_id = prefixed_id("processing", Integer.to_string(timestamp))
    processor_id = prefixed_id("processor", Integer.to_string(timestamp))

    processed_entity = %{
      "id" => processed_batch_id,
      "type" => "prov:Entity",
      "attributes" => %{
        "prov:type" => "ProcessedMilk",
        "pasteurization_temperature" => 72.0,
        "pasteurization_time" => 15,
        "cooling_temperature" => 4.0,
        "batch_size" => 950.5
      },
      "hash" => generate_hash("entity", processed_batch_id)
    }

    processing_activity = %{
      "id" => activity_id,
      "type" => "prov:Activity",
      "attributes" => %{
        "prov:type" => "MilkProcessing",
        "prov:startTime" => timestamp,
        "prov:endTime" => timestamp + 7200,
        "process" => "UHT",
        "equipment" => "processor:789",
        "quality_check" => "passed"
      },
      "hash" => generate_hash("activity", activity_id)
    }

    agent = processor_agent(processor_id)

    # Standard relationships
    relationships = generate_relationships(processed_batch_id, activity_id, processor_id)

    # Add the "used" relationship to link to input batch
    relationships =
      Map.put(relationships, "used", %{
        "id" => "relation:usage:#{timestamp}",
        "activity" => activity_id,
        "entity" => input_batch_id,
        "attributes" => %{
          "prov:time" => timestamp,
          "prov:role" => "input"
        }
      })

    # Add the "wasDerivedFrom" relationship
    relationships =
      Map.put(relationships, "wasDerivedFrom", %{
        "id" => "relation:derivation:#{timestamp}",
        "generatedEntity" => processed_batch_id,
        "usedEntity" => input_batch_id,
        "activity" => activity_id,
        "attributes" => %{
          "prov:type" => "prov:Revision"
        }
      })

    %{
      "prov:entity" => processed_entity,
      "prov:activity" => processing_activity,
      "prov:agent" => agent,
      "prov:relations" => relationships,
      "supply_chain_data" => %{
        "event_type" => "milk_processing",
        "processor_id" => "processor:789",
        "process_type" => "UHT",
        "processing_time" => timestamp
      },
      "hash" => generate_hash("transaction", "#{processed_batch_id}:#{activity_id}")
    }
  end

  @doc """
  Generates a complete supply chain trace with multiple connected transactions.

  ## Returns
    A list of connected PROV-O transactions
  """
  def generate_supply_chain_trace do
    # First transaction: Milk Collection
    collection_tx = milk_collection_transaction()
    batch_id = collection_tx["prov:entity"]["id"]

    # Second transaction: Milk Processing
    processing_tx = milk_processing_transaction(batch_id)
    processed_id = processing_tx["prov:entity"]["id"]

    # Third transaction: Packaging
    packaging_tx = packaging_transaction(processed_id)
    package_id = packaging_tx["prov:entity"]["id"]

    # Fourth transaction: Distribution
    distribution_tx = distribution_transaction(package_id)

    [collection_tx, processing_tx, packaging_tx, distribution_tx]
  end

  @doc """
  Generates a packaging transaction.

  ## Parameters
    - input_processed_id: The ID of the processed milk used as input

  ## Returns
    A map with entity, activity, agent, and relationships
  """
  def packaging_transaction(input_processed_id) do
    timestamp = :os.system_time(:millisecond)
    package_id = prefixed_id("package", Integer.to_string(timestamp))
    activity_id = prefixed_id("packaging", Integer.to_string(timestamp))
    processor_id = prefixed_id("processor", Integer.to_string(timestamp))

    package_entity = %{
      "id" => package_id,
      "type" => "prov:Entity",
      "attributes" => %{
        "prov:type" => "PackagedMilk",
        "package_type" => "Tetra Pak",
        "volume" => 1.0,
        "units" => 950,
        # 90 days in milliseconds
        "best_before" => timestamp + 7_776_000_000,
        "batch_number" => "UHT-#{timestamp}",
        "barcode" => "5901234123457"
      },
      "hash" => generate_hash("entity", package_id)
    }

    packaging_activity = %{
      "id" => activity_id,
      "type" => "prov:Activity",
      "attributes" => %{
        "prov:type" => "Packaging",
        "prov:startTime" => timestamp,
        "prov:endTime" => timestamp + 3600,
        "line" => "packaging-line-3",
        "quality_check" => "passed"
      },
      "hash" => generate_hash("activity", activity_id)
    }

    agent = processor_agent(processor_id)

    # Standard relationships
    relationships = generate_relationships(package_id, activity_id, processor_id)

    # Add the "used" relationship to link to input processed milk
    relationships =
      Map.put(relationships, "used", %{
        "id" => "relation:usage:#{timestamp}",
        "activity" => activity_id,
        "entity" => input_processed_id,
        "attributes" => %{
          "prov:time" => timestamp,
          "prov:role" => "input"
        }
      })

    # Add the "wasDerivedFrom" relationship
    relationships =
      Map.put(relationships, "wasDerivedFrom", %{
        "id" => "relation:derivation:#{timestamp}",
        "generatedEntity" => package_id,
        "usedEntity" => input_processed_id,
        "activity" => activity_id,
        "attributes" => %{
          "prov:type" => "prov:Revision"
        }
      })

    %{
      "prov:entity" => package_entity,
      "prov:activity" => packaging_activity,
      "prov:agent" => agent,
      "prov:relations" => relationships,
      "supply_chain_data" => %{
        "event_type" => "packaging",
        "line_id" => "packaging-line-3",
        "package_type" => "Tetra Pak",
        "packaging_time" => timestamp
      },
      "hash" => generate_hash("transaction", "#{package_id}:#{activity_id}")
    }
  end

  @doc """
  Generates a distribution transaction.

  ## Parameters
    - input_package_id: The ID of the packaged milk used as input

  ## Returns
    A map with entity, activity, agent, and relationships
  """
  def distribution_transaction(input_package_id) do
    timestamp = :os.system_time(:millisecond)
    shipment_id = prefixed_id("shipment", Integer.to_string(timestamp))
    activity_id = prefixed_id("distribution", Integer.to_string(timestamp))
    distributor_id = prefixed_id("distributor", Integer.to_string(timestamp))

    shipment_entity = %{
      "id" => shipment_id,
      "type" => "prov:Entity",
      "attributes" => %{
        "prov:type" => "MilkShipment",
        "shipment_number" => "SH-#{timestamp}",
        "destination" => "Retail Store ABC",
        "transport_id" => "truck-567",
        "packages" => [input_package_id],
        "temperature_log" => [4.1, 4.0, 4.2, 4.1, 4.0]
      },
      "hash" => generate_hash("entity", shipment_id)
    }

    distribution_activity = %{
      "id" => activity_id,
      "type" => "prov:Activity",
      "attributes" => %{
        "prov:type" => "Distribution",
        "prov:startTime" => timestamp,
        # 4 hours for delivery
        "prov:endTime" => timestamp + 14_400,
        "route" => "Route-45",
        "cold_chain_maintained" => true
      },
      "hash" => generate_hash("activity", activity_id)
    }

    distributor_agent = %{
      "id" => distributor_id,
      "type" => "prov:Agent",
      "attributes" => %{
        "prov:type" => "Distributor",
        "name" => "Fast Dairy Logistics",
        "license" => "LOG-123-456",
        "contact" => "logistics@example.com"
      },
      "hash" => generate_hash("agent", distributor_id)
    }

    # Standard relationships
    relationships = generate_relationships(shipment_id, activity_id, distributor_id)

    # Add the "used" relationship to link to input package
    relationships =
      Map.put(relationships, "used", %{
        "id" => "relation:usage:#{timestamp}",
        "activity" => activity_id,
        "entity" => input_package_id,
        "attributes" => %{
          "prov:time" => timestamp,
          "prov:role" => "input"
        }
      })

    %{
      "prov:entity" => shipment_entity,
      "prov:activity" => distribution_activity,
      "prov:agent" => distributor_agent,
      "prov:relations" => relationships,
      "supply_chain_data" => %{
        "event_type" => "distribution",
        "vehicle_id" => "truck-567",
        "destination" => "Retail Store ABC",
        "departure_time" => timestamp
      },
      "hash" => generate_hash("transaction", "#{shipment_id}:#{activity_id}")
    }
  end
end
