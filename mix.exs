defmodule ProvChain.MixProject do
  use Mix.Project

  def project do
    [
      app: :provchain,
      version: "0.1.0",
      elixir: "~> 1.18",  # Latest stable Elixir version (1.18.3 as of December 2024)
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications
  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {ProvChain.Application, []}
    ]
  end

  # Specifies which paths to compile per environment
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies
  defp deps do
    [
      # Core libraries
      {:libgraph, "~> 0.16.0"},           # Graph data structures
      {:jason, "~> 1.4"},                 # JSON encoding/decoding

      # Development and testing
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false}, # Code quality checks
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}, # Static analysis
      {:ex_doc, "~> 0.30", only: :dev, runtime: false}         # Documentation generation
    ]
  end

  defp aliases do
    [
      setup: ["deps.get", "compile"],
      check: [
        "clean",
        "deps.unlock --check-unused",
        "format --check-formatted",
        "credo",
        "dialyzer"
      ]
    ]
  end
end
