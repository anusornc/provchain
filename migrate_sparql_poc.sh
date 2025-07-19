#!/bin/bash
# migrate_sparql_poc.sh - สคริปต์ย้ายไฟล์จาก SPARQL PoC เข้า ProvChain

set -e  # หยุดเมื่อเจอ error

echo "🚀 Starting SPARQL PoC migration to ProvChain..."

# ตรวจสอบว่าอยู่ใน ProvChain directory
if [ ! -f "mix.exs" ] || ! grep -q "provchain" mix.exs; then
    echo "❌ Error: Please run this script from ProvChain root directory"
    exit 1
fi

# สร้าง backup
echo "📦 Creating backup..."
git add .
git commit -m "Pre-SPARQL integration backup" || echo "No changes to commit"
git checkout -b feature/sparql-integration || echo "Branch already exists"

# สร้าง directories
echo "📁 Creating directories..."
mkdir -p lib/prov_chain/knowledge_graph
mkdir -p lib/prov_chain/storage/rdf_store  
mkdir -p test/knowledge_graph
mkdir -p test/integration
mkdir -p benchmark
mkdir -p benchmark_results

# Clone PoC repository
echo "📥 Cloning SPARQL PoC..."
TEMP_DIR="/tmp/prov_sparql_poc_$(date +%s)"
git clone https://github.com/anusornc/prov_sparql_poc.git "$TEMP_DIR"

# ตรวจสอบว่า clone สำเร็จ
if [ ! -d "$TEMP_DIR" ]; then
    echo "❌ Error: Failed to clone PoC repository"
    exit 1
fi

echo "✅ PoC repository cloned to $TEMP_DIR"

# Copy และแก้ไขไฟล์หลัก
echo "📄 Copying core files..."

# 1. GraphStore
if [ -f "$TEMP_DIR/lib/prov_sparql_poc/graph_store.ex" ]; then
    cp "$TEMP_DIR/lib/prov_sparql_poc/graph_store.ex" \
       "lib/prov_chain/knowledge_graph/graph_store.ex"
    echo "✅ Copied graph_store.ex"
else
    echo "⚠️  Warning: graph_store.ex not found in PoC"
fi

# 2. QueryEngine  
if [ -f "$TEMP_DIR/lib/prov_sparql_poc/query_engine.ex" ]; then
    cp "$TEMP_DIR/lib/prov_sparql_poc/query_engine.ex" \
       "lib/prov_chain/knowledge_graph/query_engine.ex"
    echo "✅ Copied query_engine.ex"
else
    echo "⚠️  Warning: query_engine.ex not found in PoC"
fi

# 3. SupplyChainModel (เดิมชื่อ milk_supply_chain.ex)
if [ -f "$TEMP_DIR/lib/prov_sparql_poc/milk_supply_chain.ex" ]; then
    cp "$TEMP_DIR/lib/prov_sparql_poc/milk_supply_chain.ex" \
       "lib/prov_chain/knowledge_graph/supply_chain_model.ex"
    echo "✅ Copied supply_chain_model.ex"
else
    echo "⚠️  Warning: milk_supply_chain.ex not found in PoC"
fi

# 4. Test file
if [ -f "$TEMP_DIR/test/prov_sparql_poc_test.exs" ]; then
    cp "$TEMP_DIR/test/prov_sparql_poc_test.exs" \
       "test/knowledge_graph/sparql_integration_test.exs"
    echo "✅ Copied test file"
else
    echo "⚠️  Warning: test file not found in PoC"
fi

# 5. Benchmark files
if [ -f "$TEMP_DIR/benchmark/supply_chain_benchmark.exs" ]; then
    cp "$TEMP_DIR/benchmark/supply_chain_benchmark.exs" \
       "benchmark/sparql_benchmarks.exs"
    echo "✅ Copied benchmark file"
fi

if [ -f "$TEMP_DIR/benchmark/run_benchmarks.exs" ]; then
    cp "$TEMP_DIR/benchmark/run_benchmarks.exs" \
       "benchmark/run_sparql_benchmarks.exs"
    echo "✅ Copied benchmark runner"
fi

# แก้ไข module names
echo "🔧 Updating module names..."

