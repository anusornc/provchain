# benchmark/supply_chain_benchmark.exs
# Enhanced benchmark with benchee_html for comprehensive HTML reporting

alias ProvChain.KnowledgeGraph.{MilkSupplyChain, QueryEngine, GraphStore}

defmodule SupplyChainBenchmark do
  @moduledoc """
  Comprehensive benchmark suite for ProvChain.KnowledgeGraph with HTML reporting.

  Generates detailed performance reports in multiple formats:
  - Console output for immediate feedback
  - HTML reports for detailed analysis and sharing
  - JSON data for further processing
  """

  @benchmark_output_dir "benchmark_results"

  def run_main_benchmarks do
    IO.puts("🚀 Starting ProvChain PROV-O + SPARQL Main Benchmark...")
    IO.puts("=" |> String.duplicate(60))

    # Ensure output directory exists
    File.mkdir_p!(@benchmark_output_dir)

    # Setup common test data
    setup_test_data()

    Benchee.run(
      %{
        "create_supply_chain" => fn _input ->
          batch_id = "bench_#{System.system_time()}_#{:rand.uniform(1000)}"
          MilkSupplyChain.create_milk_trace(batch_id)
        end,
        "add_triples_to_store" => fn _input ->
          batch_id = "store_test_#{System.system_time()}"
          triples = MilkSupplyChain.create_milk_trace(batch_id)
          GraphStore.store_triples(triples)
        end,
        "trace_to_origin" => fn _input ->
          # Use pre-existing test data
          product_iri = "http://example.org/milk/package/test_batch_001"
          QueryEngine.find_derivation_chain(product_iri)
        end,
        "contamination_impact" => fn _input ->
          # Use pre-existing test data
          batch_iri = "http://example.org/milk/batch/test_batch_001"
          QueryEngine.find_derived_entities(batch_iri)
        end,
        "count_entities" => fn _input ->
          QueryEngine.find_entities_by_type("prov:Entity")
        end,
        "supply_chain_network" => fn _input ->
          # Use pre-existing test data
          batch_iri = "http://example.org/milk/batch/test_batch_001"
          QueryEngine.get_supply_chain_network(batch_iri)
        end
      },
      before_scenario: fn _job_name ->
        # Ensure we have test data for each scenario
        setup_test_data()
      end,
      time: 8,
      memory_time: 4,
      warmup: 2,
      print: [
        benchmarking: true,
        fast_warning: false,
        configuration: true
      ],
      formatters: [
        Benchee.Formatters.Console,
        {Benchee.Formatters.HTML, file: Path.join(@benchmark_output_dir, "main_benchmark.html")},
        {Benchee.Formatters.JSON, file: Path.join(@benchmark_output_dir, "main_benchmark.json")}
      ],
      title: "ProvChain Main Operations Benchmark"
    )

    IO.puts("\n📊 Main benchmark complete! Check #{@benchmark_output_dir}/main_benchmark.html")
  end

  def run_scalability_benchmarks do
    IO.puts("\n🔬 Running Scalability Benchmarks...")
    IO.puts("=" |> String.duplicate(60))

    data_sizes = [1, 5, 10, 25, 50]

    scalability_jobs =
      for size <- data_sizes, into: %{} do
        {"#{size}_supply_chains", fn ->
          # Clear graph for clean test
          GraphStore.clear()

          # Create multiple supply chains
          all_triples = 1..size
          |> Enum.flat_map(fn i ->
            MilkSupplyChain.create_milk_trace("scale_test_#{size}_#{i}_#{System.system_time()}")
          end)

          # Add to graph store
          GraphStore.store_triples(all_triples)

          # Query the first batch
          first_batch_iri = "http://example.org/milk/package/scale_test_#{size}_1_#{System.system_time()}"
          QueryEngine.find_derivation_chain(first_batch_iri)
        end}
      end

    Benchee.run(
      scalability_jobs,
      time: 6,
      memory_time: 3,
      warmup: 1,
      print: [
        benchmarking: true,
        fast_warning: false,
        configuration: true
      ],
      formatters: [
        Benchee.Formatters.Console,
        {Benchee.Formatters.HTML,
         file: Path.join(@benchmark_output_dir, "scalability_benchmark.html"),
         title: "Supply Chain Scalability Analysis"
        },
        {Benchee.Formatters.JSON, file: Path.join(@benchmark_output_dir, "scalability_benchmark.json")}
      ],
      title: "ProvChain Scalability Benchmark"
    )

    IO.puts("\n📈 Scalability benchmark complete! Check #{@benchmark_output_dir}/scalability_benchmark.html")
  end

  def run_query_benchmarks do
    IO.puts("\n🧩 Running Query Performance Benchmarks...")
    IO.puts("=" |> String.duplicate(60))

    # Setup large dataset for query testing
    setup_large_dataset()

    query_jobs = %{
      "simple_entity_count" => fn ->
        QueryEngine.find_entities_by_type("prov:Entity")
      end,
      "single_product_trace" => fn ->
        QueryEngine.find_derivation_chain("http://example.org/milk/package/large_dataset_1")
      end,
      "contamination_impact_analysis" => fn ->
        QueryEngine.find_derived_entities("http://example.org/milk/batch/large_dataset_1")
      end,
      "full_supply_chain_network" => fn ->
        QueryEngine.get_supply_chain_network("http://example.org/milk/batch/large_dataset_10")
      end
    }

    Benchee.run(
      query_jobs,
      time: 8,
      memory_time: 4,
      warmup: 2,
      print: [
        benchmarking: true,
        fast_warning: false,
        configuration: true
      ],
      formatters: [
        Benchee.Formatters.Console,
        {Benchee.Formatters.HTML,
         file: Path.join(@benchmark_output_dir, "query_benchmark.html"),
         title: "SPARQL Query Performance Analysis"
        },
        {Benchee.Formatters.JSON, file: Path.join(@benchmark_output_dir, "query_benchmark.json")}
      ],
      title: "ProvChain Query Performance Benchmark"
    )

    IO.puts("\n🎯 Query benchmark complete! Check #{@benchmark_output_dir}/query_benchmark.html")
  end

  # Helper functions
  defp setup_test_data do
    # Clear and setup basic test data
    GraphStore.clear()

    # Create a few test supply chains
    test_triples = 1..3
    |> Enum.flat_map(fn i ->
      MilkSupplyChain.create_milk_trace("test_batch_00#{i}")
    end)

    GraphStore.store_triples(test_triples)
  end

  defp setup_large_dataset do
    IO.puts("🔧 Setting up large dataset for query testing...")
    GraphStore.clear()

    # Create 30 supply chains for query testing
    large_dataset_triples = 1..30
    |> Enum.flat_map(fn i ->
      MilkSupplyChain.create_milk_trace("large_dataset_#{i}")
    end)

    GraphStore.store_triples(large_dataset_triples)
    IO.puts("✅ Large dataset ready: #{length(large_dataset_triples)} triples")
  end

  def generate_summary_report do
    IO.puts("\n📋 Generating Summary Report...")

    summary_html = """
    <!DOCTYPE html>
    <html>
    <head>
        <title>ProvChain Benchmark Summary</title>
        <style>
            body { font-family: Arial, sans-serif; max-width: 1200px; margin: 0 auto; padding: 20px; }
            .header { background: #2c3e50; color: white; padding: 20px; border-radius: 8px; margin-bottom: 20px; }
            .benchmark-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(300px, 1fr)); gap: 20px; }
            .benchmark-card { border: 1px solid #ddd; border-radius: 8px; padding: 20px; background: #f9f9f9; }
            .benchmark-card h3 { color: #2c3e50; margin-top: 0; }
            .benchmark-card a { color: #3498db; text-decoration: none; }
            .benchmark-card a:hover { text-decoration: underline; }
            .tech-info { background: #ecf0f1; padding: 15px; border-radius: 8px; margin: 20px 0; }
            .footer { text-align: center; margin-top: 30px; color: #666; }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>🚀 ProvChain PROV-O + SPARQL Benchmark Results</h1>
            <p>Comprehensive performance analysis of supply chain traceability operations</p>
            <p><strong>Generated:</strong> #{DateTime.now!("Etc/UTC") |> DateTime.to_string()}</p>
        </div>

        <div class="tech-info">
            <h3>🔧 Technology Stack</h3>
            <ul>
                <li><strong>PROV.ex:</strong> #{Application.spec(:prov, :vsn)}</li>
                <li><strong>SPARQL.ex:</strong> #{Application.spec(:sparql, :vsn)}</li>
                <li><strong>RDF.ex:</strong> #{Application.spec(:rdf, :vsn)}</li>
                <li><strong>Elixir:</strong> #{System.version()}</li>
                <li><strong>Erlang/OTP:</strong> #{System.otp_release()}</li>
            </ul>
        </div>

        <div class="benchmark-grid">
            <div class="benchmark-card">
                <h3>📊 Main Operations</h3>
                <p>Core supply chain operations including entity creation, triple storage, and basic queries.</p>
                <p><a href="main_benchmark.html">View Detailed Results →</a></p>
                <p><small>Tests: create_supply_chain, add_triples_to_store, trace_to_origin, contamination_impact, count_entities</small></p>
            </div>

            <div class="benchmark-card">
                <h3>📈 Scalability Analysis</h3>
                <p>Performance characteristics as the number of supply chains scales from 1 to 50.</p>
                <p><a href="scalability_benchmark.html">View Detailed Results →</a></p>
                <p><small>Tests: 1, 5, 10, 25, 50 supply chains</small></p>
            </div>

            <div class="benchmark-card">
                <h3>🧩 Query Performance</h3>
                <p>SPARQL query performance analysis from simple counts to complex network traversals.</p>
                <p><a href="query_benchmark.html">View Detailed Results →</a></p>
                <p><small>Tests: entity counts, product traces, contamination analysis, network queries</small></p>
            </div>
        </div>

        <div class="tech-info">
            <h3>📋 JSON Data Files</h3>
            <p>Raw benchmark data available for further analysis:</p>
            <ul>
                <li><a href="main_benchmark.json">main_benchmark.json</a></li>
                <li><a href="scalability_benchmark.json">scalability_benchmark.json</a></li>
                <li><a href="query_benchmark.json">query_benchmark.json</a></li>
            </ul>
        </div>

        <div class="footer">
            <p>Generated by ProvChain.KnowledgeGraph Benchmark Suite</p>
            <p>🌟 Powered by Benchee + Benchee HTML</p>
        </div>
    </body>
    </html>
    """

    summary_file = Path.join(@benchmark_output_dir, "index.html")
    File.write!(summary_file, summary_html)

    IO.puts("✅ Summary report generated: #{summary_file}")
  end

  def run_all_benchmarks do
    IO.puts("🎯 ProvChain PROV-O + SPARQL Complete Performance Suite")
    IO.puts("Testing: PROV.ex #{Application.spec(:prov, :vsn)} + SPARQL.ex #{Application.spec(:sparql, :vsn)}")
    IO.puts("Date: #{DateTime.now!("Etc/UTC")}")
    IO.puts("")

    # Run all benchmark suites
    run_main_benchmarks()
    run_scalability_benchmarks()
    run_query_benchmarks()

    # Generate summary
    generate_summary_report()

    IO.puts("\n🎉 Complete Benchmark Suite Finished!")
    IO.puts("=" |> String.duplicate(60))
    IO.puts("📂 All results available in: #{@benchmark_output_dir}/")
    IO.puts("🌐 Open #{@benchmark_output_dir}/index.html for summary")
    IO.puts("=" |> String.duplicate(60))
  end
end

# Run complete benchmark suite
SupplyChainBenchmark.run_all_benchmarks()
