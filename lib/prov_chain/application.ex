defmodule ProvChain.Application do
  @moduledoc """
  Main application module for ProvChain that manages the application lifecycle.

  This module is responsible for:
  - Starting and supervising the application components
  - Ensuring Mnesia database is properly initialized
  - Handling application shutdown
  - Managing application state during testing vs production environments
  """
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    ensure_mnesia_ready()
    Logger.info("Starting ProvChain Application")

    children =
      if Mix.env() == :test do
        [{ProvChain.Storage.MemoryStore, []}]
      else
        [
          {ProvChain.Storage.BlockStore, []},
          {ProvChain.Storage.MemoryStore, []},
          {ProvChain.KG.Store, []}
        ]
      end

    opts = [strategy: :one_for_one, name: ProvChain.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def stop(_state) do
    case :mnesia.system_info(:is_running) do
      :yes ->
        Logger.info("Stopping Mnesia safely")
        :mnesia.stop()
        Process.sleep(1000)

      _ ->
        :ok
    end

    :ok
  end

  defp ensure_mnesia_ready do
    mnesia_dir = Application.get_env(:mnesia, :dir) |> to_string()
    Logger.info("Preparing Mnesia in #{mnesia_dir}")
    File.mkdir_p!(mnesia_dir)

    case :mnesia.start() do
      :ok ->
        Logger.info("Mnesia started successfully")
        ProvChain.Helpers.MnesiaHelper.check_and_repair()

      {:error, {:already_started, _}} ->
        Logger.info("Mnesia already running")
        ProvChain.Helpers.MnesiaHelper.check_and_repair()

      {:error, reason} ->
        Logger.error("Failed to start Mnesia: #{inspect(reason)}")
        Logger.warning("Attempting to recreate schema")
        :mnesia.stop()
        :mnesia.delete_schema([node()])
        :mnesia.create_schema([node()])
        :mnesia.start()
    end
  end
end
