defmodule ProvChain.BlockDag.TipSelection do
  @moduledoc """
  Implements the tip selection algorithm for the Block-DAG.
  """

  @doc """
  Selects tips from the Block-DAG.
  """
  alias ProvChain.Storage.MemoryStore

  def select_tips do
    case MemoryStore.get_tip_set() do
      [] -> {:ok, :genesis_block_hash}
      tips -> {:ok, tips}
    end
  end
end