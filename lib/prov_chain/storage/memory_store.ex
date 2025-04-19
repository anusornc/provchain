defmodule ProvChain.Storage.MemoryStore do
  use GenServer
  require Logger

  @block_cache :provchain_blocks_cache
  @tx_cache    :provchain_transactions_cache
  @tip_set_table :provchain_tip_set
  @default_timeout 5_000

  # GenServer start
  @doc """
  Starts the MemoryStore GenServer.
  """
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  # Public API

  @doc """
  Stores a block in the cache under the given hash.
  """
  def put_block(hash, block) when is_binary(hash) do
    if is_cache_enabled?() do
      case Cachex.put(@block_cache, hash, block) do
        {:ok, _} -> :ok
        {:error, reason} = err ->
          Logger.error("Failed to cache block #{Base.encode16(hash)}: #{inspect(reason)}")
          err
      end
    else
      :ok
    end
  end

  @doc """
  Retrieves a block from the cache by hash.
  Returns `{:ok, block}` or `{:error, :not_found}`.
  """
  def get_block(hash) when is_binary(hash) do
    if is_cache_enabled?() do
      case Cachex.get(@block_cache, hash) do
        {:ok, nil} -> {:error, :not_found}
        {:ok, block} -> {:ok, block}
        {:error, _} ->
          Logger.warning("Error retrieving block #{Base.encode16(hash)}")
          {:error, :not_found}
      end
    else
      {:error, :cache_disabled}
    end
  end

  @doc """
  Stores a transaction in the cache under the given hash.
  """
  def put_transaction(hash, tx) when is_binary(hash) do
    if is_cache_enabled?() do
      case Cachex.put(@tx_cache, hash, tx) do
        {:ok, _} -> :ok
        {:error, reason} = err ->
          Logger.error("Failed to cache transaction #{Base.encode16(hash)}: #{inspect(reason)}")
          err
      end
    else
      :ok
    end
  end

  @doc """
  Retrieves a transaction from the cache by hash.
  Returns `{:ok, tx}` or `{:error, :not_found}`.
  """
  def get_transaction(hash) when is_binary(hash) do
    if is_cache_enabled?() do
      case Cachex.get(@tx_cache, hash) do
        {:ok, nil} -> {:error, :not_found}
        {:ok, tx} -> {:ok, tx}
        {:error, _} ->
          Logger.warning("Error retrieving transaction #{Base.encode16(hash)}")
          {:error, :not_found}
      end
    else
      {:error, :cache_disabled}
    end
  end

  @doc """
  Updates the tip set in ETS to the given list of blocks.
  """
  def update_tip_set(blocks) when is_list(blocks) do
    GenServer.call(__MODULE__, {:update_tip_set, blocks}, @default_timeout)
  end

  @doc """
  Retrieves the current tip set from ETS.
  Returns the list of blocks or `[]` if table missing.
  """
  def get_tip_set do
    try do
      case :ets.lookup(@tip_set_table, :current) do
        [{:current, blks}] -> blks
        [] ->
          Logger.warning("Tip set key :current not found in ETS table #{@tip_set_table}")
          []
      end
    catch
      :error, :badarg ->
        Logger.warning("ETS table #{@tip_set_table} does not exist")
        []
    end
  end

  @doc """
  Checks if a block exists in the cache.
  """
  def has_block?(hash) when is_binary(hash) do
    if is_cache_enabled?() do
      case Cachex.exists?(@block_cache, hash) do
        {:ok, ex} -> ex
        {:error, _} ->
          Logger.warning("Error checking block existence for #{Base.encode16(hash)}")
          false
      end
    else
      false
    end
  end

  @doc """
  Checks if a transaction exists in the cache.
  """
  def has_transaction?(hash) when is_binary(hash) do
    if is_cache_enabled?() do
      case Cachex.exists?(@tx_cache, hash) do
        {:ok, ex} -> ex
        {:error, _} ->
          Logger.warning("Error checking transaction existence for #{Base.encode16(hash)}")
          false
      end
    else
      false
    end
  end

  @doc """
  Enables or disables the cache at runtime.
  """
  def set_cache_enabled(enabled) when is_boolean(enabled) do
    GenServer.call(__MODULE__, {:set_cache_enabled, enabled}, @default_timeout)
  end

  @doc """
  Returns cache statistics when enabled, or `{:error, :cache_disabled}`.
  """
  def cache_stats do
    if is_cache_enabled?() do
      cache_opts = [limit: 10_000, policy: Cachex.Policy.LRU, stats: true]
      # ensure caches are started (ignore results)
      _ = Cachex.start_link(@block_cache, cache_opts)
      _ = Cachex.start_link(@tx_cache, cache_opts)

      case {Cachex.stats(@block_cache), Cachex.stats(@tx_cache)} do
        {{:ok, b}, {:ok, t}} ->
          hits   = (b[:hits] || 0) + (t[:hits] || 0)
          misses = (b[:misses] || 0) + (t[:misses] || 0)
          total  = hits + misses
          rate   = if total > 0, do: hits / total * 100, else: 0.0

          {:ok, %{
            enabled: true,
            size: (b[:size] || 0) + (t[:size] || 0),
            hit_rate: rate,
            hit_count: hits,
            miss_count: misses,
            eviction_count: (b[:evictions] || 0) + (t[:evictions] || 0),
            blocks: b,
            transactions: t
          }}

        _ ->
          Logger.error("Failed to get cache stats.")
          {:error, :stats_unavailable}
      end
    else
      {:error, :cache_disabled}
    end
  end

  @doc """
  Clears both block and transaction caches.
  """
  def clear_cache do
    if is_cache_enabled?() do
      with {:ok, _} <- Cachex.clear(@block_cache),
           {:ok, _} <- Cachex.clear(@tx_cache) do
        Logger.info("Block and transaction caches cleared")
        :ok
      else
        {:error, reason} = err ->
          Logger.error("Failed to clear cache: #{inspect(reason)}")
          err
      end
    else
      :ok
    end
  end

  @doc """
  Clears ETS tip set table and reinitializes it.
  """
  def clear_tables do
    clear_cache()

    if :ets.whereis(@tip_set_table) != :undefined do
      :ets.delete(@tip_set_table)
    end

    :ets.new(@tip_set_table, [:named_table, :set, :public, read_concurrency: true])
    :ets.insert(@tip_set_table, {:current, []})
    Logger.info("ETS table #{@tip_set_table} cleared and reinitialized")
    :ok
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    cache_size = Keyword.get(opts, :max_cache_size, 10_000)
    ttl        = Keyword.get(opts, :ttl, nil)
    base_opts  = [limit: cache_size, policy: Cachex.Policy.LRU, stats: true]
    cache_opts = if is_integer(ttl) and ttl > 0, do: [{:ttl, ttl} | base_opts], else: base_opts

    # Start or ensure caches are running (ignore results)
    _ = Cachex.start_link(@block_cache, cache_opts)
    _ = Cachex.start_link(@tx_cache, cache_opts)
    Logger.debug("Cachex stats after init: #{inspect(Cachex.stats(@block_cache))}")

    initialize_ets_table()
    Logger.info("MemoryStore initialized with Cachex and ETS")
    {:ok, %{cache_enabled: true}}
  end

  @impl true
  def handle_call({:set_cache_enabled, enabled}, _from, state) do
    Logger.info("MemoryStore cache #{if enabled, do: "enabled", else: "disabled"}")
    {:reply, :ok, %{state | cache_enabled: enabled}}
  end

  @impl true
  def handle_call({:update_tip_set, blocks}, _from, state) do
    # ensure ETS table exists
    initialize_ets_table()
    :ets.insert(@tip_set_table, {:current, blocks})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:is_cache_enabled?, _from, state) do
    {:reply, state.cache_enabled, state}
  end

  @impl true
  def terminate(_reason, _state) do
    Cachex.clear(@block_cache)
    Cachex.clear(@tx_cache)
    Logger.info("MemoryStore terminated, cleaned up Cachex and ETS")
    :ok
  end

  # Private helpers

  defp is_cache_enabled? do
    if Process.whereis(__MODULE__) do
      try do
        case GenServer.call(__MODULE__, :is_cache_enabled?, @default_timeout) do
          bool when is_boolean(bool) -> bool
          _ -> false
        end
      catch
        _, _ ->
          Logger.warning("Failed to get cache enabled state. Assuming disabled.")
          false
      end
    else
      Logger.warning("MemoryStore process not running. Assuming cache disabled.")
      false
    end
  end

  defp initialize_ets_table do
    unless :ets.whereis(@tip_set_table) != :undefined do
      :ets.new(@tip_set_table, [:named_table, :set, :public, read_concurrency: true])
    end
    :ets.insert_new(@tip_set_table, {:current, []})
  end
end
