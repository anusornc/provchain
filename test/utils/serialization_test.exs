defmodule ProvChain.Utils.SerializationTest do
  use ExUnit.Case, async: true

  alias ProvChain.Utils.Serialization
  alias ProvChain.Test.ProvOData
  alias ProvChain.BlockDag.Block
  alias ProvChain.Crypto.Signature

  describe "encode/1" do
    test "encodes basic data types" do
      assert Serialization.encode(42) == "42"
      assert Serialization.encode("hello") == "\"hello\""
      assert Serialization.encode(true) == "true"
      assert Serialization.encode([1, 2, 3]) == "[1,2,3]"
    end

    test "encodes maps with deterministic key ordering" do
      map = %{"c" => 3, "a" => 1, "b" => 2}
      encoded = Serialization.encode(map)
      decoded = Jason.decode!(encoded)
      assert decoded == %{"a" => 1, "b" => 2, "c" => 3}
      encoded2 = Serialization.encode(map)
      assert encoded == encoded2
    end

    test "encodes PROV-O milk collection transaction" do
      tx = ProvOData.milk_collection_transaction()
      encoded = Serialization.encode(tx)
      {:ok, decoded} = Serialization.decode(encoded)

      assert decoded["prov:entity"]["type"] == "prov:Entity"
      assert decoded["prov:activity"]["type"] == "prov:Activity"
      assert decoded["prov:agent"]["type"] == "prov:Agent"

      assert Map.has_key?(decoded["prov:relations"], "wasGeneratedBy")
      assert Map.has_key?(decoded["prov:relations"], "wasAttributedTo")
      assert Map.has_key?(decoded["prov:relations"], "wasAssociatedWith")

      assert decoded["supply_chain_data"]["event_type"] == "milk_collection"
    end

    test "encodes PROV-O supply chain trace" do
      trace = ProvOData.generate_supply_chain_trace()
      encoded = Serialization.encode(trace)
      {:ok, decoded} = Serialization.decode(encoded)

      assert length(decoded) == 4

      [collection, processing, packaging, distribution] = decoded

      batch_id = collection["prov:entity"]["id"]
      used_relation = processing["prov:relations"]["used"]
      assert used_relation["entity"] == batch_id

      processed_id = processing["prov:entity"]["id"]
      used_relation = packaging["prov:relations"]["used"]
      assert used_relation["entity"] == processed_id

      package_id = packaging["prov:entity"]["id"]
      used_relation = distribution["prov:relations"]["used"]
      assert used_relation["entity"] == package_id
    end

    test "safely handles non-encodable data in PROV-O structure" do
      tx = ProvOData.milk_collection_transaction()
      tx = Map.put(tx, "validator_fn", fn x -> x * 2 end)

      result = Serialization.encode(tx)
      {:ok, decoded} = Serialization.decode(result)

      assert decoded["prov:entity"]
      assert decoded["prov:activity"]
      assert decoded["prov:agent"]
      assert decoded["validator_fn"] == nil
    end
  end

  describe "decode/1" do
    test "decodes valid PROV-O JSON string" do
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
      entity = %{
        "type" => "prov:Entity",
        "id" => "entity:123",
        "attributes" => %{
          "prov:type" => "MilkBatch",
          "quality" => %{"grade" => "A"}
        }
      }
      json = Jason.encode!(entity)

      {:ok, decoded} = Serialization.decode_with_atoms(json)

      assert decoded.type == "prov:Entity"
      assert decoded.attributes."prov:type" == "MilkBatch"
      assert is_map(decoded.attributes.quality)
    end
  end

  describe "struct_to_map/1" do
    test "converts struct to serializable map with PROV-O content" do
      {_, validator} = Signature.generate_key_pair()
      prev_hash = :crypto.hash(:sha256, "prev_block_1")
      struct = %Block{
        hash: :crypto.hash(:sha256, "block_1"),
        prev_hashes: [prev_hash],
        timestamp: 1_744_420_650_662,
        height: 1,
        validator: validator,
        signature: nil,
        transactions: [%{"test" => "transaction"}],
        merkle_root: :crypto.hash(:sha256, "merkle_1"),
        supply_chain_type: "milk_collection",
        dag_weight: 2,
        metadata: %{"test" => true}
      }

      result = Serialization.struct_to_map(struct)

      assert result["hash"] == Base.encode16(struct.hash, case: :upper)
      assert result["prev_hashes"] == Enum.map(struct.prev_hashes, &Base.encode16(&1, case: :upper))
      assert result["timestamp"] == struct.timestamp
      assert result["height"] == struct.height
      assert result["supply_chain_type"] == "milk_collection"
      assert result["metadata"] == %{"test" => true}
      refute Map.has_key?(result, "__struct__")
    end
  end
end
