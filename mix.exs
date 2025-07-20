defmodule ProvChain.MixProject do
  use Mix.Project

  def project do
    [
      app: :provchain,
      version: "0.1.0",
      # Latest stable Elixir version (1.18.3 as of December 2024)
      elixir: "~> 1.18",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      elixirc_paths: elixirc_paths(Mix.env()),
      aliases: aliases(),
      test_config_path: "config/test.exs",
    ]
  end

  # Run "mix help compile.app" to learn about applications
  def application do
    [
      extra_applications: [:logger, :crypto, :mnesia],
      mod: {ProvChain.Application, []}
    ]
  end

  # Specifies which paths to compile per environment
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib", "test/support"]

  # Run "mix help deps" to learn about dependencies
  defp deps do
    [
      # Core libraries
      # Graph data structures
      {:libgraph, "~> 0.16.0"},
      # JSON encoding/decoding
      {:jason, "~> 1.4"},
      {:eddy, "~> 1.0.0"},

      {:cachex, "~> 4.0.4"},

      {:mox, "~> 1.2"},
      
      # SPARQL and RDF dependencies (from PoC)
      {:rdf, "~> 2.0"},
      {:sparql, "~> 0.3"},
      {:sparql_client, "~> 0.5"},
      {:json_ld, "~> 0.3"},
      # Development and testing
      # Code quality checks
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      # Static analysis
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      # Documentation generation
      {:ex_doc, "~> 0.30", only: :dev, runtime: false},
      {:benchee, "~> 1.0", only: :dev},
      {:benchee_html, "~> 1.0", only: :dev}
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
