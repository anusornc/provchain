defmodule ProvChain.BlockDag.Transaction do
  @moduledoc """
  Transaction structure for ProvChain incorporating the PROV-O ontology.

  This module provides functions for creating, validating, and signing transactions
  that capture supply chain events using the PROV-O entity-activity-agent model.
  Each transaction represents a provenance record in the supply chain.
  """

  alias ProvChain.Crypto.Hash
  alias ProvChain.Crypto.Signature
  alias ProvChain.Utils.Serialization

  @type prov_entity :: map()
  @type prov_activity :: map()
  @type prov_agent :: map()
  @type prov_relation :: map()
  @type prov_relations :: %{required(String.t()) => prov_relation()}
  @type supply_chain_data :: map()

  @type t :: %{
    String.t() => term()
  }

  @required_relations ["wasGeneratedBy", "wasAttributedTo", "wasAssociatedWith"]
  @valid_relations @required_relations ++ ["used", "wasDerivedFrom", "wasInformedBy", "actedOnBehalfOf"]

  @doc """
  Creates a new transaction with PROV-O components.

  ## Parameters
    - entity: The entity involved in the transaction (e.g., milk batch)
    - activity: The activity performed (e.g., milk collection)
    - agent: The agent performing the activity (e.g., dairy farmer)
    - relations: Map of relationships between entity, activity, and agent
    - supply_chain_data: Additional domain-specific data that allows extending the transaction
                         for different supply chain domains (agriculture, pharmaceuticals,
                         electronics, etc.). This provides flexibility to adapt the system
                         for various traceability markets without changing the core PROV-O structure.
    - timestamp: Transaction timestamp (defaults to current time)

  ## Returns
    A new transaction structure with calculated hash
  """
  @spec new(prov_entity(), prov_activity(), prov_agent(), prov_relations(), supply_chain_data(), integer() | nil) :: t()
  def new(entity, activity, agent, relations, supply_chain_data, timestamp \\ nil) do
    timestamp = timestamp || :os.system_time(:millisecond)

    # Construct the transaction
    tx = %{
      "prov:entity" => entity,
      "prov:activity" => activity,
      "prov:agent" => agent,
      "prov:relations" => relations,
      "supply_chain_data" => supply_chain_data,  # Domain-specific data for different business use cases
                                                 # Can be customized for various markets like dairy, agriculture,
                                                 # pharmaceuticals, textiles, electronics, etc. while keeping
                                                 # the same PROV-O structure for all traceability systems
      "timestamp" => timestamp,
      "hash" => nil,  # Will be set below
      "signature" => nil,
      "signer" => nil
    }

    # Calculate and set the hash
    hash = calculate_hash(tx)
    Map.put(tx, "hash", hash)
  end

  @doc """
  Validates the structure of a transaction according to PROV-O model.

  ## Parameters
    - transaction: The transaction to validate

  ## Returns
    {:ok, transaction} if valid, {:error, reason} otherwise
  """
  @spec validate(t()) :: {:ok, t()} | {:error, String.t()}
  def validate(transaction) do
    with :ok <- validate_required_fields(transaction),
         :ok <- validate_prov_types(transaction),
         :ok <- validate_relations(transaction),
         :ok <- validate_hash(transaction) do
      {:ok, transaction}
    end
  end

  @doc """
  Signs a transaction with the given private key.

  ## Parameters
    - transaction: The transaction to sign
    - private_key: The private key to use for signing

  ## Returns
    The transaction with signature and signer added
  """
  @spec sign(t(), binary()) :: t()
  def sign(transaction, private_key) do
    # Get the public key from the private key
    {_private, public_key} = Signature.derive_public_key(private_key)

    # Sign the transaction hash
    signature = Signature.sign(transaction["hash"], private_key)

    # Add signature and signer to the transaction
    transaction
    |> Map.put("signature", signature)
    |> Map.put("signer", public_key)
  end

  @doc """
  Verifies the signature of a transaction.

  ## Parameters
    - transaction: The transaction to verify

  ## Returns
    true if the signature is valid, otherwise false
  """
  @spec verify_signature(t()) :: boolean()
  def verify_signature(%{"hash" => hash, "signature" => signature, "signer" => signer})
      when is_binary(hash) and is_binary(signature) and is_binary(signer) do
    Signature.verify(hash, signature, signer)
  end

  def verify_signature(_), do: false

  @doc """
  Links this transaction to a previous transaction by adding 'used' and 'wasDerivedFrom' relations.

  ## Parameters
    - transaction: The current transaction
    - previous_tx: The previous transaction to link to
    - role: Optional role for the 'used' relation

  ## Returns
    Updated transaction with added relations
  """
  @spec link_to_previous(t(), t(), String.t()) :: t()
  def link_to_previous(transaction, previous_tx, role \\ "input") do
    timestamp = transaction["timestamp"]
    current_entity_id = transaction["prov:entity"]["id"]
    current_activity_id = transaction["prov:activity"]["id"]
    previous_entity_id = previous_tx["prov:entity"]["id"]

    # Create the 'used' relation
    used_relation = %{
      "id" => "relation:usage:#{timestamp}",
      "activity" => current_activity_id,
      "entity" => previous_entity_id,
      "attributes" => %{
        "prov:time" => timestamp,
        "prov:role" => role
      }
    }

    # Create the 'wasDerivedFrom' relation
    derived_relation = %{
      "id" => "relation:derivation:#{timestamp}",
      "generatedEntity" => current_entity_id,
      "usedEntity" => previous_entity_id,
      "activity" => current_activity_id,
      "attributes" => %{
        "prov:type" => "prov:Revision"
      }
    }

    # Add the relations to the transaction
    updated_relations = transaction["prov:relations"]
                        |> Map.put("used", used_relation)
                        |> Map.put("wasDerivedFrom", derived_relation)

    # Recalculate hash after adding relations
    transaction = Map.put(transaction, "prov:relations", updated_relations)
    hash = calculate_hash(transaction)
    Map.put(transaction, "hash", hash)
  end

  @doc """
  Creates a transaction from raw data, ensuring it follows the PROV-O model.

  ## Parameters
    - data: Map containing transaction data

  ## Returns
    {:ok, transaction} if valid, {:error, reason} otherwise
  """
  @spec from_map(map()) :: {:ok, t()} | {:error, String.t()}
  def from_map(data) when is_map(data) do
    # Try to extract required fields
    with {:ok, entity} <- Map.fetch(data, "prov:entity"),
         {:ok, activity} <- Map.fetch(data, "prov:activity"),
         {:ok, agent} <- Map.fetch(data, "prov:agent"),
         {:ok, relations} <- Map.fetch(data, "prov:relations"),
         {:ok, supply_chain_data} <- Map.fetch(data, "supply_chain_data") do

      timestamp = Map.get(data, "timestamp", :os.system_time(:millisecond))

      # Create and validate the transaction
      tx = new(entity, activity, agent, relations, supply_chain_data, timestamp)
      validate(tx)
    else
      :error -> {:error, "Missing required fields in transaction data"}
    end
  end

  @doc """
  Converts a transaction to a serialized JSON string.

  ## Parameters
    - transaction: The transaction to serialize

  ## Returns
    JSON string representation of the transaction
  """
  @spec to_json(t()) :: String.t()
  def to_json(transaction) do
    Serialization.encode(transaction)
  end

  @doc """
  Creates a transaction from a JSON string.

  ## Parameters
    - json: JSON string representation of the transaction

  ## Returns
    {:ok, transaction} if valid, {:error, reason} otherwise
  """
  @spec from_json(String.t()) :: {:ok, t()} | {:error, String.t()}
  def from_json(json) when is_binary(json) do
    case Serialization.decode(json) do
      {:ok, data} -> from_map(data)
      {:error, reason} -> {:error, "Failed to decode JSON: #{inspect(reason)}"}
    end
  end

  # Private functions

  @spec calculate_hash(map()) :: String.t()
  defp calculate_hash(transaction) do
    # Create a map with fields that should be included in the hash
    map_for_hash = transaction
                   |> Map.drop(["hash", "signature", "signer"])

    # Serialize and hash
    serialized = Serialization.encode(map_for_hash)
    Hash.to_hex(Hash.hash(serialized))
  end

  @spec validate_required_fields(map()) :: :ok | {:error, String.t()}
  defp validate_required_fields(transaction) do
    required_fields = ["prov:entity", "prov:activity", "prov:agent", "prov:relations", "supply_chain_data", "hash"]

    missing_fields = Enum.filter(required_fields, fn field ->
      not Map.has_key?(transaction, field)
    end)

    if Enum.empty?(missing_fields) do
      :ok
    else
      {:error, "Missing required fields: #{Enum.join(missing_fields, ", ")}"}
    end
  end

  @spec validate_prov_types(map()) :: :ok | {:error, String.t()}
  defp validate_prov_types(transaction) do
    # Check entity type
    entity_type = get_in(transaction, ["prov:entity", "type"])
    if entity_type != "prov:Entity" do
      {:error, "Invalid entity type: #{entity_type}"}
    else
      # Check activity type
      activity_type = get_in(transaction, ["prov:activity", "type"])
      if activity_type != "prov:Activity" do
        {:error, "Invalid activity type: #{activity_type}"}
      else
        # Check agent type
        agent_type = get_in(transaction, ["prov:agent", "type"])
        if agent_type != "prov:Agent" do
          {:error, "Invalid agent type: #{agent_type}"}
        else
          :ok
        end
      end
    end
  end

  @spec validate_relations(map()) :: :ok | {:error, String.t()}
  defp validate_relations(transaction) do
    relations = transaction["prov:relations"]

    # Check if all required relations are present
    missing_relations = Enum.filter(@required_relations, fn relation ->
      not Map.has_key?(relations, relation)
    end)

    if not Enum.empty?(missing_relations) do
      {:error, "Missing required relations: #{Enum.join(missing_relations, ", ")}"}
    else
      # Check if any invalid relations are present
      invalid_relations = Map.keys(relations)
                          |> Enum.filter(fn key -> not Enum.member?(@valid_relations, key) end)

      if not Enum.empty?(invalid_relations) do
        {:error, "Invalid relations: #{Enum.join(invalid_relations, ", ")}"}
      else
        :ok
      end
    end
  end

  @spec validate_hash(map()) :: :ok | {:error, String.t()}
  defp validate_hash(transaction) do
    # Calculate the hash of the transaction
    expected_hash = calculate_hash(transaction)

    # Compare with the stored hash
    if transaction["hash"] == expected_hash do
      :ok
    else
      {:error, "Invalid hash: #{transaction["hash"]} != #{expected_hash}"}
    end
  end

  @doc """
  Converts a transaction to a human-readable string format.
  ## Parameters
    - transaction: The transaction to convert
  ## Returns
    A string representation of the transaction
  """
  @spec to_string(t()) :: String.t()
  def to_string(transaction) do
    transaction
    |> Map.drop(["hash", "signature", "signer"])
    |> Enum.map(fn {key, value} -> "#{key}: #{inspect(value)}" end)
    |> Enum.join("\n")
  end
  


end
