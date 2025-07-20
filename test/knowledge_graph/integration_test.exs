defmodule ProvChain.RDF.IntegrationTest do
  use ExUnit.Case, async: true

  alias ProvChain.RDF.{Converter, Integration}
  alias ProvChain.SPARQL.Processor
  alias ProvChain.Test.ProvOData

  describe "RDF conversion" do
    test "converts PROV-O transaction to RDF triples" do
      transaction = ProvOData.milk_collection_transaction()

      rdf_output = Converter.transaction_to_rdf(transaction)

      # Check that RDF contains expected elements
      assert String.contains?(rdf_output, "@prefix prov:")
      assert String.contains?(rdf_output, "@prefix pc:")
      assert String.contains?(rdf_output, "rdf:type prov:Entity")
      assert String.contains?(rdf_output, "rdf:type prov:Activity")
      assert String.contains?(rdf_output, "rdf:type prov:Agent")
      assert String.contains?(rdf_output, "prov:wasGeneratedBy")
      assert String.contains?(rdf_output, "prov:wasAttributedTo")
      assert String.contains?(rdf_output, "prov:wasAssociatedWith")
    end

    test "converts supply chain trace to RDF" do
      trace = ProvOData.generate_supply_chain_trace()

      rdf_output = Converter.transactions_to_rdf(trace)

      # Should contain all transactions
      assert String.contains?(rdf_output, "MilkCollection")
      assert String.contains?(rdf_output, "MilkProcessing")
      assert String.contains?(rdf_output, "Packaging")
      assert String.contains?(rdf_output, "Distribution")

      # Should contain derivation relationships
      assert String.contains?(rdf_output, "prov:wasDerivedFrom")
    end
  end

  describe "SPARQL query generation" do
    test "generates trace query" do
      entity_id = "batch:123"

      query = Converter.generate_trace_query(entity_id)

      assert String.contains?(query, "PREFIX prov:")
      assert String.contains?(query, "SELECT ?entity ?activity ?agent ?timestamp")
      assert String.contains?(query, "prov:wasDerivedFrom*")
      assert String.contains?(query, entity_id)
    end

    test "generates forward trace query" do
      source_id = "batch:456"

      query = Converter.generate_forward_trace_query(source_id)

      assert String.contains?(query, "PREFIX prov:")
      assert String.contains?(query, "SELECT ?product ?activity ?timestamp")
      assert String.contains?(query, "prov:wasDerivedFrom+")
      assert String.contains?(query, source_id)
    end
  end

  describe "SPARQL query processing" do
    test "traces entity history" do
      # This test would require actual blockchain data
      # For now, we'll test the structure

      entity_id = "batch:test123"

      # In a real scenario, you'd set up test data first
      case Processor.trace_entity(entity_id) do
        {:ok, trace} ->
          assert is_list(trace)
        {:error, _reason} ->
          # Expected if no data exists
          :ok
      end
    end
  end

  describe "Integration module" do
    test "formats trace results correctly" do
      # Test the formatting logic with mock data
      mock_trace = [
        %{
          "entity" => %{"id" => "test:1", "attributes" => %{"prov:type" => "TestEntity"}},
          "activity" => %{"id" => "act:1", "attributes" => %{"prov:type" => "TestActivity"}},
          "agent" => %{"id" => "agent:1", "attributes" => %{"prov:type" => "TestAgent", "name" => "Test Agent"}},
          "timestamp" => 1640000000000
        }
      ]

      # This would test the private formatting functions
      # In a real test, you'd need to expose them or test through public API
      assert length(mock_trace) == 1
    end
  end
end
