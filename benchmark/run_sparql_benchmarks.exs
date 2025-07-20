# benchmark/run_benchmarks.exs
# Simple script to run specific benchmark components

defmodule BenchmarkRunner do
  @moduledoc """
  Simple benchmark runner for individual test components.

  Usage:
    mix run benchmark/run_benchmarks.exs main
    mix run benchmark/run_benchmarks.exs scalability
    mix run benchmark/run_benchmarks.exs complexity
    mix run benchmark/run_benchmarks.exs memory
    mix run benchmark/run_benchmarks.exs all
  """

  def main(args \\ []) do
    case args do
      ["main"] ->
        load_benchmark_module()
        SupplyChainBenchmark.run_main_benchmarks()
      ["scalability"] ->
        load_benchmark_module()
        SupplyChainBenchmark.run_scalability_benchmarks()
      ["query"] ->
        load_benchmark_module()
        SupplyChainBenchmark.run_query_benchmarks()
      ["all"] ->
        load_benchmark_module()
        SupplyChainBenchmark.run_all_benchmarks()
      _ ->
        IO.puts("""
        ProvChain Benchmark Runner

        Usage: mix run benchmark/run_benchmarks.exs [OPTION]

        Options:
          main        Run main operations benchmark
          scalability Run scalability benchmark
          query       Run query performance benchmark
          all         Run complete benchmark suite

        Examples:
          mix run benchmark/run_benchmarks.exs main
          mix run benchmark/run_benchmarks.exs all
        """)
    end
  end

  defp load_benchmark_module do
    # Load the benchmark module
    Code.eval_file("benchmark/supply_chain_benchmark.exs")
  end
end

# Get command line arguments and run
args = System.argv()
BenchmarkRunner.main(args)
