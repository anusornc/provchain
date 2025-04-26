defmodule ProvChain.Storage.BlockStore do
  @moduledoc """
  Persistent & indexed storage for DAG blocks and transactions.

  * **dev**   – resets the local Mnesia schema on every boot for a clean workspace.
  * **test**  – resets the local Mnesia schema before each test run, ensuring isolated tables.
  * **prod**  – never resets data; only starts Mnesia if necessary.
  """

  use GenServer
  require Logger

  @blocks_table :blocks
  @transactions_table :transactions
  @height_index_table :height_index
  @type_index_table :type_index
  @timeout 5_000

  # ---------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------
  def start_link(opts), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def blocks_table, do: @blocks_table
  def transactions_table, do: @transactions_table
  def height_index_table, do: @height_index_table
  def type_index_table, do: @type_index_table

  @doc "Clears all Mnesia tables (test only)"
  def clear_tables do
    if Mix.env() == :test do
      for table <- [@blocks_table, @transactions_table, @height_index_table, @type_index_table] do
        :mnesia.clear_table(table)
      end

      :ok
    else
      raise "clear_tables is only allowed in test environment"
    end
  end

  def put_block(%ProvChain.BlockDag.Block{} = block),
    do: GenServer.call(__MODULE__, {:put_block, block}, @timeout)

  def put_block(_), do: {:error, :invalid_block}

  def get_block(hash) when is_binary(hash),
    do: GenServer.call(__MODULE__, {:get_block, hash}, @timeout)

  def put_transaction(%{"hash" => hash} = tx) when is_binary(hash),
    do: GenServer.call(__MODULE__, {:put_transaction, tx}, @timeout)

  def put_transaction(_), do: {:error, :invalid_transaction}

  def get_transaction(hash) when is_binary(hash),
    do: GenServer.call(__MODULE__, {:get_transaction, hash}, @timeout)

  def get_blocks_by_height(height) when is_integer(height),
    do: GenServer.call(__MODULE__, {:get_blocks_by_height, height}, @timeout)

  def get_blocks_by_type(type) when is_binary(type),
    do: GenServer.call(__MODULE__, {:get_blocks_by_type, type}, @timeout)

  # ---------------------------------------------------------------------
  # GenServer lifecycle
  # ---------------------------------------------------------------------
  @impl true
  def init(_opts) do
    setup_mnesia()

    case create_tables() do
      :ok ->
        Logger.info("BlockStore initialized on Mnesia node #{node()}")
        {:ok, %{}}

      {:error, reason} ->
        Logger.error("BlockStore init failed: #{inspect(reason)}")
        {:stop, reason}
    end
  end

  # ---------------------------------------------------------------------
  # GenServer callbacks – storage logic
  # ---------------------------------------------------------------------
  @impl true
  def handle_call({:put_block, %ProvChain.BlockDag.Block{} = block}, _from, state) do
    ensure_running!()

    result =
      :mnesia.transaction(fn ->
        :mnesia.write({@blocks_table, block.hash, :erlang.term_to_binary(block)})
        :mnesia.write({@height_index_table, block.height, block.hash, block.timestamp})
        :mnesia.write({@type_index_table, block.supply_chain_type, block.hash, block.timestamp})
      end)

    case result do
      {:atomic, :ok} -> {:reply, :ok, state}
      {:aborted, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:get_block, hash}, _from, state) do
    ensure_running!()

    result =
      :mnesia.transaction(fn ->
        case :mnesia.read(@blocks_table, hash) do
          [{_, ^hash, data}] -> {:ok, :erlang.binary_to_term(data)}
          _ -> {:error, :not_found}
        end
      end)

    case result do
      {:atomic, {:ok, block}} -> {:reply, {:ok, block}, state}
      {:atomic, {:error, :not_found}} -> {:reply, {:error, :not_found}, state}
      {:aborted, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:put_transaction, %{"hash" => hash} = tx}, _from, state) do
    ensure_running!()

    result =
      :mnesia.transaction(fn ->
        :mnesia.write({@transactions_table, hash, :erlang.term_to_binary(tx)})
      end)

    case result do
      {:atomic, :ok} -> {:reply, :ok, state}
      {:aborted, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:get_transaction, hash}, _from, state) do
    ensure_running!()

    result =
      :mnesia.transaction(fn ->
        case :mnesia.read(@transactions_table, hash) do
          [{_, ^hash, data}] -> {:ok, :erlang.binary_to_term(data)}
          _ -> {:error, :not_found}
        end
      end)

    case result do
      {:atomic, {:ok, tx}} -> {:reply, {:ok, tx}, state}
      {:atomic, {:error, :not_found}} -> {:reply, {:error, :not_found}, state}
      {:aborted, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:get_blocks_by_height, height}, _from, state) do
    ensure_running!()

    result =
      :mnesia.transaction(fn ->
        :mnesia.match_object({@height_index_table, height, :_, :_})
        |> Enum.map(fn {_, _, hash, _} ->
          case :mnesia.read(@blocks_table, hash) do
            [{_, ^hash, data}] -> :erlang.binary_to_term(data)
            _ -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)
      end)

    case result do
      {:atomic, blocks} -> {:reply, {:ok, blocks}, state}
      {:aborted, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:get_blocks_by_type, type}, _from, state) do
    ensure_running!()

    result =
      :mnesia.transaction(fn ->
        :mnesia.match_object({@type_index_table, type, :_, :_})
        |> Enum.map(fn {_, _, hash, _} ->
          case :mnesia.read(@blocks_table, hash) do
            [{_, ^hash, data}] -> :erlang.binary_to_term(data)
            _ -> nil
          end
        end)
        |> Enum.reject(&is_nil/1)
      end)

    case result do
      {:atomic, blocks} -> {:reply, {:ok, blocks}, state}
      {:aborted, reason} -> {:reply, {:error, reason}, state}
    end
  end

  # ---------------------------------------------------------------------
  # Helpers
  # ---------------------------------------------------------------------
  defp ensure_running! do
    case :mnesia.system_info(:is_running) do
      :yes -> :ok
      _ -> raise "Mnesia is not running"
    end
  end

  defp setup_mnesia do
    env = Mix.env()

    # กำหนด directory สำหรับ Mnesia
    dir = Application.fetch_env!(:mnesia, :dir)
    File.mkdir_p!(dir)
    :application.set_env(:mnesia, :dir, to_charlist(dir))

    case env do
      :test ->
        reset_mnesia_for_test(dir)

      :dev ->
        ensure_mnesia_schema_in_dev(dir)

      _ ->
        Logger.warning("Unsupported environment: #{env}")
    end

    # เริ่มต้น Mnesia และจัดการผลลัพธ์
    handle_mnesia_start()
  end

  # ฟังก์ชันสำหรับรีเซ็ต Mnesia ในโหมดทดสอบ
  defp reset_mnesia_for_test(dir) do
    File.rm_rf!(dir)
    File.mkdir_p!(dir)
    :mnesia.stop()
    _ = :mnesia.delete_schema([node()])
    :mnesia.create_schema([node()])
  end

  # ฟังก์ชันสำหรับตรวจสอบและสร้าง schema ในโหมดพัฒนา
  defp ensure_mnesia_schema_in_dev(dir) do
    if !File.exists?(Path.join(dir, "schema.DAT")) do
      Logger.info("Creating new Mnesia schema in dev mode")
      :mnesia.stop()
      _ = :mnesia.delete_schema([node()])
      :mnesia.create_schema([node()])
    end
  end

  # ฟังก์ชันสำหรับจัดการการเริ่มต้น Mnesia
  defp handle_mnesia_start() do
    case :mnesia.start() do
      :ok ->
        :ok

      {:error, {:already_started, _}} ->
        :ok

      err ->
        Logger.error("Mnesia failed to start: #{inspect(err)}")
        err
    end
  end

  def create_tables do
    storage = if Mix.env() == :test, do: [ram_copies: [node()]], else: [disc_copies: [node()]]

    make = fn table, opts ->
      case :mnesia.create_table(table, opts ++ storage) do
        {:atomic, :ok} -> :ok
        {:aborted, {:already_exists, _}} -> :ok
        {:aborted, reason} -> {:error, {:table_create, table, reason}}
      end
    end

    with :ok <- make.(@blocks_table, attributes: [:hash, :data], type: :set),
         :ok <- make.(@transactions_table, attributes: [:hash, :data], type: :set),
         :ok <- make.(@height_index_table, attributes: [:height, :hash, :timestamp], type: :bag),
         :ok <- make.(@type_index_table, attributes: [:type, :hash, :timestamp], type: :bag) do
      :mnesia.wait_for_tables(
        [
          @blocks_table,
          @transactions_table,
          @height_index_table,
          @type_index_table
        ],
        30_000
      )
    end
  end
end
