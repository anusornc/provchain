defmodule ProvChain.BlockDag.Block do
  @moduledoc """
  Block structure for the ProvChain Block-DAG.

  Specialized for dairy supply chain tracking with PROV-O integration.
  """

  defstruct [
    :hash,              # Block hash
    :prev_hashes,       # List of previous block hashes this block references
    :timestamp,         # Block creation timestamp
    :height,            # Logical height in the DAG
    :validator,         # Block validator public key
    :signature,         # Validator signature
    :transactions,      # List of transactions in this block
    :merkle_root,       # Merkle root of transactions
    :supply_chain_type, # Type of supply chain event (e.g., "milk_collection", "processing", "packaging")
    :dag_weight,        # Weight for PHANTOM-like ordering
    :metadata           # Additional metadata for supply chain context
  ]

  alias ProvChain.Crypto.Hash

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

  ## Parameters
    - prev_hashes: List of hashes of blocks this one references
    - transactions: List of transactions to include
    - validator: Public key of the validator creating this block
    - supply_chain_type: Type of supply chain event in this block
    - metadata: Additional domain-specific data (optional)

  ## Returns
    A new block structure with calculated hash and height
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

    # Determine height as max of prev_blocks height + 1
    height = calculate_height(prev_hashes)

    # Calculate DAG weight based on PHANTOM-like algorithm
    dag_weight = calculate_weight(prev_hashes, height)

    # Calculate merkle root
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
      hash: nil,  # Will be set below
      signature: nil
    }

    # Calculate hash after block is constructed
    hash = calculate_hash(block)
    %{block | hash: hash}
  end

  @doc """
  Signs the block with the validator's private key.

  ## Parameters
    - block: The block to sign
    - private_key: The validator's private key

  ## Returns
    The block with signature added
  """
  @spec sign(t(), binary()) :: t()
  def sign(%__MODULE__{} = block, private_key) when is_binary(private_key) do
    signature = ProvChain.Crypto.Signature.sign(block.hash, private_key)
    %{block | signature: signature}
  end

  @doc """
  Verifies the block's signature.

  ## Returns
    true if the signature is valid, otherwise false
  """
  @spec verify_signature(t()) :: boolean()
  def verify_signature(%__MODULE__{hash: hash, signature: signature, validator: validator})
    when is_binary(hash) and is_binary(signature) and is_binary(validator) do
    ProvChain.Crypto.Signature.verify(hash, signature, validator)
  end

  def verify_signature(_), do: false

  @doc """
  Calculates the height of the block based on previous blocks.

  Returns 0 for genesis blocks (with no predecessors),
  otherwise returns max height of predecessors + 1.

  ## Parameters
    - prev_hashes: List of previous block hashes

  ## Returns
    The calculated height as an integer
  """
  @spec calculate_height(list(hash_type())) :: non_neg_integer()
  def calculate_height([]), do: 0
  def calculate_height(_prev_hashes) do
    # In a full implementation, we would fetch the actual blocks
    # and find the maximum height among them
    # For this phase, we'll use a simplified implementation
    1
  end

  @doc """
  Calculates the DAG weight based on the PHANTOM algorithm adapted for dairy chain.

  ## Parameters
    - prev_hashes: List of previous block hashes
    - height: The block's height in the DAG

  ## Returns
    The calculated weight value
  """
  @spec calculate_weight(list(hash_type()), non_neg_integer()) :: non_neg_integer()
  def calculate_weight(prev_hashes, height) when is_list(prev_hashes) and is_integer(height) and height >= 0 do
    # Will implement PHANTOM-like algorithm with dairy chain optimizations
    # For now, simplified implementation
    length(prev_hashes) + height
  end

  @doc """
  Calculates the Merkle root of the transactions.

  ## Parameters
    - transactions: List of transactions to include in the Merkle tree

  ## Returns
    The Merkle root hash as a binary
  """
  @spec calculate_merkle_root(list(transaction_type())) :: binary()
  def calculate_merkle_root([]) do
    <<0::256>>  # Return zero hash for empty transaction list
  end

  def calculate_merkle_root(transactions) when is_list(transactions) do
    # For now, simplified implementation
    # Will be replaced with proper Merkle tree implementation
    transaction_hashes = Enum.map(transactions, fn tx ->
      case tx do
        %{hash: hash} when is_binary(hash) -> hash
        _ -> Hash.hash(tx)
      end
    end)

    Hash.merkle_root(transaction_hashes)
  end

  @doc """
  Calculates the hash of the block.

  ## Parameters
    - block: The block to hash

  ## Returns
    The calculated hash as a binary
  """
  @spec calculate_hash(t()) :: binary()
  def calculate_hash(%__MODULE__{} = block) do
    # Serialize block (excluding hash and signature) and hash
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

    # Use try/catch to handle any serialization errors
    try do
      serialized = ProvChain.Utils.Serialization.encode(map_for_hash)
      Hash.hash(serialized)
    rescue
      _ -> Hash.hash(inspect(map_for_hash))
    end
  end
end
