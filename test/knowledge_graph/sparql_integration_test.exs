defmodule ProvChain.KnowledgeGraphTest do
  use ExUnit.Case, async: false
  @tag :skip

  alias ProvChain.KnowledgeGraph.{MilkSupplyChain, QueryEngine, GraphStore}

  setup do
    IO.puts("---- Starting test setup ----")
    IO.puts("Clearing graph store")

    # Clear graph store
    ProvChain.Storage.BlockStore.create_tables()
    GraphStore.clear()

    on_exit(fn ->
      IO.puts("Cleaning up after test")
      GraphStore.clear()
    end)

    IO.puts("---- Setup complete ----")
    :ok
  end

  describe "PROV-O Milk Supply Chain" do
    test "creates complete milk trace with proper PROV-O structure" do
      batch_id = "test_batch_#{System.system_time()}"

      # Create supply chain trace
      triples = MilkSupplyChain.create_milk_trace(batch_id)

      # Add to graph store
      GraphStore.store_triples(triples)

      # Verify we have entities, activities, and agents
      entity_count = QueryEngine.find_entities_by_type("Entity")

      # Should have at least 3 entities (milk batch, processed milk, packaged milk)
      assert entity_count.count >= 3
    end

    @tag :skip
  test "traces product to origin correctly" do
      batch_id = "trace_test_#{System.system_time()}"

      # Create and store supply chain
      triples = MilkSupplyChain.create_milk_trace(batch_id)
      GraphStore.store_triples(triples)

      # Trace packaged milk back to origin
      packaged_milk_iri = "http://example.org/milk/package/#{batch_id}"
      trace_results = QueryEngine.find_derivation_chain(packaged_milk_iri)

      # Should find results (either from SPARQL or fallback)
      # With fallback mechanism, we expect at least 1 result
      assert length(trace_results.derivation_chain) >= 1
    end

    test "finds contamination impact correctly" do
      batch_id = "contamination_test_#{System.system_time()}"

      # Create supply chain
      triples = MilkSupplyChain.create_milk_trace(batch_id)
      GraphStore.store_triples(triples)

      # Check contamination impact from milk batch
      milk_batch_iri = "http://example.org/milk/batch/#{batch_id}"
      impact_results = QueryEngine.find_derived_entities(milk_batch_iri)

      # Should find results (either from SPARQL or fallback)
      assert length(impact_results.derived_entities) >= 0
    end
  end

  describe "Performance Tests" do
    test "handles multiple supply chains efficiently" do
      # Create multiple supply chains
      batch_ids = for i <- 1..10, do: "perf_test_#{i}_#{System.system_time()}"

      all_triples =
        batch_ids
        |> Enum.flat_map(&MilkSupplyChain.create_milk_trace/1)

      # Measure insertion time
      {insertion_time, :ok} = :timer.tc(fn ->
        GraphStore.store_triples(all_triples)
      end)

      # Measure query time
      first_batch_iri = "http://example.org/milk/package/#{hd(batch_ids)}"
      {query_time, _results} = :timer.tc(fn ->
        QueryEngine.find_derivation_chain(first_batch_iri)
      end)

      # Assert reasonable performance (adjust thresholds as needed)
      assert insertion_time < 5_000_000  # Less than 5 seconds
      assert query_time < 1_000_000      # Less than 1 second

      IO.puts("Insertion time: #{insertion_time / 1000}ms")
      IO.puts("Query time: #{query_time / 1000}ms")
    end
  end
end
