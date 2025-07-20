defmodule ProvChain.RDF.Converter do
  @moduledoc """
  Lightweight RDF converter for PROV-O transactions.
  Converts ProvChain transactions to RDF triples without external dependencies.
  """

  @prov_ns "http://www.w3.org/ns/prov#"
  @provchain_ns "http://provchain.org/ns#"
  @xsd_ns "http://www.w3.org/2001/XMLSchema#"

  @doc """
  Converts a PROV-O transaction to RDF triples in Turtle format.
  """
  @spec transaction_to_rdf(map()) :: String.t()
  def transaction_to_rdf(transaction) do
    entity = transaction["prov:entity"]
    activity = transaction["prov:activity"]
    agent = transaction["prov:agent"]
    relations = transaction["prov:relations"]

    triples = []

    # Entity triples
    triples = triples ++ entity_to_triples(entity)

    # Activity triples
    triples = triples ++ activity_to_triples(activity)

    # Agent triples
    triples = triples ++ agent_to_triples(agent)

    # Relation triples
    triples = triples ++ relations_to_triples(relations)

    # Convert to Turtle format
    prefixes = generate_prefixes()
    turtle_triples = Enum.map(triples, &triple_to_turtle/1)

    prefixes <> "\n\n" <> Enum.join(turtle_triples, " .\n") <> " ."
  end

  @doc """
  Converts multiple transactions to a combined RDF graph.
  """
  @spec transactions_to_rdf(list(map())) :: String.t()
  def transactions_to_rdf(transactions) when is_list(transactions) do
    all_triples =
      transactions
      |> Enum.flat_map(&transaction_to_rdf_triples/1)
      |> Enum.uniq()

    prefixes = generate_prefixes()
    turtle_triples = Enum.map(all_triples, &triple_to_turtle/1)

    prefixes <> "\n\n" <> Enum.join(turtle_triples, " .\n") <> " ."
  end

  @doc """
  Generates SPARQL queries for common supply chain traceability patterns.
  """
  @spec generate_trace_query(String.t()) :: String.t()
  def generate_trace_query(entity_id) do
    """
    PREFIX prov: <#{@prov_ns}>
    PREFIX pc: <#{@provchain_ns}>

    SELECT ?entity ?activity ?agent ?timestamp
    WHERE {
      <#{entity_id}> prov:wasDerivedFrom* ?entity .
      ?entity prov:wasGeneratedBy ?activity .
      ?activity prov:wasAssociatedWith ?agent .
      ?activity prov:startedAtTime ?timestamp .
    }
    ORDER BY ?timestamp
    """
  end

  @doc """
  Generates SPARQL query to find all products derived from a source entity.
  """
  @spec generate_forward_trace_query(String.t()) :: String.t()
  def generate_forward_trace_query(source_entity_id) do
    """
    PREFIX prov: <#{@prov_ns}>
    PREFIX pc: <#{@provchain_ns}>

    SELECT ?product ?activity ?timestamp
    WHERE {
      ?product prov:wasDerivedFrom+ <#{source_entity_id}> .
      ?product prov:wasGeneratedBy ?activity .
      ?activity prov:startedAtTime ?timestamp .
    }
    ORDER BY ?timestamp
    """
  end

  # Private functions

  def transaction_to_rdf_triples(transaction) do
    entity = transaction["prov:entity"]
    activity = transaction["prov:activity"]
    agent = transaction["prov:agent"]
    relations = transaction["prov:relations"]

    []
    |> Kernel.++(entity_to_triples(entity))
    |> Kernel.++(activity_to_triples(activity))
    |> Kernel.++(agent_to_triples(agent))
    |> Kernel.++(relations_to_triples(relations))
  end

  defp entity_to_triples(entity) do
    base_uri = "<#{entity["id"]}>"
    attributes = entity["attributes"] || %{}

    base_triples = [
      {base_uri, "rdf:type", "prov:Entity"},
      {base_uri, "rdf:type", "pc:#{attributes["prov:type"] || "Entity"}"}
    ]

    attribute_triples =
      attributes
      |> Enum.reject(fn {key, _} -> key == "prov:type" end)
      |> Enum.map(fn {key, value} ->
        {base_uri, "pc:#{key}", format_literal(value)}
      end)

    base_triples ++ attribute_triples
  end

  defp activity_to_triples(activity) do
    base_uri = "<#{activity["id"]}>"
    attributes = activity["attributes"] || %{}

    base_triples = [
      {base_uri, "rdf:type", "prov:Activity"},
      {base_uri, "rdf:type", "pc:#{attributes["prov:type"] || "Activity"}"}
    ]

    # Handle time attributes specially
    time_triples = [
      {base_uri, "prov:startedAtTime", format_datetime(attributes["prov:startTime"])},
      {base_uri, "prov:endedAtTime", format_datetime(attributes["prov:endTime"])}
    ] |> Enum.reject(fn {_, _, value} -> value == nil end)

    other_attributes =
      attributes
      |> Enum.reject(fn {key, _} -> key in ["prov:type", "prov:startTime", "prov:endTime"] end)
      |> Enum.map(fn {key, value} ->
        {base_uri, "pc:#{key}", format_literal(value)}
      end)

    base_triples ++ time_triples ++ other_attributes
  end

  defp agent_to_triples(agent) do
    base_uri = "<#{agent["id"]}>"
    attributes = agent["attributes"] || %{}

    base_triples = [
      {base_uri, "rdf:type", "prov:Agent"},
      {base_uri, "rdf:type", "pc:#{attributes["prov:type"] || "Agent"}"}
    ]

    attribute_triples =
      attributes
      |> Enum.reject(fn {key, _} -> key == "prov:type" end)
      |> Enum.map(fn {key, value} ->
        {base_uri, "pc:#{key}", format_literal(value)}
      end)

    base_triples ++ attribute_triples
  end

  defp relations_to_triples(relations) do
    relations
    |> Enum.flat_map(&relation_to_triples/1)
  end

  defp relation_to_triples({"wasGeneratedBy", relation}) do
    entity_uri = "<#{relation["entity"]}>"
    activity_uri = "<#{relation["activity"]}>"

    [{entity_uri, "prov:wasGeneratedBy", activity_uri}]
  end

  defp relation_to_triples({"wasAttributedTo", relation}) do
    entity_uri = "<#{relation["entity"]}>"
    agent_uri = "<#{relation["agent"]}>"

    [{entity_uri, "prov:wasAttributedTo", agent_uri}]
  end

  defp relation_to_triples({"wasAssociatedWith", relation}) do
    activity_uri = "<#{relation["activity"]}>"
    agent_uri = "<#{relation["agent"]}>"

    [{activity_uri, "prov:wasAssociatedWith", agent_uri}]
  end

  defp relation_to_triples({"used", relation}) do
    activity_uri = "<#{relation["activity"]}>"
    entity_uri = "<#{relation["entity"]}>"

    [{activity_uri, "prov:used", entity_uri}]
  end

  defp relation_to_triples({"wasDerivedFrom", relation}) do
    generated_uri = "<#{relation["generatedEntity"]}>"
    used_uri = "<#{relation["usedEntity"]}>"

    [{generated_uri, "prov:wasDerivedFrom", used_uri}]
  end

  defp relation_to_triples({_unknown_relation, _}) do
    # Skip unknown relations
    []
  end

  defp format_literal(value) when is_binary(value) do
    ~s("#{escape_string(value)}")
  end

  defp format_literal(value) when is_number(value) do
    ~s("#{value}"^^xsd:decimal)
  end

  defp format_literal(value) when is_boolean(value) do
    ~s("#{value}"^^xsd:boolean)
  end

  defp format_literal(value) when is_map(value) do
    # For complex objects, serialize as JSON string
    json = Jason.encode!(value)
    ~s("#{escape_string(json)}"^^pc:json)
  end

  defp format_literal(value) do
    ~s("#{inspect(value)}")
  end

  defp format_datetime(nil), do: nil
  defp format_datetime(timestamp) when is_integer(timestamp) do
    # Convert millisecond timestamp to ISO8601
    datetime = DateTime.from_unix!(timestamp, :millisecond)
    iso_string = DateTime.to_iso8601(datetime)
    ~s("#{iso_string}"^^xsd:dateTime)
  end
  defp format_datetime(datetime_string) when is_binary(datetime_string) do
    ~s("#{datetime_string}"^^xsd:dateTime)
  end

  defp escape_string(str) do
    str
    |> String.replace("\\", "\\\\")
    |> String.replace("\"", "\\\"")
    |> String.replace("\n", "\\n")
    |> String.replace("\t", "\\t")
  end

  defp triple_to_turtle({subject, predicate, object}) do
    "#{subject} #{predicate} #{object}"
  end

  defp generate_prefixes do
    """
    @prefix rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#> .
    @prefix prov: <#{@prov_ns}> .
    @prefix pc: <#{@provchain_ns}> .
    @prefix xsd: <#{@xsd_ns}> .
    """
  end
end
