defmodule ProvChain.Storage.MemoryStore do
  use GenServer
  require Logger

  @block_cache :provchain_blocks_cache
  @tx_cache :provchain_transactions_cache
  @tip_set_table :provchain_tip_set
  @default_timeout 5_000

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def put_block(hash, block) when is_binary(hash) do
    if is_cache_enabled?() do
      case Cachex.put(@block_cache, hash, block) do
        {:ok, _} -> :ok
        {:error, reason} = error ->
          Logger.error("Failed to cache block #{Base.encode16(hash)}: #{inspect(reason)}")
          error
      end
    else
      :ok
    end
  end

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

  def put_transaction(hash, transaction) when is_binary(hash) do
    if is_cache_enabled?() do
      case Cachex.put(@tx_cache, hash, transaction) do
        {:ok, _} -> :ok
        {:error, reason} = error ->
          Logger.error("Failed to cache transaction #{Base.encode16(hash)}: #{inspect(reason)}")
          error
      end
    else
      :ok
    end
  end

  def get_transaction(hash) when is_binary(hash) do
    if is_cache_enabled?() do
      case Cachex.get(@tx_cache, hash) do
        {:ok, nil} -> {:error, :not_found}
        {:ok, transaction} -> {:ok, transaction}
        {:error, _} ->
          Logger.warning("Error retrieving transaction #{Base.encode16(hash)}")
          {:error, :not_found}
      end
    else
      {:error, :cache_disabled}
    end
  end

  def update_tip_set(blocks) when is_list(blocks) do
    GenServer.call(__MODULE__, {:update_tip_set, blocks}, @default_timeout)
  end

  def get_tip_set do
    try do
      case :ets.lookup(@tip_set_table, :current) do
        [{:current, blocks}] -> blocks
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

  def has_block?(hash) when is_binary(hash) do
    if is_cache_enabled?() do
      case Cachex.exists?(@block_cache, hash) do
        {:ok, exists} -> exists
        {:error, _} ->
          Logger.warning("Error checking block existence for #{Base.encode16(hash)}")
          false
      end
    else
      false
    end
  end

  def has_transaction?(hash) when is_binary(hash) do
    if is_cache_enabled?() do
      case Cachex.exists?(@tx_cache, hash) do
        {:ok, exists} -> exists
        {:error, _} ->
          Logger.warning("Error checking transaction existence for #{Base.encode16(hash)}")
          false
      end
    else
      false
    end
  end

  def set_cache_enabled(enabled) when is_boolean(enabled) do
    GenServer.call(__MODULE__, {:set_cache_enabled, enabled}, @default_timeout)
  end

  def cache_stats do
    if is_cache_enabled?() do
      case {Cachex.stats(@block_cache), Cachex.stats(@tx_cache)} do
        {{:ok, block_stats}, {:ok, tx_stats}} ->
          hits = (block_stats[:hits] || 0) + (tx_stats[:hits] || 0)
          misses = (block_stats[:misses] || 0) + (tx_stats[:misses] || 0)
          total = hits + misses
          hit_rate = if total > 0, do: hits / total * 100, else: 0.0

          stats = %{
            enabled: true,
            size: (block_stats[:size] || 0) + (tx_stats[:size] || 0),
            hit_rate: hit_rate,
            hit_count: hits,
            miss_count: misses,
            eviction_count: (block_stats[:evictions] || 0) + (tx_stats[:evictions] || 0),
            blocks: block_stats,
            transactions: tx_stats
          }
          {:ok, stats}

        {block_result, tx_result} ->
          Logger.error("""
          Failed to get cache stats.
          Block cache result: #{inspect(block_result)}
          Transaction cache result: #{inspect(tx_result)}
          """)
          {:error, :stats_unavailable}
      end
    else
      {:error, :cache_disabled}
    end
  end

  def clear_cache do
    if is_cache_enabled?() do
      with {:ok, _} <- Cachex.clear(@block_cache),
           {:ok, _} <- Cachex.clear(@tx_cache) do
        Logger.info("Block and transaction caches cleared")
        :ok
      else
        {:error, reason} = error ->
          Logger.error("Failed to clear cache: #{inspect(reason)}")
          error
      end
    else
      :ok
    end
  end

  @impl true
  def init(opts) do
    cache_size = Keyword.get(opts, :max_cache_size, 10_000)
    ttl = Keyword.get(opts, :ttl, nil)
    cache_opts = [limit: cache_size, policy: Cachex.Policy.LRU, stats: true]
    cache_opts = if is_integer(ttl) and ttl > 0, do: [{:ttl, ttl} | cache_opts], else: cache_opts

    block_cache_result = Cachex.start_link(@block_cache, cache_opts)
    tx_cache_result = Cachex.start_link(@tx_cache, cache_opts)

    case {block_cache_result, tx_cache_result} do
      {{:ok, _}, {:ok, _}} ->
        Logger.info("Started block and transaction caches with size: #{cache_size}")
        initialize_ets_table()
        Logger.info("MemoryStore initialized with Cachex and ETS")
        {:ok, %{cache_enabled: true}}

      {{:ok, _}, {:error, {:already_started, pid}}} ->
        Logger.warning("Transaction cache already started with pid #{inspect(pid)}")
        initialize_ets_table()
        Logger.info("MemoryStore initialized with Cachex and ETS")
        {:ok, %{cache_enabled: true}}

      {{:error, {:already_started, pid}}, {:ok, _}} ->
        Logger.warning("Block cache already started with pid #{inspect(pid)}")
        initialize_ets_table()
        Logger.info("MemoryStore initialized with Cachex and ETS")
        {:ok, %{cache_enabled: true}}

      {{:error, {:already_started, pid1}}, {:error, {:already_started, pid2}}} ->
        Logger.warning("Block cache already started with pid #{inspect(pid1)}")
        Logger.warning("Transaction cache already started with pid #{inspect(pid2)}")
        initialize_ets_table()
        Logger.info("MemoryStore initialized with Cachex and ETS")
        {:ok, %{cache_enabled: true}}

      {{:error, reason}, _} ->
        Logger.error("Failed to initialize MemoryStore: block cache error #{inspect(reason)}")
        {:stop, {:cache_init_failed, reason}}

      {_, {:error, reason}} ->
        Logger.error("Failed to initialize MemoryStore: transaction cache error #{inspect(reason)}")
        {:stop, {:cache_init_failed, reason}}
    end
  end

  @impl true
  def handle_call({:set_cache_enabled, enabled}, _from, state) do
    Logger.info("MemoryStore cache #{if enabled, do: "enabled", else: "disabled"}")
    {:reply, :ok, %{state | cache_enabled: enabled}}
  end

  @impl true
  def handle_call({:update_tip_set, blocks}, _from, state) do
    :ets.insert(@tip_set_table, {:current, blocks})
    {:reply, :ok, state}
  end

  @impl true
  def handle_call(:is_cache_enabled?, _from, state) do
    {:reply, {:ok, state.cache_enabled}, state}
  end

  @impl true
  def terminate(_reason, _state) do
    Cachex.clear(@block_cache)
    Cachex.clear(@tx_cache)
    if :ets.whereis(@tip_set_table) != :undefined do
      :ets.delete(@tip_set_table)
    end
    Logger.info("MemoryStore terminated, cleaned up Cachex and ETS")
    :ok
  end

  defp is_cache_enabled? do
    try do
      case GenServer.call(__MODULE__, :is_cache_enabled?, @default_timeout) do
        {:ok, bool} when is_boolean(bool) -> bool
        _ -> false
      end
    catch
      _ ->
        Logger.warning("Failed to get cache enabled state. Assuming disabled.")
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
