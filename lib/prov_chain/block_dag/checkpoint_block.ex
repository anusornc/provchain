defmodule ProvChain.BlockDag.CheckpointBlock do
  @moduledoc """
  Represents a Checkpoint/Consensus Block in the ProvChain Block-DAG.
  Checkpoint Blocks consolidate Aggregation Blocks and play a role in consensus.
  """

  defstruct [
    :hash,
    :referenced_aggregation_block_hashes,
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
    referenced_aggregation_block_hashes: list(hash_type()),
    timestamp: non_neg_integer(),
    height: non_neg_integer(),
    validator: binary(),
    metadata: map()
  }

  @doc """
  Creates a new CheckpointBlock.
  """
  @spec new(
    list(hash_type()),
    binary(),
    map()
  ) :: t()
  def new(referenced_aggregation_block_hashes, validator, metadata) do
    timestamp = :os.system_time(:millisecond)
    height = calculate_height(referenced_aggregation_block_hashes)

    checkpoint_block = %__MODULE__{
      referenced_aggregation_block_hashes: referenced_aggregation_block_hashes,
      timestamp: timestamp,
      height: height,
      validator: validator,
      metadata: metadata,
      hash: nil
    }

    hash = calculate_hash(checkpoint_block)
    %{checkpoint_block | hash: hash}
  end

  defp calculate_height(_referenced_aggregation_block_hashes) do
    3 # Checkpoint Blocks are level 3
  end

  defp calculate_hash(%__MODULE__{} = checkpoint_block) do
    map_for_hash = %{
      referenced_aggregation_block_hashes: checkpoint_block.referenced_aggregation_block_hashes,
      timestamp: checkpoint_block.timestamp,
      height: checkpoint_block.height,
      validator: checkpoint_block.validator,
      metadata: checkpoint_block.metadata
    }
    :erlang.term_to_binary(map_for_hash) |> Hash.hash()
  end
end
