defmodule ProvChain.Storage.BlockStore do
  use GenServer
  require Logger

  @blocks_table :blocks
  @transactions_table :transactions
  @height_index_table :height_index
  @type_index_table :type_index

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    dag_path = Application.get_env(:provchain, :dag_storage_path)
    File.mkdir_p!(dag_path)
    :application.set_env(:mnesia, :dir, to_charlist(dag_path))

    unless Mix.env() == :test do
      if node() == :nonode@nohost do
        raise "Mnesia requires a named node for disc_copies. Run with --name or --sname"
      end
    end

    case :mnesia.system_info(:is_running) do
      :yes ->
        Logger.info("Stopping Mnesia to reconfigure...")
        case :mnesia.stop() do
          :stopped -> :timer.sleep(1000)
          error -> Logger.error("Failed to stop Mnesia: #{inspect(error)}"); raise "Mnesia stop failed"
        end
      _ ->
        :ok
    end

    with :ok <- create_schema([node()], dag_path),
         :ok <- start_mnesia(),
         :ok <- :mnesia.wait_for_tables([:schema], 5000),
         :ok <- create_tables() do
      {:ok, %{}}
    else
      {:error, reason} ->
        Logger.error("Failed to initialize BlockStore: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  defp create_schema(nodes, dag_path) do
    case :mnesia.create_schema(nodes) do
      :ok ->
        Logger.info("Created new Mnesia schema at #{dag_path}")
        :ok
      {:error, {_, {:already_exists, _}}} ->
        Logger.info("Using existing Mnesia schema at #{dag_path}")
        :ok
      {:error, reason} ->
        Logger.error("Schema creation failed: #{inspect(reason)}")
        {:error, {:schema_creation_failed, reason}}
    end
  end

  defp start_mnesia do
    case :mnesia.start() do
      :ok ->
        Logger.info("Mnesia started successfully")
        :ok
      error ->
        Logger.error("Failed to start Mnesia: #{inspect(error)}")
        {:error, {:mnesia_start_failed, error}}
    end
  end

  def clear_tables do
    if Mix.env() == :test do
      :mnesia.clear_table(@blocks_table)
      :mnesia.clear_table(@transactions_table)
      :mnesia.clear_table(@height_index_table)
      :mnesia.clear_table(@type_index_table)
    else
      raise "Not allowed in non-test environments"
    end
  end

  def delete_schema do
    if Mix.env() == :test do
      dag_path = Application.get_env(:provchain, :dag_storage_path)
      :mnesia.stop()
      :mnesia.delete_schema([node()])
      :application.set_env(:mnesia, :dir, to_charlist(dag_path))
      :mnesia.create_schema([node()])
      :mnesia.start()
      :timer.sleep(100)
      create_tables()
      :ok
    else
      raise "Not allowed in non-test environments"
    end
  end

  def put_block(block) do
    GenServer.call(__MODULE__, {:put_block, block})
  end

  def get_block(hash) when is_binary(hash) do
    GenServer.call(__MODULE__, {:get_block, hash})
  end

  def put_transaction(transaction) do
    GenServer.call(__MODULE__, {:put_transaction, transaction})
  end

  def get_transaction(hash) when is_binary(hash) do
    GenServer.call(__MODULE__, {:get_transaction, hash})
  end

  def get_blocks_by_height(height) when is_integer(height) do
    GenServer.call(__MODULE__, {:get_blocks_by_height, height})
  end

  def get_blocks_by_type(type) when is_binary(type) do
    GenServer.call(__MODULE__, {:get_blocks_by_type, type})
  end

  def blocks_table, do: @blocks_table
  def transactions_table, do: @transactions_table
  def height_index_table, do: @height_index_table
  def type_index_table, do: @type_index_table

  @impl true
  def handle_call({:put_block, block}, _from, state) do
    case :mnesia.system_info(:is_running) do
      :yes ->
        block_map = %{
          "hash" => block.hash,
          "prev_hashes" => block.prev_hashes,
          "timestamp" => block.timestamp,
          "height" => block.height,
          "validator" => block.validator,
          "signature" => block.signature,
          "transactions" => block.transactions,
          "merkle_root" => block.merkle_root,
          "supply_chain_type" => block.supply_chain_type,
          "dag_weight" => block.dag_weight,
          "metadata" => block.metadata
        }
        Logger.debug("Storing block_map: #{inspect(block_map)}")
        serialized_block = ProvChain.Utils.Serialization.encode(block_map)

        transaction_fn = fn ->
          :mnesia.write({@blocks_table, block.hash, serialized_block})
          :mnesia.write({@height_index_table, block.height, block.hash, block.timestamp})
          :mnesia.write({@type_index_table, block.supply_chain_type, block.hash, block.timestamp})
        end

        case :mnesia.transaction(transaction_fn) do
          {:atomic, :ok} -> {:reply, :ok, state}
          {:aborted, reason} ->
            Logger.error("Failed to put block: #{inspect(reason)}")
            {:reply, {:error, reason}, state}
        end
      :no ->
        Logger.error("Mnesia is not running, cannot put block")
        {:reply, {:error, :mnesia_not_running}, state}
    end
  end

  @impl true
  def handle_call({:get_block, hash}, _from, state) do
    result =
      :mnesia.transaction(fn ->
        case :mnesia.read(@blocks_table, hash) do
          [{@blocks_table, ^hash, serialized_block}] -> serialized_block
          [] -> nil
        end
      end)

    case result do
      {:atomic, nil} ->
        {:reply, {:error, :not_found}, state}
      {:atomic, serialized_block} ->
        case ProvChain.Utils.Serialization.decode(serialized_block) do
          {:ok, block_map} ->
            Logger.debug("Deserialized block_map: #{inspect(block_map)}")
            block = %ProvChain.BlockDag.Block{
              hash: block_map["hash"],
              prev_hashes: block_map["prev_hashes"],
              timestamp: block_map["timestamp"],
              height: block_map["height"],
              validator: block_map["validator"],
              signature: block_map["signature"],
              transactions: block_map["transactions"],
              merkle_root: block_map["merkle_root"],
              supply_chain_type: block_map["supply_chain_type"],
              dag_weight: block_map["dag_weight"],
              metadata: block_map["metadata"]
            }
            {:reply, {:ok, block}, state}
          {:error, reason} ->
            Logger.error("Failed to deserialize block: #{inspect(reason)}")
            {:reply, {:error, reason}, state}
        end
      {:aborted, reason} ->
        Logger.error("Mnesia transaction aborted: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:put_transaction, transaction}, _from, state) do
    hash = transaction["hash"] || raise ArgumentError, "Transaction must have a hash"
    case :mnesia.system_info(:is_running) do
      :yes ->
        serialized_tx = ProvChain.Utils.Serialization.encode(transaction)
        result =
          :mnesia.transaction(fn ->
            :mnesia.write({@transactions_table, hash, serialized_tx})
          end)
        case result do
          {:atomic, :ok} -> {:reply, :ok, state}
          {:aborted, reason} ->
            Logger.error("Failed to put transaction: #{inspect(reason)}")
            {:reply, {:error, reason}, state}
        end
      :no ->
        Logger.error("Mnesia is not running, cannot put transaction")
        {:reply, {:error, :mnesia_not_running}, state}
    end
  end

  @impl true
  def handle_call({:get_transaction, hash}, _from, state) do
    result =
      :mnesia.transaction(fn ->
        case :mnesia.read(@transactions_table, hash) do
          [{@transactions_table, ^hash, serialized_tx}] -> serialized_tx
          [] -> nil
        end
      end)
    case result do
      {:atomic, nil} ->
        {:reply, {:error, :not_found}, state}
      {:atomic, serialized_tx} ->
        case ProvChain.Utils.Serialization.decode(serialized_tx) do
          {:ok, tx} -> {:reply, {:ok, tx}, state}
          {:error, reason} ->
            Logger.error("Failed to deserialize transaction: #{inspect(reason)}")
            {:reply, {:error, reason}, state}
        end
      {:aborted, reason} ->
        Logger.error("Mnesia transaction aborted: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:get_blocks_by_height, height}, _from, state) do
    result =
      :mnesia.transaction(fn ->
        block_records = :mnesia.match_object({@height_index_table, height, :_, :_})
        block_hashes = Enum.map(block_records, fn {_, _, hash, _} -> hash end)
        Enum.map(block_hashes, fn hash ->
          case :mnesia.read(@blocks_table, hash) do
            [{@blocks_table, ^hash, serialized_block}] ->
              case ProvChain.Utils.Serialization.decode(serialized_block) do
                {:ok, block_map} ->
                  %ProvChain.BlockDag.Block{
                    hash: block_map["hash"],
                    prev_hashes: block_map["prev_hashes"],
                    timestamp: block_map["timestamp"],
                    height: block_map["height"],
                    validator: block_map["validator"],
                    signature: block_map["signature"],
                    transactions: block_map["transactions"],
                    merkle_root: block_map["merkle_root"],
                    supply_chain_type: block_map["supply_chain_type"],
                    dag_weight: block_map["dag_weight"],
                    metadata: block_map["metadata"]
                  }
                _ -> nil
              end
            [] -> nil
          end
        end)
        |> Enum.filter(&(&1 != nil))
      end)
    case result do
      {:atomic, blocks} -> {:reply, {:ok, blocks}, state}
      {:aborted, reason} ->
        Logger.error("Mnesia transaction aborted: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  @impl true
  def handle_call({:get_blocks_by_type, type}, _from, state) do
    result =
      :mnesia.transaction(fn ->
        block_records = :mnesia.match_object({@type_index_table, type, :_, :_})
        block_hashes = Enum.map(block_records, fn {_, _, hash, _} -> hash end)
        Enum.map(block_hashes, fn hash ->
          case :mnesia.read(@blocks_table, hash) do
            [{@blocks_table, ^hash, serialized_block}] ->
              case ProvChain.Utils.Serialization.decode(serialized_block) do
                {:ok, block_map} ->
                  %ProvChain.BlockDag.Block{
                    hash: block_map["hash"],
                    prev_hashes: block_map["prev_hashes"],
                    timestamp: block_map["timestamp"],
                    height: block_map["height"],
                    validator: block_map["validator"],
                    signature: block_map["signature"],
                    transactions: block_map["transactions"],
                    merkle_root: block_map["merkle_root"],
                    supply_chain_type: block_map["supply_chain_type"],
                    dag_weight: block_map["dag_weight"],
                    metadata: block_map["metadata"]
                  }
                _ -> nil
              end
            [] -> nil
          end
        end)
        |> Enum.filter(&(&1 != nil))
      end)
    case result do
      {:atomic, blocks} -> {:reply, {:ok, blocks}, state}
      {:aborted, reason} ->
        Logger.error("Mnesia transaction aborted: #{inspect(reason)}")
        {:reply, {:error, reason}, state}
    end
  end

  defp create_tables do
    create_table_if_needed = fn table, attrs ->
      case :mnesia.create_table(table, attrs) do
        {:atomic, :ok} ->
          Logger.info("Table #{table} created successfully")
          :ok
        {:aborted, {:already_exists, ^table}} ->
          Logger.info("Table #{table} already exists")
          :ok
        {:aborted, reason} ->
          Logger.error("Error creating Mnesia table #{table}: #{inspect(reason)}")
          {:error, {:table_creation_failed, table, reason}}
      end
    end
    storage_type = if Mix.env() == :test, do: [ram_copies: [node()]], else: [disc_copies: [node()]]
    with :ok <- create_table_if_needed.(@blocks_table, [attributes: [:hash, :data], type: :set] ++ storage_type),
         :ok <- create_table_if_needed.(@transactions_table, [attributes: [:hash, :data], type: :set] ++ storage_type),
         :ok <- create_table_if_needed.(@height_index_table, [attributes: [:height, :hash, :timestamp], type: :bag] ++ storage_type),
         :ok <- create_table_if_needed.(@type_index_table, [attributes: [:type, :hash, :timestamp], type: :bag] ++ storage_type) do
      :ok
    else
      {:error, reason} -> {:error, reason}
    end
  end
end
