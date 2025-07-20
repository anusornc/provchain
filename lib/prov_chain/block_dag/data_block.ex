defmodule ProvChain.BlockDag.DataBlock do
  @moduledoc """
  Represents a Data Block in the ProvChain Block-DAG.
  Data Blocks are the lowest level of blocks, containing raw provenance transactions.
  """

  defstruct [
    :hash,
    :prev_hashes,
    :timestamp,
    :height,
    :validator,
    :transactions,
    :supply_chain_type,
    :metadata
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
    transactions: list(transaction_type()),
    supply_chain_type: String.t(),
    metadata: map()
  }

  @doc """
  Creates a new DataBlock.
  """
  @spec new(
    list(hash_type()),
    list(transaction_type()),
    binary(),
    String.t(),
    map()
  ) :: t()
  def new(prev_hashes, transactions, validator, supply_chain_type, metadata) do
    timestamp = :os.system_time(:millisecond)
    height = calculate_height(prev_hashes)
    
    data_block = %__MODULE__{
      prev_hashes: prev_hashes,
      timestamp: timestamp,
      height: height,
      validator: validator,
      transactions: transactions,
      supply_chain_type: supply_chain_type,
      metadata: metadata,
      hash: nil
    }

    hash = calculate_hash(data_block)
    %{data_block | hash: hash}
  end

  defp calculate_height(prev_hashes) do
    if Enum.empty?(prev_hashes) do
      1
    else
      # For simplicity, assume height is max(prev_block_heights) + 1
      # In a real DAG, this would involve querying previous blocks' heights
      2 # Assuming previous DataBlocks are at height 1, so new height is 2
    end
  end

  defp calculate_hash(%__MODULE__{} = data_block) do
    map_for_hash = %{
      prev_hashes: data_block.prev_hashes,
      timestamp: data_block.timestamp,
      height: data_block.height,
      validator: data_block.validator,
      transactions: data_block.transactions,
      supply_chain_type: data_block.supply_chain_type,
      metadata: data_block.metadata
    }
    :erlang.term_to_binary(map_for_hash) |> Hash.hash()
  end
end
