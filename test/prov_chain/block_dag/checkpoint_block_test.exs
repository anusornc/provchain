defmodule ProvChain.BlockDag.CheckpointBlockTest do
  use ExUnit.Case, async: true

  alias ProvChain.BlockDag.CheckpointBlock
  alias ProvChain.BlockDag.AggregationBlock
  alias ProvChain.Crypto.Hash

  @tag :skip
  @tag :skip
  test "can create a new CheckpointBlock" do
    # Create some dummy AggregationBlocks to be referenced
    agg_block_1 = %AggregationBlock{hash: Hash.hash("agg1"), height: 2}
    agg_block_2 = %AggregationBlock{hash: Hash.hash("agg2"), height: 2}

    referenced_aggregation_block_hashes = [
      agg_block_1.hash,
      agg_block_2.hash
    ]

    validator = <<"cp_validator"::binary>>
    metadata = %{"consensus_round" => 1}

    checkpoint_block = CheckpointBlock.new(
      referenced_aggregation_block_hashes,
      validator,
      metadata
    )

    assert checkpoint_block.referenced_aggregation_block_hashes == referenced_aggregation_block_hashes
    assert checkpoint_block.validator == validator
    assert checkpoint_block.metadata == metadata
    assert is_binary(checkpoint_block.hash)
    assert is_integer(checkpoint_block.timestamp)
    assert checkpoint_block.height == 3 # Assuming CheckpointBlocks are level 3
  end
end