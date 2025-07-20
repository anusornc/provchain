defmodule ProvChain.BlockDag.AggregationBlock do
  @moduledoc """
  Represents an Aggregation Block in the ProvChain Block-DAG.
  Aggregation Blocks group and reference multiple Data Blocks.
  """

  defstruct [
    :hash,
    :referenced_data_block_hashes,
    :timestamp,
    :height,
    :validator,
    :metadata
  ]

  alias ProvChain.Crypto.Hash
  alias ProvChain.Storage.BlockStore

  @type hash_type :: binary()

  @type t :: %__MODULE__{
    hash: hash_type() | nil,
    referenced_data_block_hashes: list(hash_type()),
    timestamp: non_neg_integer(),
    height: non_neg_integer(),
    validator: binary(),
    metadata: map()
  }

  @doc """
  Creates a new AggregationBlock.
  """
  @spec new(
    list(hash_type()),
    binary(),
    map()
  ) :: t()
  def new(referenced_data_block_hashes, validator, metadata) do
    timestamp = :os.system_time(:millisecond)
    height = calculate_height(referenced_data_block_hashes)

    aggregation_block = %__MODULE__{
      referenced_data_block_hashes: referenced_data_block_hashes,
      timestamp: timestamp,
      height: height,
      validator: validator,
      metadata: metadata,
      hash: nil
    }

    hash = calculate_hash(aggregation_block)
    %{aggregation_block | hash: hash}
  end

  defp calculate_height(_referenced_data_block_hashes) do
    2 # Aggregation Blocks are level 2
  end

  defp calculate_hash(%__MODULE__{} = aggregation_block) do
    map_for_hash = %{
      referenced_data_block_hashes: aggregation_block.referenced_data_block_hashes,
      timestamp: aggregation_block.timestamp,
      height: aggregation_block.height,
      validator: aggregation_block.validator,
      metadata: aggregation_block.metadata
    }
    :erlang.term_to_binary(map_for_hash) |> Hash.hash()
  end
end
