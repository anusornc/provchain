defmodule ProvChain.SPARQL.EngineTest do
  use ExUnit.Case, async: false

  alias ProvChain.KG.Builder # Correctly alias Builder
  alias ProvChain.KG.Store
  alias ProvChain.SPARQL.Engine
  alias RDF.Graph
  import RDF.Sigils
  alias ProvChain.Test.ProvOData # Alias for test data

  alias ProvChain.BlockDag.Transaction
  alias ProvChain.Storage.BlockStore

  require Logger

  setup do
    Logger.debug("--- Starting SPARQL.EngineTest Setup ---")

    stop_process_if_running(Store)
    stop_process_if_running(BlockStore)

    :mnesia.stop()
    :ok = :mnesia.delete_schema([node()])
    mnesia_dir = Application.fetch_env!(:mnesia, :dir) |> to_string()
    File.rm_rf!(mnesia_dir)
    File.mkdir_p!(mnesia_dir)
    :ok = :mnesia.create_schema([node()])
    :ok = :mnesia.start()
    :ok = :mnesia.wait_for_tables([:schema], 30_000)
    Logger.info("Mnesia schema created and started for SPARQL.EngineTest")

    storage_opts = [ram_copies: [node()]]
    table = BlockStore.transactions_table()
    opts = [attributes: [:hash, :data], type: :set]
    case :mnesia.create_table(table, opts ++ storage_opts) do
      {:atomic, :ok} -> Logger.info("Created Mnesia table #{table}")
      {:aborted, {:already_exists, ^table}} -> Logger.info("Mnesia table #{table} already exists.")
      {:aborted, reason} -> flunk("Failed to create Mnesia table #{table}: #{inspect(reason)}")
    end
    :ok = :mnesia.wait_for_tables([table], 30_000)
    Logger.info("Mnesia table #{table} is ready.")

    {:ok, block_store_pid} = BlockStore.start_link([])
    Logger.info("BlockStore started for SPARQL.EngineTest (PID: #{inspect(block_store_pid)})")

    tx1_data = ProvOData.milk_collection_transaction()
    tx1 = Transaction.new(tx1_data["prov:entity"], tx1_data["prov:activity"], tx1_data["prov:agent"], tx1_data["prov:relations"], tx1_data["supply_chain_data"], tx1_data["timestamp"])
    :ok = BlockStore.put_transaction(tx1)

    tx2_data = ProvOData.milk_processing_transaction(tx1["prov:entity"]["id"])
    tx2 = Transaction.new(tx2_data["prov:entity"], tx2_data["prov:activity"], tx2_data["prov:agent"], tx2_data["prov:relations"], tx2_data["supply_chain_data"], tx2_data["timestamp"])
    :ok = BlockStore.put_transaction(tx2)

    tx3_data = ProvOData.packaging_transaction(tx2["prov:entity"]["id"])
    tx3 = Transaction.new(tx3_data["prov:entity"], tx3_data["prov:activity"], tx3_data["prov:agent"], tx3_data["prov:relations"], tx3_data["supply_chain_data"], tx3_data["timestamp"])
    :ok = BlockStore.put_transaction(tx3)

    {:ok, store_pid} = Store.start_link([])
    Logger.info("KG.Store started for SPARQL.EngineTest (PID: #{inspect(store_pid)})")

    on_exit(fn ->
      Logger.debug("--- Starting SPARQL.EngineTest Teardown ---")
      stop_process_if_running(Store)
      stop_process_if_running(BlockStore)
      if :mnesia.system_info(:is_running) == :yes, do: :mnesia.stop()
      Logger.debug("--- Finished SPARQL.EngineTest Teardown ---")
    end)

    Logger.debug("--- Finished SPARQL.EngineTest Setup ---")
    {:ok, %{store_pid: store_pid, tx1: tx1, tx2: tx2, tx3: tx3}}
  end

  defp stop_process_if_running(module_or_name) do
    case Process.whereis(module_or_name) do
      pid when is_pid(pid) ->
        Logger.debug("Stopping #{inspect(module_or_name)} (PID: #{inspect(pid)})")
        ref = Process.monitor(pid)
        Process.exit(pid, :shutdown)
        receive do
          {:DOWN, ^ref, _, _, _} -> Logger.debug("#{inspect(module_or_name)} stopped.")
        after 5000 ->
          Logger.warning("#{inspect(module_or_name)} did not stop gracefully after 5s. Killing.")
          Process.exit(pid, :kill)
        end
      nil ->
        Logger.debug("#{inspect(module_or_name)} not running.")
        :ok
    end
  end

  describe "Engine.query/2" do
    test "programmatic query", %{tx1: _tx1} do
      graph = Store.graph()
      result = Engine.query(:programmatic, graph)
      Logger.debug("Programmatic query result: #{inspect(result)}")
      assert {:ok, _results} = result
    end

    test "simple query", %{tx1: _tx1} do
      graph = Store.graph()
      result = Engine.query(:simple, graph)
      Logger.debug("Simple query result: #{inspect(result)}")
      assert {:ok, _results} = result
    end

    test "hardcoded minimal query", %{tx1: _tx1} do
      graph = Store.graph()
      result = Engine.query(:minimal, graph)
      Logger.debug("Hardcoded minimal query result: #{inspect(result)}")
      assert {:ok, _results} = result
    end

    test "minimal query without PREFIX", %{tx1: _tx1} do
      query = "SELECT ?s WHERE { ?s a <http://www.w3.org/ns/prov#Entity> . }"
      graph = Store.graph()
      result = Engine.query(query, graph)
      Logger.debug("Minimal query result: #{inspect(result)}")
      assert {:ok, _results} = result
    end

    test "supports basic SELECT query to find entities", %{tx1: tx1, tx2: tx2, tx3: tx3} do
      query = [
        "PREFIX prov: <http://www.w3.org/ns/prov#>",
        "SELECT ?s WHERE { ?s a prov:Entity . } ORDER BY ?s"
      ] |> Enum.join("\n")
      graph = Store.graph()
      assert {:ok, results} = Engine.query(query, graph)

      IO.inspect(results.results, label: "SPARQL Query Results")
      subjects = Enum.map(results.results, &(&1["s"])) |> Enum.sort()
      expected_iris = [
        ~i<prov:#{tx1["prov:entity"]["id"]}>,
        ~i<prov:#{tx2["prov:entity"]["id"]}>,
        ~i<prov:#{tx3["prov:entity"]["id"]}>
      ] |> Enum.sort()
      IO.inspect(subjects, label: "Subjects from Query")
      IO.inspect(expected_iris, label: "Expected IRIs")
      assert subjects == expected_iris
    end

    test "supports query with FILTER", %{tx1: tx1} do
      entity_id = tx1["prov:entity"]["id"]
      entity_iri = ~i<prov:#{entity_id}>
      query = [
        "PREFIX prov: <http://www.w3.org/ns/prov#>",
        "SELECT ?s WHERE {",
        "  ?s a prov:Entity .",
        "  FILTER (?s = <#{entity_iri}>)",
        "}"
      ] |> Enum.join("\n")
      graph = Store.graph()
      assert {:ok, results} = Engine.query(query, graph)
      assert length(results.results) == 1
      assert hd(results.results)["s"] == entity_iri
    end

    test "supports traceability query (wasDerivedFrom*)", %{tx1: tx1, tx2: tx2, tx3: tx3} do
      package_id = tx3["prov:entity"]["id"]
      package_iri = ~i<prov:#{package_id}>
      query = [
        "PREFIX prov: <http://www.w3.org/ns/prov#>",
        "SELECT ?usedEntity WHERE {",
        "  <#{package_iri}> prov:wasDerivedFrom* ?usedEntity .",
        "  FILTER(?usedEntity != <#{package_iri}>)",
        "} ORDER BY ?usedEntity"
      ] |> Enum.join("\n")
      graph = Store.graph()
      assert {:ok, results} = Engine.query(query, graph)
      assert length(results.results) == 2
      subjects = Enum.map(results.results, &(&1["usedEntity"])) |> Enum.sort()
      expected_iris = [
        ~i<prov:#{tx1["prov:entity"]["id"]}>,
        ~i<prov:#{tx2["prov:entity"]["id"]}>
      ] |> Enum.sort()
      assert subjects == expected_iris
    end

    test "Engine.query/2 supports query checking specific relations (e.g., used)" do
      # Test data setup
      transaction_id = "tx-for-used-test"
      # Ensure ProvOData.milk_processing_transaction/1 returns the activity and generated entity
      # and that ProvOData.milk_batch_entity/1 returns the entity to be used.

      # Define the activity that will use an entity
      processing_activity = ProvOData.activity_data("milk-processing-activity", "Milk Processing")

      # Define the entity that was generated by some previous activity (not explicitly modeled here for simplicity)
      # This is the entity that will be 'used' by 'milk-processing-activity'
      used_milk_entity = ProvOData.milk_batch_entity("used-milk-for-processing")

      # Define the entity that is generated by the 'milk-processing-activity'
      # This is 'processed-milk-from-used-test'
      generated_entity = ProvOData.processed_milk_entity("processed-milk-from-#{transaction_id}")


      # Construct the transaction map for Builder.build_graph/1
      transaction_data = %{
        "id" => transaction_id, # Optional: for tracking or if your build_graph needs it
        "prov:activity" => processing_activity,
        "prov:entity" => generated_entity, # The entity generated by this activity
        "prov:agent" => ProvOData.agent_data("processor-agent", "Processor"), # Dummy agent
        "prov:relations" => %{
          "used" => [%{ # Relations are now a list
            "activity" => processing_activity["id"],
            "entity" => used_milk_entity["id"],
            "id" => "custom-used-relation-#{transaction_id}" # Optional: relation ID
          }],
          # Relation showing that generated_entity wasGeneratedBy processing_activity
          "wasGeneratedBy" => [%{ # Relations are now a list
            "entity" => generated_entity["id"],
            "activity" => processing_activity["id"],
            "id" => "custom-wgb-relation-#{transaction_id}" # Optional: relation ID
          }]
        },
        "supply_chain_data" => %{}, # Dummy supply chain data
        "timestamp" => DateTime.utc_now() |> DateTime.to_iso8601()
      }

      # Add the 'used' entity separately if build_graph doesn't handle pre-existing entities
      # that are only part of a 'used' relation and not 'generatedBy' this specific transaction.
      # For this test, we'll assume build_graph can create it or we can add it.
      # A more robust approach might be to ensure `used_milk_entity` is also part of the `entities`
      # list if `build_graph` expects all entities to be declared.
      # However, the `Builder.build_graph` should ideally create triples for all referenced entities.

      # Let's create a list of all entities involved to pass to build_graph if needed,
      # or ensure build_graph can infer them from relations.
      # For now, assuming build_graph will create triples for processing_activity, generated_entity,
      # and used_milk_entity (due to its appearance in the 'used' relation).

      graph = Builder.build_graph(transaction_data, [used_milk_entity]) # Pass used_milk_entity as a pre-existing entity

      IO.puts("--- Graph triples for prov:used test ---")
      graph
      |> Graph.triples()
      |> Enum.each(fn triple -> IO.inspect(triple, label: "Triple") end)


      # SPARQL query to find the entity used by the processing activity
      query = [
        "PREFIX prov: <http://www.w3.org/ns/prov#>",
        "PREFIX rdf: <http://www.w3.org/1999/02/22-rdf-syntax-ns#>",
        "SELECT ?usedEntity WHERE {",
        "  <prov:#{processing_activity["id"]}> prov:used <prov:#{used_milk_entity["id"]}> .",
        "  <prov:#{used_milk_entity["id"]}> rdf:type prov:Entity .", # Verify it's an entity
        "  BIND(<prov:#{used_milk_entity["id"]}> AS ?usedEntity)", # Bind to the variable we want
        "}"
      ] |> Enum.join("\n")

      # More specific query to ensure the relation exists as expected:
      # query = [
      #   "PREFIX prov: <http://www.w3.org/ns/prov#>",
      #   "ASK {",
      #   "  <prov:#{processing_activity[\"id\"]}> prov:used <prov:#{used_milk_entity[\"id\"]}> .",
      #   "}"
      # ] |> Enum.join("\n")


      Logger.debug("Executing prov:used query: #{query}")
      assert {:ok, results} = Engine.query(query, graph)

      # IO.inspect(results, label: "prov:used Query Results")
      # For ASK query:
      # assert results.boolean == true

      # For SELECT query:
      assert length(results.results) == 1, "Expected to find one used entity"
      found_entity_iri = hd(results.results)["usedEntity"]
      assert found_entity_iri == RDF.iri("prov:#{used_milk_entity["id"]}")
    end

    test "returns empty result for non-matching query" do
      query = [
        "PREFIX prov: <http://www.w3.org/ns/prov#>",
        "SELECT ?s WHERE { ?s prov:wasGeneratedBy <urn:nonexistent> . }"
      ] |> Enum.join("\n")
      graph = Store.graph()
      assert {:ok, results} = Engine.query(query, graph)
      assert results.results == []
    end

    test "returns error for invalid SPARQL query syntax" do
      query = "SELECT ?s WHERE { ?s a <http://www.w3.org/ns/prov#Entity> "
      graph = Store.graph()
      assert {:error, _reason} = Engine.query(query, graph)
    end
  end
end
