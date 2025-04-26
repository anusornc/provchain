# lib/prov_chain/sparql/engine.ex

defmodule ProvChain.SPARQL.Engine do
  @moduledoc """
  Minimal SPARQL engine for ProvChain: only supports
  `SELECT ?s WHERE { ?s a prov:Entity }` queries on an RDF.Graph.
  """

  import RDF.Sigils, only: [sigil_I: 2]
  alias RDF.Graph
  alias SPARQL.Query
  alias SPARQL.Query.Result

  @doc "Executes a minimal SPARQL SELECT query, returning all `?s a prov:Entity` subjects."
  @spec query(String.t() | SPARQL.Query.t(), RDF.Graph.t()) :: {:ok, %SPARQL.Query.Result{variables: [String.t()], results: [%{String.t() => any()}]}}
  def query(query_string, %Graph{} = graph) when is_binary(query_string) do
    type_pred  = ~I<rdf:type>
    entity_obj = ~I<prov:Entity>

    results =
      graph
      |> Graph.triples()
      |> Enum.filter(fn {_, ^type_pred, ^entity_obj} -> true; _ -> false end)
      |> Enum.map(fn {s, _, _} -> %{"s" => s} end)

    {:ok, %Result{variables: ["s"], results: results}}
  end

  def query(%Query{} = q, %Graph{} = graph) do
    query(to_string(q), graph)
  end
end
