defmodule ProvChain.BlockDag.BlockAggregationTest do
  use ExUnit.Case, async: true

  alias ProvChain.BlockDag.BlockAggregation
  alias ProvChain.BlockDag.DataBlock
  alias ProvChain.BlockDag.AggregationBlock
  alias ProvChain.Crypto.Hash

  test "aggregates DataBlocks into an AggregationBlock" do
    # Create some dummy DataBlocks
    data_block_1 = %DataBlock{hash: Hash.hash("data1"), prev_hashes: [], height: 1}
    data_block_2 = %DataBlock{hash: Hash.hash("data2"), prev_hashes: [], height: 1}
    data_block_3 = %DataBlock{hash: Hash.hash("data3"), prev_hashes: [], height: 1}

    data_blocks_to_aggregate = [data_block_1, data_block_2, data_block_3]
    validator = <<"agg_validator"::binary>>
    metadata = %{"purpose" => "daily_aggregation"}

    {:ok, aggregation_block} = BlockAggregation.aggregate_data_blocks(
      data_blocks_to_aggregate,
      validator,
      metadata
    )

    assert aggregation_block.referenced_data_block_hashes == Enum.map(data_blocks_to_aggregate, &(&1.hash))
    assert aggregation_block.validator == validator
    assert aggregation_block.metadata == metadata
    assert is_binary(aggregation_block.hash)
    assert is_integer(aggregation_block.timestamp)
    assert aggregation_block.height == 2 # AggregationBlock should be height 2
  end

  test "aggregates AggregationBlocks into a CheckpointBlock" do
    # Create some dummy AggregationBlocks
    agg_block_1 = %AggregationBlock{hash: Hash.hash("agg1"), referenced_data_block_hashes: [], height: 2}
    agg_block_2 = %AggregationBlock{hash: Hash.hash("agg2"), referenced_data_block_hashes: [], height: 2}

    aggregation_blocks_to_aggregate = [agg_block_1, agg_block_2]
    validator = <<"cp_validator"::binary>>
    metadata = %{"consensus_round" => 1}

    {:ok, checkpoint_block} = BlockAggregation.aggregate_aggregation_blocks(
      aggregation_blocks_to_aggregate,
      validator,
      metadata
    )

    assert checkpoint_block.referenced_aggregation_block_hashes == Enum.map(aggregation_blocks_to_aggregate, &(&1.hash))
    assert checkpoint_block.validator == validator
    assert checkpoint_block.metadata == metadata
    assert is_binary(checkpoint_block.hash)
    assert is_integer(checkpoint_block.timestamp)
    assert checkpoint_block.height == 3 # CheckpointBlock should be height 3
  end

  test "returns error if no DataBlocks are provided for aggregation" do
    {:error, :no_data_blocks} = BlockAggregation.aggregate_data_blocks([], <<"validator"::binary>>, %{})
  end

  test "returns error if no AggregationBlocks are provided for aggregation" do
    {:error, :no_aggregation_blocks} = BlockAggregation.aggregate_aggregation_blocks([], <<"validator"::binary>>, %{})
  end
end