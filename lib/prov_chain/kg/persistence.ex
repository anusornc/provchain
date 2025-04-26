defmodule ProvChain.KG.Persistence do
  @moduledoc "Save/load the in-memory RDF.Graph to Turtle on disk."

  @ttl_path "data/graph.ttl"

  @spec save(RDF.Graph.t()) :: :ok | {:error, term()}
  def save(graph) do
    File.mkdir_p!("data")
    # write Turtle file :contentReference[oaicite:2]{index=2}
    RDF.Turtle.write_file(graph, @ttl_path)
  end

  @spec load() :: {:ok, RDF.Graph.t()} | {:error, term()}
  def load do
    if File.exists?(@ttl_path), do: RDF.Turtle.read_file(@ttl_path), else: {:error, :not_found}
  end
end
