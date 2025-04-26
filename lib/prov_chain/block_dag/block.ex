defmodule ProvChain.BlockDag.Block do
  @moduledoc """
  Block structure for the ProvChain Block-DAG.
  Specialized for dairy supply chain tracking with PROV-O integration.
  """

  defstruct [
    :hash,
    :prev_hashes,
    :timestamp,
    :height,
    :validator,
    :signature,
    :transactions,
    :merkle_root,
    :supply_chain_type,
    :dag_weight,
    :metadata
  ]

  alias ProvChain.Crypto.Hash
  alias ProvChain.Crypto.Signature

  @type hash_type :: binary()
  @type transaction_type :: map()

  @type t :: %__MODULE__{
          hash: hash_type() | nil,
          prev_hashes: list(hash_type()),
          timestamp: non_neg_integer(),
          height: non_neg_integer(),
          validator: binary(),
          signature: binary() | nil,
          transactions: list(transaction_type()),
          merkle_root: binary(),
          supply_chain_type: String.t(),
          dag_weight: non_neg_integer(),
          metadata: map()
        }

  @doc """
  Creates a new block with the given parameters.
  """
  @spec new(
          list(hash_type()),
          list(transaction_type()),
          binary(),
          String.t(),
          map()
        ) :: t()
  def new(prev_hashes, transactions, validator, supply_chain_type, metadata \\ %{})
      when is_list(prev_hashes) and is_list(transactions) and
             is_binary(validator) and is_binary(supply_chain_type) and
             is_map(metadata) do
    timestamp = :os.system_time(:millisecond)
    height = calculate_height(prev_hashes)
    dag_weight = calculate_weight(prev_hashes, height)
    merkle_root = calculate_merkle_root(transactions)

    block = %__MODULE__{
      prev_hashes: prev_hashes,
      timestamp: timestamp,
      height: height,
      validator: validator,
      transactions: transactions,
      merkle_root: merkle_root,
      supply_chain_type: supply_chain_type,
      dag_weight: dag_weight,
      metadata: metadata,
      hash: nil,
      signature: nil
    }

    hash = calculate_hash(block)
    %{block | hash: hash}
  end

  @doc """
  Signs the block with the validator's private key.
  """
  @spec sign(t(), binary()) :: {:ok, t()} | {:error, term()}
  def sign(%__MODULE__{} = block, private_key) when is_binary(private_key) do
    with {:ok, signature} <- Signature.sign(block.hash, private_key) do
      {:ok, %{block | signature: signature}}
    end
  end

  def sign(_, _), do: {:error, :invalid_input}

  @doc """
  Verifies the block's signature.
  """
  @spec verify_signature(t()) :: boolean()
  def verify_signature(%__MODULE__{hash: hash, signature: signature, validator: validator})
      when is_binary(hash) and is_binary(signature) and is_binary(validator) do
    Signature.verify(hash, signature, validator)
  end

  def verify_signature(_), do: false

  @doc """
  Calculates the height of the block based on previous blocks.
  """
  @spec calculate_height(list(hash_type())) :: non_neg_integer()
  def calculate_height([]), do: 0
  def calculate_height(_prev_hashes), do: 1

  @doc """
  Calculates the DAG weight based on the PHANTOM algorithm adapted for dairy chain.
  """
  @spec calculate_weight(list(hash_type()), non_neg_integer()) :: non_neg_integer()
  def calculate_weight(prev_hashes, height)
      when is_list(prev_hashes) and is_integer(height) and height >= 0 do
    length(prev_hashes) + height
  end

  @doc """
  Calculates the Merkle root of the transactions.
  """
  @spec calculate_merkle_root(list(transaction_type())) :: binary()
  def calculate_merkle_root([]) do
    <<0::256>>
  end

  def calculate_merkle_root(transactions) when is_list(transactions) do
    transaction_hashes =
      Enum.map(transactions, fn tx ->
        case tx do
          %{hash: hash} when is_binary(hash) -> hash
          _ -> Hash.hash(tx)
        end
      end)

    Hash.merkle_root(transaction_hashes)
  end

  @doc """
  Calculates the hash of the block.
  """
  @spec calculate_hash(t()) :: binary()
  def calculate_hash(%__MODULE__{} = block) do
    map_for_hash = %{
      prev_hashes: block.prev_hashes,
      timestamp: block.timestamp,
      height: block.height,
      validator: block.validator,
      merkle_root: block.merkle_root,
      supply_chain_type: block.supply_chain_type,
      dag_weight: block.dag_weight,
      metadata: block.metadata
    }

    try do
      serialized = ProvChain.Utils.Serialization.encode(map_for_hash)
      Hash.hash(serialized)
    rescue
      _ -> Hash.hash(inspect(map_for_hash))
    end
  end
end
