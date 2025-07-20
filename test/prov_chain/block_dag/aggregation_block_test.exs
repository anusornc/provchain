defmodule ProvChain.BlockDag.AggregationBlockTest do
  use ExUnit.Case, async: true

  alias ProvChain.BlockDag.AggregationBlock
  alias ProvChain.BlockDag.DataBlock
  alias ProvChain.Crypto.Hash

  @tag :skip
  @tag :skip
  test "can create a new AggregationBlock" do
    # Create some dummy DataBlocks to be referenced
    data_block_1 = %DataBlock{hash: Hash.hash("data1"), prev_hashes: [], height: 1}
    data_block_2 = %DataBlock{hash: Hash.hash("data2"), prev_hashes: [], height: 1}
    data_block_3 = %DataBlock{hash: Hash.hash("data3"), prev_hashes: [], height: 1}

    referenced_data_block_hashes = [
      data_block_1.hash,
      data_block_2.hash,
      data_block_3.hash
    ]

    validator = <<"agg_validator"::binary>>
    metadata = %{"purpose" => "daily_aggregation"}

    aggregation_block = AggregationBlock.new(
      referenced_data_block_hashes,
      validator,
      metadata
    )

    assert aggregation_block.referenced_data_block_hashes == referenced_data_block_hashes
    assert aggregation_block.validator == validator
    assert aggregation_block.metadata == metadata
    assert is_binary(aggregation_block.hash)
    assert is_integer(aggregation_block.timestamp)
    assert aggregation_block.height == 2 # Assuming AggregationBlocks are level 2
  end
end