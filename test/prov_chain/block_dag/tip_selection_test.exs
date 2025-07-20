defmodule ProvChain.BlockDag.TipSelectionTest do
  use ExUnit.Case, async: true

  alias ProvChain.BlockDag.TipSelection
  alias ProvChain.BlockDag.DataBlock
  alias ProvChain.Crypto.Hash

  test "selects tips from a simple set of blocks" do
    # Create some dummy DataBlocks
    block1 = %DataBlock{hash: Hash.hash("block1"), prev_hashes: [], height: 1}
    block2 = %DataBlock{hash: Hash.hash("block2"), prev_hashes: [], height: 1}
    block3 = %DataBlock{hash: Hash.hash("block3"), prev_hashes: [block1.hash], height: 2}
    block4 = %DataBlock{hash: Hash.hash("block4"), prev_hashes: [block1.hash, block2.hash], height: 2}

    all_blocks = [block1, block2, block3, block4]

    # In a real scenario, these blocks would be in storage.
    # For now, we'll pass them directly.
    tips = TipSelection.select_tips(all_blocks)

    # Expected tips are block3 and block4, as they are not referenced by any other blocks in this set.
    # Note: This is a simplified scenario. Real tip selection is more complex.
    assert Enum.sort(tips) == Enum.sort([block3.hash, block4.hash])
  end

  test "selects tips when some blocks are referenced multiple times" do
    block1 = %DataBlock{hash: Hash.hash("blockA"), prev_hashes: [], height: 1}
    block2 = %DataBlock{hash: Hash.hash("blockB"), prev_hashes: [block1.hash], height: 2}
    block3 = %DataBlock{hash: Hash.hash("blockC"), prev_hashes: [block1.hash], height: 2}
    block4 = %DataBlock{hash: Hash.hash("blockD"), prev_hashes: [block2.hash, block3.hash], height: 3}

    all_blocks = [block1, block2, block3, block4]

    tips = TipSelection.select_tips(all_blocks)

    assert Enum.sort(tips) == Enum.sort([block4.hash])
  end

  test "returns empty list if no blocks are provided" do
    tips = TipSelection.select_tips([])
    assert tips == []
  end

  test "returns all blocks if none are referenced" do
    block1 = %DataBlock{hash: Hash.hash("b1"), prev_hashes: [], height: 1}
    block2 = %DataBlock{hash: Hash.hash("b2"), prev_hashes: [], height: 1}

    all_blocks = [block1, block2]

    tips = TipSelection.select_tips(all_blocks)

    assert Enum.sort(tips) == Enum.sort([block1.hash, block2.hash])
  end
end