# lib/prov_chain/kg/builder.ex

defmodule ProvChain.KG.Builder do
  @moduledoc """
  Build an in-memory RDF.Graph representation of a PROV-O transaction.

  Expects a map with keys:
    - "prov:entity"    ⇒ %{"id" => id, "attributes" => attrs}
    - "prov:activity"  ⇒ %{"id" => id}
    - "prov:agent"     ⇒ %{"id" => id}
    - "prov:relations" ⇒ %{rel_name => %{"id" => rid, "activity" => aid, "entity" => eid, "agent" => agid}}
  """

  alias RDF.Graph
  import RDF.Sigils, only: [sigil_I: 2, sigil_i: 2]

  @prefixes %{
    prov: ProvChain.Ontology.NS.PROV,
    rdf: RDF.NS.RDF
  }

  @doc "Return the namespace prefixes map."
  @spec prefixes() :: map()
  def prefixes, do: @prefixes

  @doc "Build an RDF.Graph from a PROV-O transaction map."
  @spec build_graph(map()) :: RDF.Graph.t()
  def build_graph(%{
        "prov:entity" => entity,
        "prov:activity" => activity,
        "prov:agent" => agent,
        "prov:relations" => relations
      }) do
    Graph.new([], prefixes: @prefixes)
    |> add_entity(entity)
    |> add_activity(activity)
    |> add_agent(agent)
    |> add_relations(relations)
  end

  # -- Private helpers --

  defp prov_iri(id), do: ~i<prov:#{id}>

  defp add_entity(graph, %{"id" => id, "type" => type, "attributes" => attrs}) do
    subj = prov_iri(id)
    type_iri = case type do
      "prov:Entity" -> ProvChain.Ontology.NS.PROV.Entity
      "prov:Activity" -> ProvChain.Ontology.NS.PROV.Activity
      "prov:Agent" -> ProvChain.Ontology.NS.PROV.Agent
      _ -> ~i<prov:#{type}>
    end
    graph
    |> Graph.add({subj, RDF.type, type_iri})
    |> add_attributes(subj, attrs)
    |> maybe_add_custom_type(subj, attrs)
  end

  defp add_activity(graph, %{"id" => id, "type" => type, "attributes" => attrs}) do
    subj = prov_iri(id)
    type_iri = case type do
      "prov:Entity" -> ProvChain.Ontology.NS.PROV.Entity
      "prov:Activity" -> ProvChain.Ontology.NS.PROV.Activity
      "prov:Agent" -> ProvChain.Ontology.NS.PROV.Agent
      _ -> ~i<prov:#{type}>
    end
    graph
    |> Graph.add({subj, RDF.type, type_iri})
    |> add_attributes(subj, attrs)
    |> maybe_add_custom_type(subj, attrs)
  end

  defp add_agent(graph, %{"id" => id, "type" => type, "attributes" => attrs}) do
    subj = prov_iri(id)
    type_iri = case type do
      "prov:Entity" -> ProvChain.Ontology.NS.PROV.Entity
      "prov:Activity" -> ProvChain.Ontology.NS.PROV.Activity
      "prov:Agent" -> ProvChain.Ontology.NS.PROV.Agent
      _ -> ~i<prov:#{type}>
    end
    graph
    |> Graph.add({subj, RDF.type, type_iri})
    |> add_attributes(subj, attrs)
    |> maybe_add_custom_type(subj, attrs)
  end

  defp maybe_add_custom_type(graph, subj, attrs) do
    case attrs do
      %{"prov:type" => custom_type} when is_binary(custom_type) ->
        Graph.add(graph, {subj, RDF.type, RDF.iri("http://www.w3.org/ns/prov##{custom_type}")})
      _ ->
        graph
    end
  end

  defp add_relations(graph, relations) when is_map(relations) do
    Enum.reduce(relations, graph, fn {rel_type, rel}, acc ->
      aid = rel["activity"]
      eid = rel["entity"] || rel["generatedEntity"]
      agid = rel["agent"]
      used_eid = rel["usedEntity"]

      activity_iri = if aid, do: prov_iri(aid), else: nil
      entity_iri = if eid, do: prov_iri(eid), else: nil
      agent_iri = if agid, do: prov_iri(agid), else: nil
      used_entity_iri = if used_eid, do: prov_iri(used_eid), else: nil

      case rel_type do
        "wasGeneratedBy" ->
          acc |> Graph.add({entity_iri, ~I<prov:wasGeneratedBy>, activity_iri})
        "wasAttributedTo" ->
          acc |> Graph.add({entity_iri, ~I<prov:wasAttributedTo>, agent_iri})
        "wasAssociatedWith" ->
          acc |> Graph.add({activity_iri, ~I<prov:wasAssociatedWith>, agent_iri})
        "used" ->
          acc |> Graph.add({activity_iri, ~I<prov:used>, entity_iri})
        "wasDerivedFrom" ->
          acc |> Graph.add({entity_iri, ~I<prov:wasDerivedFrom>, used_entity_iri})
        _ ->
          acc
      end
    end)
  end

  defp add_attributes(graph, _subj, attrs) when not is_map(attrs), do: graph

  defp add_attributes(graph, subj, attrs) when is_map(attrs) do
    Enum.reduce(attrs, graph, fn {k, v}, acc ->
      case String.split(k, ":", parts: 2) do
        ["prov", "type"] when is_binary(v) ->
          # Add both prov:type as a literal and rdf:type as a class IRI
          acc
          |> Graph.add({subj, ~I<prov:type>, RDF.literal(v)})
          |> Graph.add({subj, ~I<rdf:type>, RDF.iri("http://www.w3.org/ns/prov##{v}")})
        [pfx, local] ->
          pred = ~i<#{pfx}:#{local}>
          obj = RDF.literal(v)
          Graph.add(acc, {subj, pred, obj})

        _ ->
          acc
      end
    end)
  end
end
