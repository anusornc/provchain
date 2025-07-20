defmodule ProvChain.Storage.MemoryStore do
  use GenServer
  require Logger
  import Cachex.Spec

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
        {:error, reason} ->
          Logger.warning("Error retrieving block #{Base.encode16(hash)}: #{inspect(reason)}")
          {:error, :not_found}
      end
    else
      {:error, :cache_disabled}
    end
  end

  @doc """
  Retrieves the height of a block from the cache by hash.
  Returns the height or `0` if not found or cache disabled.
  """
  def get_block_height(hash) when is_binary(hash) do
    case get_block(hash) do
      {:ok, block} -> block.height
      _ -> 0
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
        {:error, reason} ->
          Logger.warning("Error retrieving transaction #{Base.encode16(hash)}: #{inspect(reason)}")
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
    # Ensure table exists before lookup
    initialize_ets_table()
    case :ets.lookup(@tip_set_table, :current) do
      [{:current, blks}] -> blks
      [] ->
        Logger.debug("Tip set key :current not found in ETS table #{@tip_set_table}, reinitializing")
        initialize_ets_table()
        []
    end
  end

  @doc """
  Sets the tip set in ETS to the given list of hashes.
  """
  def set_tips(tip_hashes) when is_list(tip_hashes) do
    GenServer.call(__MODULE__, {:set_tips, tip_hashes}, @default_timeout)
  end

  @doc """
  Checks if a block exists in the cache.
  """
  def has_block?(hash) when is_binary(hash) do
    if is_cache_enabled?() do
      case Cachex.exists?(@block_cache, hash) do
        {:ok, ex} -> ex
        {:error, reason} ->
          Logger.warning("Error checking block existence for #{Base.encode16(hash)}: #{inspect(reason)}")
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
        {:error, reason} ->
          Logger.warning("Error checking transaction existence for #{Base.encode16(hash)}: #{inspect(reason)}")
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

        {{:error, reason}, _} ->
          Logger.error("Failed to get block cache stats: #{inspect(reason)}")
          {:error, :stats_unavailable}
        {_, {:error, reason}} ->
          Logger.error("Failed to get transaction cache stats: #{inspect(reason)}")
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
      Logger.info("Deleted ETS table #{@tip_set_table}")
    end
    initialize_ets_table()
    Logger.info("ETS table #{@tip_set_table} reinitialized")
    :ok
  end

  # GenServer callbacks

  @impl true
  def init(opts) do
    cache_size = Keyword.get(opts, :max_cache_size, 10_000)
    ttl        = Keyword.get(opts, :ttl, nil)
    base_opts  = [limit: cache_size, policy: Cachex.Policy.LRU, stats: true, hooks: [hook(module: Cachex.Stats)]]
    cache_opts = if is_integer(ttl) and ttl > 0, do: [{:ttl, ttl} | base_opts], else: base_opts

    # Log cache options for debugging
    Logger.debug("Cachex options for block cache: #{inspect(cache_opts)}")
    Logger.debug("Cachex options for transaction cache: #{inspect(cache_opts)}")

    # Start caches with diagnostics
    try do
      {:ok, _} = Cachex.start_link(@block_cache, cache_opts)
      Logger.info("Block cache started successfully")
    catch
      :error, reason ->
        Logger.error("Failed to start block cache: #{inspect(reason)}")
    end
    try do
      {:ok, _} = Cachex.start_link(@tx_cache, cache_opts)
      Logger.info("Transaction cache started successfully")
    catch
      :error, reason ->
        Logger.error("Failed to start transaction cache: #{inspect(reason)}")
    end

    # Verify stats are enabled
    case Cachex.stats(@block_cache) do
      {:ok, stats} ->
        Logger.debug("Block cache stats enabled: #{inspect(stats)}")
      {:error, reason} ->
        Logger.error("Block cache stats disabled: #{inspect(reason)}")
    end
    case Cachex.stats(@tx_cache) do
      {:ok, stats} ->
        Logger.debug("Transaction cache stats enabled: #{inspect(stats)}")
      {:error, reason} ->
        Logger.error("Transaction cache stats disabled: #{inspect(reason)}")
    end

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
    # Ensure ETS table exists
    initialize_ets_table()
    :ets.insert(@tip_set_table, {:current, blocks})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call({:set_tips, tip_hashes}, _from, state) do
    initialize_ets_table()
    :ets.insert(@tip_set_table, {:current, tip_hashes})
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
        _, reason ->
          Logger.warning("Failed to get cache enabled state: #{inspect(reason)}. Assuming disabled.")
          false
      end
    else
      Logger.warning("MemoryStore process not running. Assuming cache disabled.")
      false
    end
  end

  defp initialize_ets_table do
    if :ets.whereis(@tip_set_table) == :undefined do
      :ets.new(@tip_set_table, [:named_table, :set, :public, read_concurrency: true])
      Logger.info("Created ETS table #{@tip_set_table}")
    else
      Logger.debug("ETS table #{@tip_set_table} already exists")
    end
    unless :ets.lookup(@tip_set_table, :current) != [] do
      :ets.insert(@tip_set_table, {:current, []})
      Logger.debug("Initialized ETS table #{@tip_set_table} with default tip set")
    end
  end
end
