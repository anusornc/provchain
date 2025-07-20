defmodule ProvChain.KnowledgeGraph.GraphStore do
  @moduledoc """
  Simple graph storage interface for ProvChain knowledge graphs.
  Uses internal RDF store instead of external RDF.Graph library.
  """

  alias ProvChain.Storage.RdfStore

  @doc """
  Stores a triple in the graph.
  """
  def store_triple(subject, predicate, object) do
    RdfStore.add_triples([{subject, predicate, object}])
  end

  @doc """
  Stores multiple triples in the graph.
  """
  def store_triples(triples) when is_list(triples) do
    RdfStore.add_triples(triples)
  end

  @doc """
  Queries the graph for triples matching the pattern.
  """
  def query_pattern(subject \\ :any, predicate \\ :any, object \\ :any) do
    # Get all triples and filter by pattern
    all_triples = RdfStore.get_all_triples()

    Enum.filter(all_triples, fn {s, p, o} ->
      matches_pattern?(s, subject) and
      matches_pattern?(p, predicate) and
      matches_pattern?(o, object)
    end)
  end

  @doc """
  Gets all triples in the graph.
  """
  def get_all_triples do
    RdfStore.get_all_triples()
  end

  @doc """
  Counts triples matching a pattern.
  """
  def count_triples(subject \\ :any, predicate \\ :any, object \\ :any) do
    query_pattern(subject, predicate, object)
    |> length()
  end

  @doc """
  Finds all subjects with a given predicate and object.
  """
  def find_subjects(predicate, object) do
    query_pattern(:any, predicate, object)
    |> Enum.map(fn {s, _p, _o} -> s end)
    |> Enum.uniq()
  end

  @doc """
  Finds all objects with a given subject and predicate.
  """
  def find_objects(subject, predicate) do
    query_pattern(subject, predicate, :any)
    |> Enum.map(fn {_s, _p, o} -> o end)
    |> Enum.uniq()
  end

  @doc """
  Finds all predicates between a subject and object.
  """
  def find_predicates(subject, object) do
    query_pattern(subject, :any, object)
    |> Enum.map(fn {_s, p, _o} -> p end)
    |> Enum.uniq()
  end

  @doc """
  Clears all triples from the graph.
  """
  def clear do
    RdfStore.clear()
  end

  @doc """
  Checks if a triple exists in the graph.
  """
  def has_triple?(subject, predicate, object) do
    case query_pattern(subject, predicate, object) do
      [] -> false
      _ -> true
    end
  end

  @doc """
  Gets all unique subjects in the graph.
  """
  def get_subjects do
    RdfStore.get_all_triples()
    |> Enum.map(fn {s, _p, _o} -> s end)
    |> Enum.uniq()
  end

  @doc """
  Gets all unique predicates in the graph.
  """
  def get_predicates do
    RdfStore.get_all_triples()
    |> Enum.map(fn {_s, p, _o} -> p end)
    |> Enum.uniq()
  end

  @doc """
  Gets all unique objects in the graph.
  """
  def get_objects do
    RdfStore.get_all_triples()
    |> Enum.map(fn {_s, _p, o} -> o end)
    |> Enum.uniq()
  end

  @doc """
  Gets graph statistics.
  """
  def get_stats do
    all_triples = RdfStore.get_all_triples()

    %{
      total_triples: length(all_triples),
      unique_subjects: get_subjects() |> length(),
      unique_predicates: get_predicates() |> length(),
      unique_objects: get_objects() |> length()
    }
  end

  # Private functions

  defp matches_pattern?(_value, :any), do: true
  defp matches_pattern?(value, pattern), do: value == pattern
end
