# test/kg/builder_test.exs
defmodule ProvChain.KG.BuilderTest do
  use ExUnit.Case, async: true

  alias ProvChain.KG.Builder
  alias ProvChain.Test.ProvOData
  import RDF.Sigils

  @sparql """
  PREFIX prov: <http://www.w3.org/ns/prov#>
  SELECT ?s WHERE {
    ?s a prov:Entity .
  }
  """

  test "build_graph/1 returns a graph containing the entity as prov:Entity" do
    tx = ProvOData.milk_collection_transaction()
    graph = Builder.build_graph(tx)

    # Ensure the graph has the correct prefixes for SPARQL
    graph_with_prefixes = RDF.Graph.add_prefixes(graph, %{prov: ProvChain.Ontology.NS.PROV, rdf: RDF.NS.RDF})

    IO.inspect(RDF.Graph.triples(graph_with_prefixes), label: "Graph Triples")

    # Run the SPARQL query against the in-memory graph
    {:ok, result} = ProvChain.SPARQL.Engine.query(@sparql, graph_with_prefixes)

    # We expect exactly one result, whose ?s is the IRI ~i<prov:#{id}>
    [%{"s" => subject}] = result.results
    assert subject == ~i<prov:#{tx["prov:entity"]["id"]}>
  end
end
