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
    rdf:  RDF.NS.RDF
  }

  @doc "Return the namespace prefixes map."
  @spec prefixes() :: map()
  def prefixes, do: @prefixes

  @doc "Build an RDF.Graph from a PROV-O transaction map."
  @spec build_graph(map()) :: RDF.Graph.t()
  def build_graph(%{
        "prov:entity"    => entity,
        "prov:activity"  => activity,
        "prov:agent"     => agent,
        "prov:relations" => relations
      }) do
    Graph.new([], prefixes: @prefixes)
    |> add_entity(entity)
    |> add_activity(activity)
    |> add_agent(agent)
    |> add_relations(relations)
  end

  # -- Private helpers --

  defp add_entity(graph, %{"id" => id, "attributes" => attrs}) do
    subj = ~i<prov:#{id}>

    graph
    |> Graph.add({subj, ~I<rdf:type>, ~I<prov:Entity>})
    |> add_attributes(subj, attrs)
  end

  defp add_activity(graph, %{"id" => id}) do
    subj = ~i<prov:#{id}>
    Graph.add(graph, {subj, ~I<rdf:type>, ~I<prov:Activity>})
  end

  defp add_agent(graph, %{"id" => id}) do
    subj = ~i<prov:#{id}>
    Graph.add(graph, {subj, ~I<rdf:type>, ~I<prov:Agent>})
  end

  defp add_relations(graph, relations) when is_map(relations) do
    Enum.reduce(relations, graph, fn {_name, rel}, acc ->
      rid = rel["id"]
      aid = rel["activity"]
      eid = rel["entity"] || rel["generatedEntity"]
      agid = rel["agent"]

      subj = ~i<prov:#{rid}>

      acc
      |> Graph.add({subj, ~I<rdf:type>, ~I<prov:Relation>})
      |> Graph.add({subj, ~I<prov:activity>, ~i<prov:#{aid}>})
      |> Graph.add({subj, ~I<prov:entity>, ~i<prov:#{eid}>})
      |> Graph.add({subj, ~I<prov:agent>, ~i<prov:#{agid}>})
    end)
  end

  defp add_attributes(graph, _subj, attrs) when not is_map(attrs), do: graph

  defp add_attributes(graph, subj, attrs) when is_map(attrs) do
    Enum.reduce(attrs, graph, fn {k, v}, acc ->
      case String.split(k, ":", parts: 2) do
        [pfx, local] ->
          pred = ~i<#{pfx}:#{local}>
          obj  = RDF.literal(v)
          Graph.add(acc, {subj, pred, obj})
        _ ->
          acc
      end
    end)
  end
end
