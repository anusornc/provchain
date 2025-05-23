defmodule ProvChain.SPARQL.MinimalTest do
  use ExUnit.Case, async: true

  alias RDF.Graph
  alias ProvChain.SPARQL.Engine

  test "minimal SPARQL execution via Engine" do
    # Create a simple RDF graph with one entity
    graph =
      Graph.new([{RDF.iri("http://example.com/entity1"), RDF.type, RDF.iri("http://www.w3.org/ns/prov#Entity")}],
        prefixes: %{prov: ProvChain.Ontology.NS.PROV, rdf: RDF.NS.RDF})

    # Define a basic SPARQL query to select entities
    query_string = """
      PREFIX prov: <http://www.w3.org/ns/prov#>
      SELECT ?s WHERE { ?s a prov:Entity . }
    """

    # Execute the query using the Engine
    result = Engine.query(query_string, graph)

    # Assert that the query executed successfully and returned the expected result
    assert {:ok, %SPARQL.Query.Result{results: [%{"s" => entity}]}} = result
    assert entity == RDF.iri("http://example.com/entity1")
  end
end
