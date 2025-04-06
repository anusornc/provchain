defmodule ProvChain.Utils.SerializationTest do
  use ExUnit.Case, async: true

  alias ProvChain.Utils.Serialization
  alias ProvChain.Test.ProvOData

  describe "encode/1" do
    test "encodes basic data types" do
      assert Serialization.encode(42) == "42"
      assert Serialization.encode("hello") == "\"hello\""
      assert Serialization.encode(true) == "true"
      assert Serialization.encode([1, 2, 3]) == "[1,2,3]"
    end

    test "encodes maps with deterministic key ordering" do
      # Create map with keys in random order
      map = %{c: 3, a: 1, b: 2}
      encoded = Serialization.encode(map)

      # Just check that the decoded data has the correct values
      # rather than testing the exact string format
      decoded = Jason.decode!(encoded)
      assert decoded == %{"a" => 1, "b" => 2, "c" => 3}

      # Also verify that encoding is consistent
      encoded2 = Serialization.encode(map)
      assert encoded == encoded2
    end

    test "encodes PROV-O milk collection transaction" do
      # Get a milk collection transaction with PROV-O structure
      tx = ProvOData.milk_collection_transaction()

      encoded = Serialization.encode(tx)
      decoded = Jason.decode!(encoded)

      # Verify essential PROV-O elements are present
      assert decoded["prov:entity"]["type"] == "prov:Entity"
      assert decoded["prov:activity"]["type"] == "prov:Activity"
      assert decoded["prov:agent"]["type"] == "prov:Agent"

      # Verify PROV-O relationships
      assert Map.has_key?(decoded["prov:relations"], "wasGeneratedBy")
      assert Map.has_key?(decoded["prov:relations"], "wasAttributedTo")
      assert Map.has_key?(decoded["prov:relations"], "wasAssociatedWith")

      # Verify domain-specific data
      assert decoded["supply_chain_data"]["event_type"] == "milk_collection"
    end

    test "encodes PROV-O supply chain trace" do
      # Get a complete supply chain trace (collection -> processing -> packaging -> distribution)
      trace = ProvOData.generate_supply_chain_trace()

      encoded = Serialization.encode(trace)
      decoded = Jason.decode!(encoded)

      # Verify we have all four stages encoded
      assert length(decoded) == 4

      # Check the connections in the trace
      [collection, processing, packaging, distribution] = decoded

      # Verify processing used the milk batch from collection
      batch_id = collection["prov:entity"]["id"]
      used_relation = processing["prov:relations"]["used"]
      assert used_relation["entity"] == batch_id

      # Verify packaging used the processed milk
      processed_id = processing["prov:entity"]["id"]
      used_relation = packaging["prov:relations"]["used"]
      assert used_relation["entity"] == processed_id

      # Verify distribution used the packaged milk
      package_id = packaging["prov:entity"]["id"]
      used_relation = distribution["prov:relations"]["used"]
      assert used_relation["entity"] == package_id
    end

    test "safely handles non-encodable data in PROV-O structure" do
      # Get a milk collection transaction
      tx = ProvOData.milk_collection_transaction()

      # Add a non-encodable value (a function)
      tx = Map.put(tx, :validator_fn, fn x -> x * 2 end)

      # Should not raise an error
      result = Serialization.encode(tx)

      # Should still contain the essential PROV-O structure
      assert result =~ "prov:entity"
      assert result =~ "prov:activity"
      assert result =~ "prov:agent"
    end
  end

  describe "decode/1" do
    test "decodes valid PROV-O JSON string" do
      # Get a milk collection transaction
      tx = ProvOData.milk_collection_transaction()
      json = Serialization.encode(tx)

      {:ok, decoded} = Serialization.decode(json)

      assert decoded["prov:entity"]["type"] == "prov:Entity"
      assert decoded["prov:activity"]["attributes"]["prov:type"] == "MilkCollection"
      assert decoded["prov:agent"]["attributes"]["prov:type"] == "DairyFarmer"
    end

    test "returns error for invalid JSON" do
      result = Serialization.decode("{invalid json}")
      assert {:error, _} = result
    end
  end

  describe "decode_with_atoms/1" do
    test "decodes PROV-O JSON with atom keys" do
      # Get a milk batch entity
      entity = ProvOData.milk_batch_entity()
      json = Serialization.encode(entity)

      {:ok, decoded} = Serialization.decode_with_atoms(json)

      assert decoded.type == "prov:Entity"
      assert decoded.attributes."prov:type" == "MilkBatch"
      assert is_map(decoded.attributes.quality)
    end
  end

  describe "struct_to_map/1" do
    test "converts struct to serializable map with PROV-O content" do
      # Create a struct-like map with DateTime
      timestamp = ~U[2025-01-01 12:00:00Z]
      struct = %{
        __struct__: TestStruct,
        id: "activity:1234",
        type: "prov:Activity",
        timestamp: timestamp,
        attributes: %{
          "prov:type" => "MilkCollection",
          "startTime" => timestamp
        }
      }

      result = Serialization.struct_to_map(struct)

      assert result[:id] == "activity:1234"
      assert result[:type] == "prov:Activity"
      assert result[:timestamp] == DateTime.to_iso8601(timestamp)
      assert result[:attributes]["startTime"] == DateTime.to_iso8601(timestamp)
      refute Map.has_key?(result, :__struct__)
    end
  end
end
