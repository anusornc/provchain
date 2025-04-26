# lib/prov_chain/ontology/ns.ex
defmodule ProvChain.Ontology.NS do
  @moduledoc """
  Namespace module for PROV ontology terms used in ProvChain.

  This module defines the PROV vocabulary namespace with a base IRI of
  "http://www.w3.org/ns/prov#" for use with RDF.ex. It uses non-strict term 
  resolution to allow dynamic access to all PROV terms at runtime without 
  having to explicitly enumerate them all.
  """
  use RDF.Vocabulary.Namespace

  # You must provide at least one of :file, :data or :terms.
  # Here we give an empty terms list so that dynamic resolution (strict: false)
  # will allow all PROV terms at runtime.
  defvocab(PROV,
    base_iri: "http://www.w3.org/ns/prov#",
    strict: false,
    terms: []
  )
end
