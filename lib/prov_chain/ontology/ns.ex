# lib/prov_chain/ontology/ns.ex
defmodule ProvChain.Ontology.NS do
  use RDF.Vocabulary.Namespace

  # You must provide at least one of :file, :data or :terms.
  # Here we give an empty terms list so that dynamic resolution (strict: false)
  # will allow all PROV terms at runtime.
  defvocab PROV,
    base_iri: "http://www.w3.org/ns/prov#",
    strict: false,
    terms: []
end