# แก้ไขไฟล์ใน knowledge_graph/
for file in lib/prov_chain/knowledge_graph/*.ex; do
    if [ -f "$file" ]; then
        # แก้ไข module names
        sed -i.bak 's/ProvSparqlPoc\.GraphStore/ProvChain.KnowledgeGraph.GraphStore/g' "$file"
        sed -i.bak 's/ProvSparqlPoc\.QueryEngine/ProvChain.KnowledgeGraph.QueryEngine/g' "$file"
        sed -i.bak 's/ProvSparqlPoc\.MilkSupplyChain/ProvChain.KnowledgeGraph.SupplyChainModel/g' "$file"
        sed -i.bak 's/ProvSparqlPoc/ProvChain.KnowledgeGraph/g' "$file"
        
        # แก้ไขชื่อ defmodule สำหรับไฟล์เฉพาะ
        if [[ "$file" == *"supply_chain_model.ex" ]]; then
            sed -i.bak 's/defmodule ProvChain.KnowledgeGraph do/defmodule ProvChain.KnowledgeGraph.SupplyChainModel do/g' "$file"
        fi
        
        # ลบไฟล์ backup
        rm -f "$file.bak"
        
        echo "✅ Updated $(basename "$file")"
    fi
done

# แก้ไข test files
for file in test/knowledge_graph/*.exs; do
    if [ -f "$file" ]; then
        sed -i.bak 's/ProvSparqlPoc/ProvChain.KnowledgeGraph/g' "$file"
        sed -i.bak 's/defmodule ProvChainTest/defmodule ProvChain.KnowledgeGraph.SparqlIntegrationTest/g' "$file"
        rm -f "$file.bak"
        echo "✅ Updated $(basename "$file")"
    fi
done

# แก้ไข benchmark files
for file in benchmark/*.exs; do
    if [ -f "$file" ]; then
        sed -i.bak 's/ProvSparqlPoc/ProvChain.KnowledgeGraph/g' "$file"
        rm -f "$file.bak"
        echo "✅ Updated $(basename "$file")"
    fi
done

# สร้างไฟล์ integration modules
echo "🆕 Creating integration modules..."

# สร้าง RdfStore module
cat > lib/prov_chain/storage/rdf_store.ex << 'EOF'
defmodule ProvChain.Storage.RdfStore do
  @moduledoc """
  Integration layer between ProvChain blockchain and SPARQL RDF Graph Store.
  
  This module provides a bridge between the blockchain persistence layer (Mnesia)
  and the semantic query layer (SPARQL), converting blockchain data to PROV-O
  compliant RDF triples for advanced querying capabilities.
  """
  
  use GenServer
  require Logger
  
  alias ProvChain.KnowledgeGraph.{GraphStore, QueryEngine}
  
  # TODO: Copy full implementation from artifacts
  
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end
  
  def store_block(block) do
    # TODO: Implement block to RDF conversion
    Logger.info("Storing block #{Base.encode16(block.hash)} in RDF store")
    :ok
  end
  
  def store_transaction(transaction) do
    # TODO: Implement transaction to RDF conversion  
    Logger.info("Storing transaction #{Base.encode16(transaction["hash"])} in RDF store")
    :ok
  end
  
  # Delegate queries to GraphStore/QueryEngine
  defdelegate count_entities(), to: QueryEngine
  defdelegate trace_to_origin(product_iri), to: QueryEngine
  defdelegate contamination_impact(batch_iri), to: QueryEngine
  defdelegate get_supply_chain_network(entity_iri), to: QueryEngine
  
  @impl true
  def init(opts) do
    Logger.info("Starting RDF Store")
    {:ok, %{opts: opts}}
  end
  
  @impl true
  def handle_call({:store_block, block}, _from, state) do
    {:reply, store_block(block), state}
  end
  
  @impl true  
  def handle_call({:store_transaction, tx}, _from, state) do
    {:reply, store_transaction(tx), state}
  end
end
EOF

echo "✅ Created RdfStore module"

# สร้าง Storage Manager
cat > lib/prov_chain/storage/manager.ex << 'EOF'
defmodule ProvChain.Storage.Manager do
  @moduledoc """
  Unified storage manager for all persistence layers
  """
  
  alias ProvChain.Storage.{MemoryStore, BlockStore, RdfStore}
  
  def store_block(block) do
    with :ok <- MemoryStore.put_block(block.hash, block),
         :ok <- BlockStore.put_block(block),
         :ok <- RdfStore.store_block(block) do
      :ok
    else
      error -> {:error, error}
    end
  end
  
  def store_transaction(tx) do
    with :ok <- MemoryStore.put_transaction(tx["hash"], tx),
         :ok <- BlockStore.put_transaction(tx),
         :ok <- RdfStore.store_transaction(tx) do
      :ok
    else
      error -> {:error, error}
    end
  end
  
  # Query delegation
  defdelegate trace_to_origin(product_iri), to: RdfStore
  defdelegate contamination_impact(batch_iri), to: RdfStore
  defdelegate get_supply_chain_network(entity_iri), to: RdfStore
end
EOF

echo "✅ Created Storage Manager"

# สร้าง integration test
cat > test/integration/basic_sparql_test.exs << 'EOF'
defmodule ProvChain.Integration.BasicSparqlTest do
  use ExUnit.Case, async: false
  
  alias ProvChain.Storage.{Manager, RdfStore}
  alias ProvChain.Test.ProvOData
  
  setup do
    # Clear all stores
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
    block = ProvChain.BlockDag.Block.new([], [tx], validator, "test", %{})
    
    # Store in all layers
    assert :ok = Manager.store_block(block)
    
    # Verify storage in memory and Mnesia layers
    assert {:ok, _} = ProvChain.Storage.MemoryStore.get_block(block.hash)
    assert {:ok, _} = ProvChain.Storage.BlockStore.get_block(block.hash)
    
    # TODO: Verify RDF storage when fully implemented
  end
end
EOF

echo "✅ Created integration test"

# อัพเดท mix.exs dependencies
echo "📦 Updating mix.exs dependencies..."

# สร้าง backup ของ mix.exs
cp mix.exs mix.exs.backup

# เพิ่ม dependencies ในส่วนท้าย deps function
if ! grep -q ":rdf" mix.exs; then
    # หา deps function และเพิ่ม SPARQL dependencies ก่อน closing bracket
    sed -i.bak '/defp deps do/,/^  end$/{
        /^  end$/{
            i\
      # SPARQL and RDF dependencies (from PoC)\
      {:rdf, "~> 2.0"},\
      {:sparql, "~> 0.3"},\
      {:sparql_client, "~> 0.5"},\
      {:json_ld, "~> 0.3"},\
      \
      # Performance and monitoring\
      {:benchee, "~> 1.3"},\
      {:benchee_html, "~> 1.0"},
        }
    }' mix.exs
    
    rm -f mix.exs.bak
    echo "✅ Added SPARQL dependencies to mix.exs"
else
    echo "⚠️  SPARQL dependencies already exist in mix.exs"
fi

# อัพเดท application.ex
echo "🔧 Updating application.ex..."

if ! grep -q "KnowledgeGraph.GraphStore" lib/prov_chain/application.ex; then
    # เพิ่ม GraphStore ใน children list
    sed -i.bak 's/children = \[/children = [\
      {ProvChain.KnowledgeGraph.GraphStore, []},/' lib/prov_chain/application.ex
    
    rm -f lib/prov_chain/application.ex.bak
    echo "✅ Added GraphStore to application supervision tree"
else
    echo "⚠️  GraphStore already in supervision tree"
fi

# ติดตั้ง dependencies
echo "📦 Installing dependencies..."
mix deps.get

# ทดสอบ compilation
echo "🔧 Testing compilation..."
if mix compile; then
    echo "✅ Compilation successful!"
else
    echo "❌ Compilation failed. Please check errors above."
    exit 1
fi

# ทำความสะอาด
echo "🧹 Cleaning up..."
rm -rf "$TEMP_DIR"

# สรุปผลการทำงาน
echo ""
echo "🎉 SPARQL PoC migration completed successfully!"
echo ""
echo "📋 What was done:"
echo "  ✅ Created knowledge_graph/ directory structure"
echo "  ✅ Copied core SPARQL modules from PoC"
echo "  ✅ Updated module names and namespaces"
echo "  ✅ Created integration modules (RdfStore, Manager)"
echo "  ✅ Added SPARQL dependencies to mix.exs"
echo "  ✅ Updated application supervision tree"
echo "  ✅ Created basic integration tests"
echo ""
echo "📋 Next steps:"
echo "  1. Copy full implementations from provided artifacts"
echo "  2. Run tests: mix test test/integration/basic_sparql_test.exs"
echo "  3. Implement remaining RDF conversion logic"
echo "  4. Run benchmarks: mix run benchmark/sparql_benchmarks.exs"
echo ""
echo "📁 New files created:"
echo "  - lib/prov_chain/knowledge_graph/graph_store.ex"
echo "  - lib/prov_chain/knowledge_graph/query_engine.ex" 
echo "  - lib/prov_chain/knowledge_graph/supply_chain_model.ex"
echo "  - lib/prov_chain/storage/rdf_store.ex"
echo "  - lib/prov_chain/storage/manager.ex"
echo "  - test/knowledge_graph/sparql_integration_test.exs"
echo "  - test/integration/basic_sparql_test.exs"
echo "  - benchmark/sparql_benchmarks.exs"
echo ""
echo "🚀 Ready for SPARQL integration development!"
