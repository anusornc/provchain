defmodule ProvChain.Storage.MemoryStore do
  @moduledoc """
  In-memory storage implementation using ETS/DETS.

  This module provides fast access to recently used blocks and transactions
  by storing them in ETS tables, with optional persistence using DETS.
  """
  use GenServer

  # Table names as module attributes for clarity and reuse
  @block_table :provchain_blocks
  @transaction_table :provchain_transactions
  @tip_set_table :provchain_tip_set

  @doc """
  Starts the MemoryStore GenServer.
  """
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Initializes the ETS tables needed for in-memory storage.
  """
  @impl true
  def init(_) do
    # Create ETS tables for blocks, transactions, and tip set
    :ets.new(@block_table, [:named_table, :set, :public])
    :ets.new(@transaction_table, [:named_table, :set, :public])
    :ets.new(@tip_set_table, [:named_table, :set, :public])

    # Set initial tip set (empty list)
    :ets.insert(@tip_set_table, {:current, []})

    {:ok, %{}}
  end

  @doc """
  Stores a block in memory.

  ## Parameters
    - hash: The block hash used as key
    - block: The block data to store

  ## Returns
    :ok on success
  """
  def put_block(hash, block) when is_binary(hash) do
    true = :ets.insert(@block_table, {hash, block})
    :ok
  end

  @doc """
  Retrieves a block from memory.

  ## Parameters
    - hash: The block hash to look up

  ## Returns
    {:ok, block} if found, {:error, :not_found} otherwise
  """
  def get_block(hash) when is_binary(hash) do
    case :ets.lookup(@block_table, hash) do
      [{^hash, block}] -> {:ok, block}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Stores a transaction in memory.

  ## Parameters
    - hash: The transaction hash used as key
    - transaction: The transaction data to store

  ## Returns
    :ok on success
  """
  def put_transaction(hash, transaction) when is_binary(hash) do
    true = :ets.insert(@transaction_table, {hash, transaction})
    :ok
  end

  @doc """
  Retrieves a transaction from memory.

  ## Parameters
    - hash: The transaction hash to look up

  ## Returns
    {:ok, transaction} if found, {:error, :not_found} otherwise
  """
  def get_transaction(hash) when is_binary(hash) do
    case :ets.lookup(@transaction_table, hash) do
      [{^hash, transaction}] -> {:ok, transaction}
      [] -> {:error, :not_found}
    end
  end

  @doc """
  Updates the current tip set (the latest blocks in the DAG).

  ## Parameters
    - blocks: List of block hashes representing the tip set

  ## Returns
    :ok on success
  """
  def update_tip_set(blocks) when is_list(blocks) do
    true = :ets.insert(@tip_set_table, {:current, blocks})
    :ok
  end

  @doc """
  Retrieves the current tip set.

  ## Returns
    List of block hashes in the current tip set
  """
  def get_tip_set do
    case :ets.lookup(@tip_set_table, :current) do
      [{:current, blocks}] -> blocks
      [] -> []
    end
  end

  @doc """
  Checks if a block exists in memory.

  ## Parameters
    - hash: The block hash to check

  ## Returns
    true if the block exists, false otherwise
  """
  def has_block?(hash) when is_binary(hash) do
    :ets.member(@block_table, hash)
  end

  @doc """
  Checks if a transaction exists in memory.

  ## Parameters
    - hash: The transaction hash to check

  ## Returns
    true if the transaction exists, false otherwise
  """
  def has_transaction?(hash) when is_binary(hash) do
    :ets.member(@transaction_table, hash)
  end
end
