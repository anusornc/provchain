defmodule ProvChain.BlockDag.TipSelection do
  @moduledoc """
  Provides functions for selecting tips (unreferenced blocks) in the Block-DAG.
  """

  alias ProvChain.BlockDag.DataBlock
  alias ProvChain.BlockDag.AggregationBlock
  alias ProvChain.BlockDag.CheckpointBlock

  @doc """
  Selects tips from a list of blocks.
  A tip is a block that is not referenced by any other block in the given list.
  """
  @spec select_tips(list(DataBlock.t() | AggregationBlock.t() | CheckpointBlock.t())) :: list(binary())
  def select_tips(blocks) when is_list(blocks) do
    if Enum.empty?(blocks) do
      []
    else
      all_hashes = Enum.map(blocks, &(&1.hash))
      all_prev_hashes = Enum.flat_map(blocks, &(&1.prev_hashes))

      # A block is a tip if its hash is not found in any other block's prev_hashes
      Enum.filter(all_hashes, fn hash ->
        hash not in all_prev_hashes
      end)
    end
  end
end
