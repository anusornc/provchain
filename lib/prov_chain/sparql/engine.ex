defmodule ProvChain.SPARQL.Engine do
  @moduledoc """
  SPARQL engine for ProvChain, supporting SELECT queries on RDF.Graph.
  """

  alias RDF.Graph
  alias SPARQL.Query
  alias SPARQL.Query.Result
  require Logger

  @doc """
  Executes a SPARQL SELECT query on the given RDF.Graph.
  Returns {:ok, Result} for valid queries or {:error, reason} for invalid queries.
  """
  @spec query(String.t() | SPARQL.Query.t() | :minimal | :simple | :programmatic, RDF.Graph.t()) ::
          {:ok, Result.t()} | {:error, term()}
  def query(query_input, %Graph{} = graph) do
    # Add standard prefixes to the existing graph without complex merging
    graph_for_query = 
      graph
      |> RDF.Graph.add_prefixes(%{
        prov: ProvChain.Ontology.NS.PROV,
        rdf: RDF.NS.RDF
      })

    # Convert to SPARQL.Query
    query_result =
      case query_input do
        :minimal ->
          Logger.debug("Executing hardcoded minimal SPARQL query")
          {:ok, Query.new("SELECT ?s WHERE { ?s a <http://www.w3.org/ns/prov#Entity> . }")}

        :simple ->
          Logger.debug("Executing simple SPARQL query")
          {:ok, Query.new("SELECT ?s WHERE { ?s ?p ?o . }")}

        :programmatic ->
          Logger.debug("Executing programmatic SPARQL query")
          {:ok, %Query{
            form: :select,
            expr: %SPARQL.Algebra.Project{
              vars: ["s"],
              expr: %SPARQL.Algebra.BGP{
                triples: [{"s", RDF.type, RDF.iri("http://www.w3.org/ns/prov#Entity")}]
              }
            }
          }}

        %Query{} = query ->
          {:ok, query}

        query_string when is_binary(query_string) ->
          clean_query = String.trim(query_string)
          Logger.debug("Executing SPARQL query: #{inspect(clean_query)}")
          Logger.debug("Query bytes: #{inspect(:binary.bin_to_list(clean_query))}")
          try do
            case Query.new(clean_query) do
              %Query{} = query -> {:ok, query}
              {:error, reason} -> {:error, reason}
            end
          rescue
            e ->
              Logger.error("Query parsing exception: #{inspect(e)}")
              {:error, "Query parsing failed: #{inspect(e)}"}
          end
      end

    # Log graph details using the fully prepared graph_for_query
    do_log_graph_details(graph_for_query)

    case query_result do
      {:ok, %Query{} = query} ->
        Logger.debug(fn ->
          "Executing SPARQL query object: #{inspect(query, pretty: true, limit: :infinity)}"
        end)
        # Execute query with the graph that has all necessary prefixes and data
        case SPARQL.execute_query(graph_for_query, query) do
          {:ok, %Result{} = result} -> {:ok, result}
          %Result{} = result -> {:ok, result}
          {:error, reason} ->
            Logger.error("SPARQL query execution failed: #{inspect(reason)}")
            {:error, reason}
          other ->
            Logger.error("Unexpected result from SPARQL.execute_query: #{inspect(other)}")
            {:error, other}
        end
      {:error, reason} ->
        Logger.error("Failed to parse SPARQL query: #{inspect(reason)}")
        {:error, reason}
    end
  end

  # Helper function for logging to ensure correct scope
  defp do_log_graph_details(%RDF.Graph{} = graph_to_log) do
    Logger.debug(fn ->
      triples = RDF.Graph.triples(graph_to_log)
      num_triples = Enum.count(triples)
      triples_sample = Enum.take(triples, 5)
      "SPARQL.Engine.query/2 received graph. Number of triples: #{num_triples}. Sample triples: #{inspect(triples_sample)}"
    end)
  end
end
