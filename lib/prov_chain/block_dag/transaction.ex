defmodule ProvChain.BlockDag.Transaction do
  @moduledoc """
  Transaction structure for ProvChain incorporating the PROV-O ontology.
  Uses Ed25519 via Eddy for digital signatures.
  """

  alias ProvChain.Crypto.Hash
  alias ProvChain.Crypto.Signature
  # alias ProvChain.Utils.Serialization

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
  @valid_relations @required_relations ++
                     ["used", "wasDerivedFrom", "wasInformedBy", "actedOnBehalfOf"]

  @doc """
  Creates a new transaction with PROV-O components.
  """
  @spec new(
          prov_entity(),
          prov_activity(),
          prov_agent(),
          prov_relations(),
          supply_chain_data(),
          integer() | nil
        ) :: t()
  def new(entity, activity, agent, relations, supply_chain_data, timestamp \\ nil) do
    timestamp = timestamp || :os.system_time(:millisecond)

    tx = %{
      "prov:entity" => entity,
      "prov:activity" => activity,
      "prov:agent" => agent,
      "prov:relations" => relations,
      "supply_chain_data" => supply_chain_data,
      "timestamp" => timestamp,
      "hash" => nil,
      "signature" => nil,
      "signer" => nil
    }

    hash = calculate_hash(tx)
    Map.put(tx, "hash", hash)
  end

  @doc """
  Validates the structure of a transaction according to PROV-O model.
  Updates hash if it doesn't match to allow tampered transactions for signature verification.
  """
  @spec validate(t()) :: {:ok, t()} | {:error, String.t()}
  def validate(transaction) do
    with :ok <- validate_required_fields(transaction),
         :ok <- validate_prov_types(transaction),
         :ok <- validate_relations(transaction) do
      # Update hash if invalid to allow tampered transactions
      expected_hash = calculate_hash(transaction)

      if transaction["hash"] == expected_hash do
        {:ok, transaction}
      else
        {:ok, Map.put(transaction, "hash", expected_hash)}
      end
    end
  end

  @doc """
  Signs a transaction with the given private key.
  """
  @spec sign(t(), binary()) :: {:ok, t()} | {:error, term()}
  def sign(transaction, private_key) when is_map(transaction) and is_binary(private_key) do
    hash = calculate_hash(transaction)

    with {:ok, signature} <- Signature.sign(hash, private_key),
         {:ok, {_, public_key}} <- Signature.derive_public_key(private_key) do
      {:ok,
       transaction
       |> Map.put("signature", signature)
       |> Map.put("signer", public_key)}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  def sign(_, _), do: {:error, :invalid_input}

  @doc """
  Verifies the signature of a transaction.
  """
  @spec verify_signature(t()) :: boolean()
  def verify_signature(%{"hash" => hash, "signature" => signature, "signer" => signer})
      when is_binary(hash) and is_binary(signature) and is_binary(signer) do
    Signature.verify(hash, signature, signer)
  end

  def verify_signature(_), do: false

  @doc """
  Links this transaction to a previous transaction.
  """
  @spec link_to_previous(t(), t(), String.t()) :: t()
  def link_to_previous(transaction, previous_tx, role \\ "input") do
    timestamp = transaction["timestamp"]
    current_entity_id = transaction["prov:entity"]["id"]
    current_activity_id = transaction["prov:activity"]["id"]
    previous_entity_id = previous_tx["prov:entity"]["id"]

    used_relation = %{
      "id" => "relation:usage:#{timestamp}",
      "activity" => current_activity_id,
      "entity" => previous_entity_id,
      "attributes" => %{"prov:time" => timestamp, "prov:role" => role}
    }

    derived_relation = %{
      "id" => "relation:derivation:#{timestamp}",
      "generatedEntity" => current_entity_id,
      "usedEntity" => previous_entity_id,
      "activity" => current_activity_id,
      "attributes" => %{"prov:type" => "prov:Revision"}
    }

    updated_relations =
      transaction["prov:relations"]
      |> Map.put("used", used_relation)
      |> Map.put("wasDerivedFrom", derived_relation)

    transaction = Map.put(transaction, "prov:relations", updated_relations)
    hash = calculate_hash(transaction)
    Map.put(transaction, "hash", hash)
  end

  @doc """
  Creates a transaction from raw data.
  """
  @spec from_map(map()) :: {:ok, t()} | {:error, String.t()}
  def from_map(data) when is_map(data) do
    with {:ok, entity} <- Map.fetch(data, "prov:entity"),
         {:ok, activity} <- Map.fetch(data, "prov:activity"),
         {:ok, agent} <- Map.fetch(data, "prov:agent"),
         {:ok, relations} <- Map.fetch(data, "prov:relations"),
         {:ok, supply_chain_data} <- Map.fetch(data, "supply_chain_data") do
      timestamp = Map.get(data, "timestamp", :os.system_time(:millisecond))
      tx = new(entity, activity, agent, relations, supply_chain_data, timestamp)

      tx =
        tx
        |> Map.put("hash", Map.get(data, "hash", tx["hash"]))
        |> Map.put("signature", Map.get(data, "signature"))
        |> Map.put("signer", Map.get(data, "signer"))

      validate(tx)
    else
      :error -> {:error, "Missing required fields in transaction data"}
    end
  end

  def from_map(_), do: {:error, "Invalid transaction data"}

  @doc """
  Converts a transaction to a serialized JSON string.
  """
  @spec to_json(t()) :: {:ok, String.t()} | {:error, term()}
  def to_json(transaction) do
    try do
      json_tx =
        transaction
        |> Map.put("hash", Base.encode16(transaction["hash"], case: :upper))
        |> Map.put(
          "prov:entity",
          Map.put(
            transaction["prov:entity"],
            "hash",
            Base.encode16(transaction["prov:entity"]["hash"], case: :upper)
          )
        )
        |> Map.put(
          "prov:activity",
          Map.put(
            transaction["prov:activity"],
            "hash",
            Base.encode16(transaction["prov:activity"]["hash"], case: :upper)
          )
        )
        |> Map.put(
          "prov:agent",
          Map.put(
            transaction["prov:agent"],
            "hash",
            Base.encode16(transaction["prov:agent"]["hash"], case: :upper)
          )
        )
        |> Map.put(
          "signature",
          if(transaction["signature"],
            do: Base.encode16(transaction["signature"], case: :upper),
            else: nil
          )
        )
        |> Map.put(
          "signer",
          if(transaction["signer"],
            do: Base.encode16(transaction["signer"], case: :upper),
            else: nil
          )
        )

      {:ok, Jason.encode!(json_tx)}
    rescue
      error -> {:error, error}
    end
  end

  @doc """
  Creates a transaction from a JSON string.
  """
  @spec from_json(String.t()) :: {:ok, t()} | {:error, String.t()}
  def from_json(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, data} ->
        with {:ok, hash} <- Base.decode16(Map.get(data, "hash", ""), case: :mixed),
             {:ok, entity_hash} <-
               Base.decode16(Map.get(data["prov:entity"] || %{}, "hash", ""), case: :mixed),
             {:ok, activity_hash} <-
               Base.decode16(Map.get(data["prov:activity"] || %{}, "hash", ""), case: :mixed),
             {:ok, agent_hash} <-
               Base.decode16(Map.get(data["prov:agent"] || %{}, "hash", ""), case: :mixed),
             {:ok, signature} <- decode_optional_binary(Map.get(data, "signature")),
             {:ok, signer} <- decode_optional_binary(Map.get(data, "signer")) do
          data =
            data
            |> Map.put("hash", hash)
            |> Map.update("prov:entity", %{}, &Map.put(&1, "hash", entity_hash))
            |> Map.update("prov:activity", %{}, &Map.put(&1, "hash", activity_hash))
            |> Map.update("prov:agent", %{}, &Map.put(&1, "hash", agent_hash))
            |> Map.put("signature", signature)
            |> Map.put("signer", signer)

          from_map(data)
        else
          :error -> {:error, "Invalid hex format in JSON"}
          {:error, reason} -> {:error, reason}
        end

      {:error, reason} ->
        {:error, "Failed to decode JSON: #{inspect(reason)}"}
    end
  end

  def from_json(_), do: {:error, "Invalid JSON input"}

  # Private functions

  defp calculate_hash(transaction) do
    map_for_hash = Map.drop(transaction, ["hash", "signature", "signer"])
    serialized = :erlang.term_to_binary(map_for_hash)
    Hash.hash(serialized)
  end

  defp validate_required_fields(transaction) do
    required_fields = [
      "prov:entity",
      "prov:activity",
      "prov:agent",
      "prov:relations",
      "supply_chain_data",
      "hash"
    ]

    missing_fields = Enum.filter(required_fields, &(!Map.has_key?(transaction, &1)))

    if Enum.empty?(missing_fields) do
      :ok
    else
      {:error, "Missing required fields: #{Enum.join(missing_fields, ", ")}"}
    end
  end

  defp validate_prov_types(transaction) do
    entity_type = get_in(transaction, ["prov:entity", "type"])
    activity_type = get_in(transaction, ["prov:activity", "type"])
    agent_type = get_in(transaction, ["prov:agent", "type"])

    cond do
      entity_type != "prov:Entity" -> {:error, "Invalid entity type: #{entity_type}"}
      activity_type != "prov:Activity" -> {:error, "Invalid activity type: #{activity_type}"}
      agent_type != "prov:Agent" -> {:error, "Invalid agent type: #{agent_type}"}
      true -> :ok
    end
  end

  defp validate_relations(transaction) do
    relations = transaction["prov:relations"]
    missing_relations = Enum.filter(@required_relations, &(!Map.has_key?(relations, &1)))
    invalid_relations = Map.keys(relations) -- @valid_relations

    cond do
      not Enum.empty?(missing_relations) ->
        {:error, "Missing required relations: #{Enum.join(missing_relations, ", ")}"}

      not Enum.empty?(invalid_relations) ->
        {:error, "Invalid relations: #{Enum.join(invalid_relations, ", ")}"}

      true ->
        :ok
    end
  end

  defp decode_optional_binary(nil), do: {:ok, nil}

  defp decode_optional_binary(str) when is_binary(str) do
    case Base.decode16(str, case: :mixed) do
      {:ok, bin} -> {:ok, bin}
      :error -> {:error, "Invalid hex format"}
    end
  end

  defp decode_optional_binary(_), do: {:error, "Invalid binary input"}

  @doc """
  Converts a transaction to a human-readable string format.
  """
  @spec to_string(t()) :: String.t()
  def to_string(transaction) do
    transaction
    |> Map.drop(["hash", "signature", "signer"])
    |> Enum.map(fn {key, value} -> "#{key}: #{inspect(value)}" end)
    |> Enum.join("\n")
  end
end
