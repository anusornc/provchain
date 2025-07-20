defmodule ProvChain.BlockDag.BlockAggregation do
  @moduledoc """
  Handles the aggregation logic for different block types in the ProvChain Block-DAG.
  """

  alias ProvChain.BlockDag.DataBlock
  alias ProvChain.BlockDag.AggregationBlock
  alias ProvChain.BlockDag.CheckpointBlock

  @doc """
  Aggregates a list of DataBlocks into a new AggregationBlock.
  """
  @spec aggregate_data_blocks(list(DataBlock.t()), binary(), map()) :: {:ok, AggregationBlock.t()} | {:error, atom()}
  def aggregate_data_blocks(data_blocks, validator, metadata) do
    if Enum.empty?(data_blocks) do
      {:error, :no_data_blocks}
    else
      referenced_data_block_hashes = Enum.map(data_blocks, &(&1.hash))
      aggregation_block = AggregationBlock.new(referenced_data_block_hashes, validator, metadata)
      {:ok, aggregation_block}
    end
  end

  @doc """
  Aggregates a list of AggregationBlocks into a new CheckpointBlock.
  """
  @spec aggregate_aggregation_blocks(list(AggregationBlock.t()), binary(), map()) :: {:ok, CheckpointBlock.t()} | {:error, atom()}
  def aggregate_aggregation_blocks(aggregation_blocks, validator, metadata) do
    if Enum.empty?(aggregation_blocks) do
      {:error, :no_aggregation_blocks}
    else
      referenced_aggregation_block_hashes = Enum.map(aggregation_blocks, &(&1.hash))
      checkpoint_block = CheckpointBlock.new(referenced_aggregation_block_hashes, validator, metadata)
      {:ok, checkpoint_block}
    end
  end
end
