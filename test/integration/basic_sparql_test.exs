defmodule ProvChain.Integration.BasicSparqlTest do
  use ExUnit.Case, async: false
  
  alias ProvChain.Storage.{Manager, RdfStore}
  alias ProvChain.Test.ProvOData
  
  setup do
    # Clear all stores
    ProvChain.Storage.BlockStore.create_tables()
    ProvChain.Storage.MemoryStore.clear_cache()
    ProvChain.Storage.BlockStore.clear_tables()
    # RdfStore.clear_graph()  # Uncomment when implemented
    :ok
  end
  
  test "basic SPARQL integration" do
    # Test that modules are available
    assert Code.ensure_loaded?(ProvChain.KnowledgeGraph.GraphStore)
    assert Code.ensure_loaded?(ProvChain.KnowledgeGraph.QueryEngine)
    assert Code.ensure_loaded?(ProvChain.Storage.RdfStore)
    assert Code.ensure_loaded?(ProvChain.Storage.Manager)
  end
  
  @tag :integration
  test "store block in all layers" do
    # Create test block
    {_, validator} = ProvChain.Crypto.Signature.generate_key_pair()
    tx = ProvOData.milk_collection_transaction()
    block = ProvChain.BlockDag.Block.new([], [tx], elem(validator, 0), "test", %{})
    
    # Store in all layers
    {:ok, block} = Manager.store_block(block)
    
    # Verify storage in memory and Mnesia layers
    assert {:ok, _} = ProvChain.Storage.MemoryStore.get_block(block.hash)
    assert {:ok, _} = ProvChain.Storage.BlockStore.get_block(block.hash)
    
    # TODO: Verify RDF storage when fully implemented
  end
end
