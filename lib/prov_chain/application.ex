defmodule ProvChain.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Starts a worker by calling: ProvChain.Worker.start_link(arg)
      # {ProvChain.Worker, arg}
      {ProvChain.Storage.BlockStore, []},   # Block storage
      {ProvChain.Storage.MemoryStore, []}   # Memory storage
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: ProvChain.Supervisor, max_restarts: 5, max_seconds: 10]
    # The :one_for_one strategy means that if a child process terminates,
    Supervisor.start_link(children, opts)
  end
end
