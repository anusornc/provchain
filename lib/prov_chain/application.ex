defmodule ProvChain.Application do
  @moduledoc """
  The ProvChain Application Service.

  The provchain application provides a permissioned blockchain for supply chain tracking.
  This module defines the application callback required to start the supervision tree.
  """

  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    Logger.info("Starting MemoryStore in ProvChain.Application")

    children = [
      {ProvChain.Storage.BlockStore, []},
      {ProvChain.Storage.MemoryStore, []}
    ]

    opts = [strategy: :one_for_one, name: ProvChain.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
