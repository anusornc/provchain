defmodule ProvChain.BlockDag.TransactionTest do
  use ExUnit.Case, async: true

  alias ProvChain.BlockDag.Transaction
  alias ProvChain.Crypto.Signature
  alias ProvChain.Test.ProvOData

  describe "new/6" do
    test "creates a valid transaction with PROV-O components" do
      entity = ProvOData.milk_batch_entity()
      activity = ProvOData.milk_collection_activity()
      agent = ProvOData.farmer_agent()
      relations = ProvOData.generate_relationships(entity["id"], activity["id"], agent["id"])

      supply_chain_data = %{
        "event_type" => "milk_collection",
        "tank_id" => "tank:456",
        "temperature" => 4.2
      }

      tx = Transaction.new(entity, activity, agent, relations, supply_chain_data)
      assert tx["prov:entity"] == entity
      assert tx["prov:activity"] == activity
      assert tx["prov:agent"] == agent
      assert tx["prov:relations"] == relations
      assert tx["supply_chain_data"] == supply_chain_data
      assert is_integer(tx["timestamp"])
      assert is_binary(tx["hash"])
      assert byte_size(tx["hash"]) == 32
      assert tx["signature"] == nil
      assert tx["signer"] == nil
    end

    test "creates transaction with specified timestamp" do
      entity = ProvOData.milk_batch_entity()
      activity = ProvOData.milk_collection_activity()
      agent = ProvOData.farmer_agent()
      relations = ProvOData.generate_relationships(entity["id"], activity["id"], agent["id"])
      supply_chain_data = %{"event_type" => "milk_collection"}
      timestamp = 1_617_283_200_000
      tx = Transaction.new(entity, activity, agent, relations, supply_chain_data, timestamp)
      assert tx["timestamp"] == timestamp
      assert is_binary(tx["hash"])
      assert byte_size(tx["hash"]) == 32
    end
  end

  describe "validate/1" do
    test "validates correctly structured transaction" do
      tx_data = ProvOData.milk_collection_transaction()

      tx =
        Transaction.new(
          tx_data["prov:entity"],
          tx_data["prov:activity"],
          tx_data["prov:agent"],
          tx_data["prov:relations"],
          tx_data["supply_chain_data"]
        )

      assert {:ok, _} = Transaction.validate(tx)
    end

    test "rejects transaction with missing fields" do
      tx_data = ProvOData.milk_collection_transaction()

      tx =
        Transaction.new(
          tx_data["prov:entity"],
          tx_data["prov:activity"],
          tx_data["prov:agent"],
          tx_data["prov:relations"],
          tx_data["supply_chain_data"]
        )

      invalid_tx = Map.delete(tx, "prov:entity")
      assert {:error, error_msg} = Transaction.validate(invalid_tx)
      assert error_msg =~ "Missing required fields"
    end

    test "rejects transaction with invalid PROV-O types" do
      tx_data = ProvOData.milk_collection_transaction()

      tx =
        Transaction.new(
          tx_data["prov:entity"],
          tx_data["prov:activity"],
          tx_data["prov:agent"],
          tx_data["prov:relations"],
          tx_data["supply_chain_data"]
        )

      invalid_tx = put_in(tx, ["prov:entity", "type"], "InvalidType")
      assert {:error, error_msg} = Transaction.validate(invalid_tx)
      assert error_msg =~ "Invalid entity type"
    end

    test "rejects transaction with missing required relations" do
      tx_data = ProvOData.milk_collection_transaction()

      tx =
        Transaction.new(
          tx_data["prov:entity"],
          tx_data["prov:activity"],
          tx_data["prov:agent"],
          tx_data["prov:relations"],
          tx_data["supply_chain_data"]
        )

      invalid_relations = Map.delete(tx["prov:relations"], "wasGeneratedBy")
      invalid_tx = Map.put(tx, "prov:relations", invalid_relations)
      assert {:error, error_msg} = Transaction.validate(invalid_tx)
      assert error_msg =~ "Missing required relations"
    end

    test "accepts transaction with invalid hash and updates it" do
      tx_data = ProvOData.milk_collection_transaction()

      tx =
        Transaction.new(
          tx_data["prov:entity"],
          tx_data["prov:activity"],
          tx_data["prov:agent"],
          tx_data["prov:relations"],
          tx_data["supply_chain_data"]
        )

      invalid_tx = Map.put(tx, "hash", :crypto.hash(:sha256, "invalid"))
      {:ok, validated_tx} = Transaction.validate(invalid_tx)
      assert validated_tx["hash"] != invalid_tx["hash"]
    end
  end

  describe "sign/2 and verify_signature/1" do
    test "signs a transaction and verifies signature" do
      {:ok, {private_key, _}} = Signature.generate_key_pair()
      tx_data = ProvOData.milk_collection_transaction()

      tx =
        Transaction.new(
          tx_data["prov:entity"],
          tx_data["prov:activity"],
          tx_data["prov:agent"],
          tx_data["prov:relations"],
          tx_data["supply_chain_data"]
        )

      {:ok, signed_tx} = Transaction.sign(tx, private_key)
      assert is_binary(signed_tx["signature"])
      assert is_binary(signed_tx["signer"])
      assert Transaction.verify_signature(signed_tx) == true
    end

    test "rejects invalid signature" do
      {:ok, {private_key, _}} = Signature.generate_key_pair()
      tx_data = ProvOData.milk_collection_transaction()

      tx =
        Transaction.new(
          tx_data["prov:entity"],
          tx_data["prov:activity"],
          tx_data["prov:agent"],
          tx_data["prov:relations"],
          tx_data["supply_chain_data"]
        )

      {:ok, signed_tx} = Transaction.sign(tx, private_key)
      tampered_tx = put_in(signed_tx, ["supply_chain_data", "tank_id"], "tampered:789")
      {:ok, validated_tampered_tx} = Transaction.validate(tampered_tx)
      assert Transaction.verify_signature(validated_tampered_tx) == false
    end
  end

  describe "link_to_previous/3" do
    test "links transaction to previous transaction" do
      collection_tx = ProvOData.milk_collection_transaction()

      entity = %{
        "id" => "processed:123",
        "type" => "prov:Entity",
        "attributes" => %{"prov:type" => "ProcessedMilk"}
      }

      activity = %{
        "id" => "processing:123",
        "type" => "prov:Activity",
        "attributes" => %{"prov:type" => "MilkProcessing"}
      }

      agent = %{
        "id" => "processor:123",
        "type" => "prov:Agent",
        "attributes" => %{"prov:type" => "DairyProcessor"}
      }

      relations = ProvOData.generate_relationships(entity["id"], activity["id"], agent["id"])
      supply_chain_data = %{"event_type" => "milk_processing"}
      processing_tx = Transaction.new(entity, activity, agent, relations, supply_chain_data)
      linked_tx = Transaction.link_to_previous(processing_tx, collection_tx)
      assert Map.has_key?(linked_tx["prov:relations"], "used")
      assert Map.has_key?(linked_tx["prov:relations"], "wasDerivedFrom")
      used_relation = linked_tx["prov:relations"]["used"]
      assert used_relation["entity"] == collection_tx["prov:entity"]["id"]
      assert used_relation["activity"] == processing_tx["prov:activity"]["id"]
      derived_relation = linked_tx["prov:relations"]["wasDerivedFrom"]
      assert derived_relation["usedEntity"] == collection_tx["prov:entity"]["id"]
      assert derived_relation["generatedEntity"] == processing_tx["prov:entity"]["id"]
      assert linked_tx["hash"] != processing_tx["hash"]
      assert {:ok, _} = Transaction.validate(linked_tx)
    end
  end

  describe "from_map/1 and from_json/1" do
    test "creates valid transaction from map" do
      tx_data = ProvOData.milk_collection_transaction()
      {:ok, tx} = Transaction.from_map(tx_data)
      assert {:ok, _} = Transaction.validate(tx)
    end

    test "rejects invalid map data" do
      invalid_data = %{"prov:entity" => %{"type" => "prov:Entity"}}
      assert {:error, _} = Transaction.from_map(invalid_data)
    end

    test "creates valid transaction from JSON" do
      tx_data = ProvOData.milk_collection_transaction()
      {:ok, json} = Transaction.to_json(tx_data)
      {:ok, tx} = Transaction.from_json(json)
      assert {:ok, _} = Transaction.validate(tx)
      assert tx["prov:entity"]["id"] == tx_data["prov:entity"]["id"]
      assert tx["prov:activity"]["id"] == tx_data["prov:activity"]["id"]
      assert tx["prov:agent"]["id"] == tx_data["prov:agent"]["id"]
    end

    test "rejects invalid JSON" do
      invalid_json = "{invalid json}"
      assert {:error, _} = Transaction.from_json(invalid_json)
    end
  end

  describe "to_json/1" do
    test "serializes transaction to JSON" do
      tx_data = ProvOData.milk_collection_transaction()

      tx =
        Transaction.new(
          tx_data["prov:entity"],
          tx_data["prov:activity"],
          tx_data["prov:agent"],
          tx_data["prov:relations"],
          tx_data["supply_chain_data"]
        )

      {:ok, json} = Transaction.to_json(tx)
      assert {:ok, decoded} = Jason.decode(json)
      assert decoded["prov:entity"]["id"] == tx["prov:entity"]["id"]
      assert decoded["prov:activity"]["id"] == tx["prov:activity"]["id"]
      assert decoded["prov:agent"]["id"] == tx["prov:agent"]["id"]
      assert decoded["hash"] == Base.encode16(tx["hash"], case: :upper)
    end
  end
end
