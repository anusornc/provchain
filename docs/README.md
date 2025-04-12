## Layer Architecture & Libraries

### Current Implementation

| Layer | Component | Libraries | Purpose |
|-------|-----------|-----------|---------|
| **Core Blockchain Layer** | Block-DAG Structure | `libgraph` | Advanced graph data structures |
| | | `jason` | JSON encoding/decoding |
| | PROV-O Ontology | *(custom implementation)* | PROV-O data structure handling |
| | Persistence | `:mnesia` | Distributed database for blocks and transactions |
| | | `:ets` | In-memory storage for caching |
| | Cryptography | `eddy` | ED25519 digital signatures |
| | | `:crypto` | Basic cryptographic functions (SHA-256) |
| **Development & Testing** | Testing | `ex_unit` | Unit testing framework |
| | | `mox` | Mocking library |
| | Monitoring | `telemetry` | Metrics and instrumentation |
| | Documentation | `ex_doc` | Documentation generation |
| | Code Quality | `credo` | Static code analysis |
| | | `dialyxir` | Type checking |

### Planned Architecture (Future)

| Layer | Component | Libraries | Purpose |
|-------|-----------|-----------|---------|
| **Application Layer** | API & Integration | `phoenix` | Web framework for API endpoints |
| | | `absinthe` | GraphQL API support |
| | | `corsica` | CORS management |
| | Data Processing | `nimble_csv` | Fast CSV parsing |
| | | `flow` | Parallel data processing pipeline |
| | | `rdf_ex` | RDF data structure handling |
| | Authentication | `guardian` | JWT authentication |
| | | `comeonin` | Password hashing |
| | Visualization | `vega_lite` | Data visualization for traceability |
| **Core Blockchain Layer** | PROV-O Ontology | `rdf_ex` | RDF data structure handling |
| | | `json_ld_ex` | JSON-LD serialization |
| | | `shex_ex` | Schema validation for PROV-O |
| | Knowledge Graph | `bolt_sips` | Neo4j client |
| | | `sparql_client` | SPARQL query support |
| | | `redix` | Redis client for path caching |
| | Additional Persistence | `exrockdb` | RocksDB for historical blocks |
| | | `nebulex` | Distributed multi-level caching |
| | | `con_cache` | Concurrent caching |
| **Network Layer** | P2P Communication | `libp2p` | Peer-to-peer networking |
| | | `phoenix_pubsub` | PubSub messaging system |
| | | `ex_kademlia` | Distributed hash table |
| | Consensus (PoA) | `ex_raft` | Raft consensus components |
| | | `libcluster` | Automated cluster formation |
| | | `horde` | Distributed supervisor |
| | Cryptography | `x509` | Certificate operations |
| | | `blake2_elixir` | High-performance hashing |
| **Development & Testing** | Testing | `propcheck` | Property-based testing |
| | | `benchee` | Performance benchmarking |
| | | `stream_data` | Data generation for testing |
| | Monitoring | `prometheus_ex` | Prometheus integration |
| | | `logger_file_backend` | Log management |
| | | `wobserver` | Web-based observer |
| **Simulation & Validation** | Supply Chain | `simul_ex` | Supply chain simulation |
| | | `timex` | Time manipulation for testing |
| | Compliance | `hammox` | Behavior validation |
| | | `bureaucrat` | Documentation generation |# Blockchain with DAG Storage, PROV-O & Knowledge Graph for UHT Milk Traceability

## Project Summary

This research project develops an innovative permissioned blockchain system that combines Block-DAG structure with PROV-O ontology and Knowledge Graph technology to create a high-throughput supply chain traceability solution. Using UHT milk production as a practical application case, the system tracks products from farm to consumer while overcoming limitations of traditional blockchain implementations.

The architecture leverages Elixir's concurrency model and combines three powerful paradigms: a specialized Block-DAG structure for high throughput, PROV-O ontology for standardized provenance tracking, and Knowledge Graph technology for efficient traceability queries. The Hybrid PoA consensus with social trust model ensures security while maintaining performance.

Our system aims to surpass existing blockchain solutions like PHANTOM through domain-specific optimizations, sophisticated materialized path strategies, and parallel validation pipelines that leverage Elixir's actor model.

## Current Status

The core foundation of ProvChain has been established, with the following components implemented:

- ✅ Basic project structure and configuration
- ✅ Cryptographic utilities (hashing, signatures, Merkle trees)
- ✅ Block-DAG data structures for dairy supply chain
- ✅ Transaction format with PROV-O entity-activity-agent model
- ✅ Basic persistence layer (Mnesia for disk storage and ETS for in-memory caching)
- ✅ Serialization utilities for data transfer
- ✅ Test utilities for generating realistic supply chain data with PROV-O model

## Development Plan

### Phase 1: Core Architecture & Foundation
- [x] Set up Elixir project structure with dependency management
- [x] Define specialized Block-DAG data structures for dairy supply chain
- [x] Implement transaction format with PROV-O entity-activity-agent model
- [x] Create basic persistence layer with Mnesia and ETS
- [ ] Enhance storage with indexing and query optimization
- [x] Design and implement transaction signing and verification

### Phase 2: PROV-O & Supply Chain Integration
- [x] Develop test utilities for generating realistic supply chain data
- [x] Implement transaction validation with PROV-O structural rules
- [x] Develop explicit transaction linking using PROV-O relationships
- [x] Create specialized Merkle structures for UHT milk traceability
- [ ] Create CSV to PROV-O transformation pipeline with templates for UHT milk events
- [ ] Implement parallel processing for transformation using Elixir concurrency
- [ ] Design full validation rules specific to dairy supply chain transitions
- [ ] Implement edge computing support for resource-constrained participants

### Phase 3: Consensus & Network Layer
- [ ] Implement Hybrid PoA with reputation-weighted validation
- [ ] Develop multi-level vouching system with trust scores
- [ ] Build validator rotation mechanism to prevent centralization
- [ ] Create social trust model with probation period for new validators
- [ ] Implement block propagation optimized for DAG structure
- [ ] Design and implement conflict resolution protocol for DAG consistency

### Phase 4: Query Optimization & Indexing
- [x] Implement basic height and type indexes in Mnesia
- [ ] Add advanced indexing strategies for efficient queries
- [ ] Design and implement efficient block retrieval methods
- [ ] Optimize transaction lookup performance
- [ ] Implement caching strategies for common queries
- [ ] Add support for complex supply chain queries
- [ ] Develop specialized query language for supply chain traceability

### Phase 5: Knowledge Graph Integration
- [ ] ออกแบบและพัฒนาการทำงานร่วมกันระหว่าง Mnesia และ Neo4J
  - [ ] ออกแบบ adapter layer สำหรับเชื่อมต่อระหว่าง Mnesia และ Neo4J
  - [ ] สร้างกระบวนการ ETL สำหรับย้ายข้อมูลจาก Mnesia ไปยัง Neo4J
  - [ ] พัฒนากลไกการซิงค์ข้อมูลแบบ real-time หรือ batch
- [ ] ออกแบบ graph schema สำหรับ Neo4J ที่สอดคล้องกับ PROV-O
  - [ ] กำหนด node types (Entity, Activity, Agent) ตามโมเดล PROV-O
  - [ ] กำหนด relationship types ตามความสัมพันธ์ใน PROV-O
  - [ ] เพิ่ม properties และ indexes สำหรับการค้นหาที่มีประสิทธิภาพ
- [ ] พัฒนา materialized paths สำหรับการค้นหาที่ใช้บ่อย
  - [ ] สร้าง static materialized paths สำหรับเส้นทางการสืบย้อนกลับ (traceability paths)
  - [ ] พัฒนากลไกปรับปรุง paths อัตโนมัติเมื่อข้อมูลเปลี่ยนแปลง
  - [ ] ทำ path versioning เพื่อรองรับการเปลี่ยนแปลงโครงสร้าง
- [ ] พัฒนา query engine สำหรับการค้นหาซับซ้อน
  - [ ] สร้าง query templates สำหรับรูปแบบการค้นหาที่พบบ่อย
  - [ ] พัฒนา query optimizer ที่ใช้ประโยชน์จาก materialized paths
  - [ ] สร้าง cache layer สำหรับผลลัพธ์การค้นหาที่ใช้บ่อย
- [ ] บูรณาการ Neo4J กับระบบ API
  - [ ] สร้าง endpoints สำหรับการค้นหาซับซ้อนผ่าน Neo4J
  - [ ] พัฒนา fallback mechanism ในกรณีที่ Neo4J ไม่สามารถใช้งานได้

### Phase 6: Consumer Interface & Application Layer
- [ ] Implement API for common traceability scenarios
- [ ] Develop farm-to-consumer trace reconstruction algorithm
- [ ] Design consumer-facing visualization interface
- [ ] Create QR code generation and scanning system
- [ ] Implement latency targets for consumer-facing queries
- [ ] Develop mobile application for end-user verification
- [ ] Create dashboard for supply chain participants

### Phase 7: Performance Optimization & Testing
- [x] Implement test suite for core components
- [ ] Benchmark transaction throughput against PHANTOM and Hyperledger
- [ ] Optimize DAG traversal with topology-aware algorithms
- [ ] Implement semantic compression for efficient storage
- [ ] Create synthetic UHT milk supply chain dataset for large-scale testing
- [ ] Conduct stress testing with millions of products
- [ ] Test system resilience with Byzantine behavior simulation
- [ ] Implement anomaly detection for supply chain irregularities

### Phase 8: Compliance & Documentation
- [ ] Verify EU regulation compliance for food traceability
- [ ] Document system architecture and design decisions
- [ ] Create API documentation for system integration
- [ ] Prepare academic paper with methodology and results
- [ ] Document benchmarking results against existing solutions
- [ ] Create demonstration video of UHT milk traceability
- [ ] Develop documentation for industry stakeholders

## Architecture

ProvChain follows a layered architecture:

### Core Components
- **Block-DAG**: Specialized directed acyclic graph structure for high throughput
- **PROV-O Integration**: Standard ontology for provenance tracking
- **Cryptography**: ED25519 signatures (via Eddy) and SHA-256 hashing
- **Storage**: Multi-level persistence with modular backends (see Hybrid Storage Architecture)
- **Serialization**: Utilities for consistent encoding/decoding of complex data structures

### Key Features
- **Milk Supply Chain Tracking**: Complete farm-to-consumer traceability
- **PROV-O Entities**: Structured representation of actors, activities, and entities
- **Explicit Relationships**: Direct linkage between supply chain events using PROV-O relations
- **High Throughput**: DAG structure allows parallel block validation
- **Flexible Indexing**: Height and type indexes for efficient queries
- **Pluggable Storage**: Modular design with multiple storage backends

## Hybrid Storage Architecture

ProvChain ใช้สถาปัตยกรรมแบบ Hybrid Storage ดังนี้:

### Mnesia เป็น Primary Storage
- **บทบาท**: เป็นแหล่งข้อมูลหลัก (Source of Truth) สำหรับบล็อกและธุรกรรมทั้งหมด
- **ข้อดี**: เหมาะกับการทำงานในระบบ Elixir โดยมีคุณสมบัติ distribution และ fault-tolerance ในตัว
- **การใช้งานปัจจุบัน**: จัดเก็บบล็อก, ธุรกรรม, และดัชนีพื้นฐาน (height และ type)

### ETS เป็น In-Memory Cache
- **บทบาท**: เก็บข้อมูลที่เข้าถึงบ่อยในหน่วยความจำเพื่อความเร็ว
- **ข้อดี**: การเข้าถึงข้อมูลที่รวดเร็วมาก, เหมาะสำหรับ tip set และข้อมูลล่าสุด
- **การใช้งานปัจจุบัน**: เก็บบล็อกล่าสุด, ธุรกรรมล่าสุด, และ tip set

### Neo4J เป็น Knowledge Graph Engine (แผนในอนาคต)
- **บทบาท**: ระบบจัดการฐานข้อมูลกราฟสำหรับการค้นหาที่ซับซ้อนและวิเคราะห์เส้นทางในห่วงโซ่อุปทาน
- **ข้อดี**: มีประสิทธิภาพสูงในการค้นหาเส้นทางและความสัมพันธ์ที่ซับซ้อน
- **การเชื่อมโยงกับ Mnesia**: ข้อมูลจะถูกส่งจาก Mnesia ไปยัง Neo4J ด้วยกระบวนการ ETL

### แนวทางการทำงานร่วมกัน
```
+----------------+      +-----------------+      +----------------+
|                |      |                 |      |                |
|      ETS       |<---->|     Mnesia     |----->|     Neo4J      |
| (In-memory)    |      | (Disk Storage) |      | (Graph Engine) |
|                |      |                 |      |                |
+----------------+      +-----------------+      +----------------+
      ^                        ^                        ^
      |                        |                        |
      v                        v                        v
+----------------+      +-----------------+      +----------------+
|   Fast Cache   |      |  Primary Store  |      | Complex Query  |
|    lookups     |      |   operations    |      |    Engine      |
+----------------+      +-----------------+      +----------------+
```

### กระบวนการทำงาน
1. ธุรกรรมและบล็อกใหม่จะถูกบันทึกใน Mnesia เป็นหลัก
2. ข้อมูลที่เข้าถึงบ่อยจะถูกแคชใน ETS
3. Neo4J จะรับข้อมูลผ่านกระบวนการ ETL (แบบ batch หรือ real-time)
4. การค้นหาพื้นฐานจะใช้ ETS และ Mnesia
5. การค้นหาที่ซับซ้อน (เช่น การติดตามย้อนกลับในห่วงโซ่อุปทาน) จะใช้ Neo4J

## Neo4J Integration Examples

### Neo4J Schema สำหรับ PROV-O (แผนในอนาคต)

```cypher
// Entity nodes
CREATE CONSTRAINT entity_id_constraint IF NOT EXISTS ON (e:Entity) ASSERT e.id IS UNIQUE;

// Activity nodes
CREATE CONSTRAINT activity_id_constraint IF NOT EXISTS ON (a:Activity) ASSERT a.id IS UNIQUE;

// Agent nodes
CREATE CONSTRAINT agent_id_constraint IF NOT EXISTS ON (ag:Agent) ASSERT ag.id IS UNIQUE;

// ตัวอย่างการสร้าง nodes และ relationships ตามโมเดล PROV-O
CREATE (batch:Entity {
  id: 'batch:123',
  type: 'MilkBatch',
  volume: 1000.5,
  farm: 'farm:123',
  temperature: 4.2,
  timestamp: 1744420650662
})

CREATE (collection:Activity {
  id: 'collection:123',
  type: 'MilkCollection',
  startTime: 1744420650662,
  endTime: 1744420654262,
  location: 'Farm A Collection Point'
})

CREATE (farmer:Agent {
  id: 'farmer:123',
  type: 'DairyFarmer',
  name: 'John Smith',
  certification: 'organic-123'
})

// สร้างความสัมพันธ์ตาม PROV-O
CREATE (batch)-[:WAS_GENERATED_BY {time: 1744420650662}]->(collection)
CREATE (batch)-[:WAS_ATTRIBUTED_TO {role: 'producer'}]->(farmer)
CREATE (collection)-[:WAS_ASSOCIATED_WITH {role: 'collector'}]->(farmer)
```

### ตัวอย่างโค้ดการเชื่อมต่อ Mnesia กับ Neo4J

```elixir
defmodule ProvChain.KnowledgeGraph.Connector do
  @moduledoc """
  Module สำหรับเชื่อมต่อระหว่าง Mnesia และ Neo4J
  """
  
  use GenServer
  alias ProvChain.Storage.BlockStore
  
  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end
  
  @impl true
  def init(_) do
    # เชื่อมต่อกับ Neo4J
    {:ok, conn} = Bolt.Sips.start_link(url: "bolt://localhost:7687", basic_auth: [username: "neo4j", password: "password"])
    # กำหนด interval สำหรับการทำ ETL batch job
    schedule_etl()
    {:ok, %{conn: conn, last_synced_block: nil}}
  end
  
  @impl true
  def handle_info(:sync_blocks, state) do
    # ดึงบล็อกที่ยังไม่ได้ซิงค์จาก Mnesia และส่งไปยัง Neo4J
    last_synced = state.last_synced_block
    # TODO: ดึงบล็อกใหม่จาก BlockStore
    # TODO: แปลงบล็อกเป็น Cypher queries
    # TODO: ส่ง queries ไปยัง Neo4J
    
    # กำหนดการซิงค์ครั้งถัดไป
    schedule_etl()
    {:noreply, %{state | last_synced_block: "new_last_block"}}
  end
  
  # แปลงบล็อกเป็น Cypher queries
  defp block_to_cypher(block) do
    # สร้าง queries สำหรับทุกธุรกรรมในบล็อก
    Enum.map(block.transactions, &transaction_to_cypher/1)
  end
  
  # แปลงธุรกรรมเป็น Cypher query
  defp transaction_to_cypher(tx) do
    entity = tx["prov:entity"]
    activity = tx["prov:activity"]
    agent = tx["prov:agent"]
    
    # สร้าง query สำหรับสร้าง nodes และ relationships
    """
    MERGE (e:Entity {id: '#{entity["id"]}'}) 
    ON CREATE SET e += $entity_props
    
    MERGE (a:Activity {id: '#{activity["id"]}'})
    ON CREATE SET a += $activity_props
    
    MERGE (ag:Agent {id: '#{agent["id"]}'})
    ON CREATE SET ag += $agent_props
    
    MERGE (e)-[r1:WAS_GENERATED_BY]->(a)
    ON CREATE SET r1 += $gen_props
    
    MERGE (e)-[r2:WAS_ATTRIBUTED_TO]->(ag)
    ON CREATE SET r2 += $attr_props
    
    MERGE (a)-[r3:WAS_ASSOCIATED_WITH]->(ag)
    ON CREATE SET r3 += $assoc_props
    """
  end
  
  # ตั้งเวลาสำหรับการทำ ETL
  defp schedule_etl do
    Process.send_after(self(), :sync_blocks, 60_000) # ทุก 1 นาที
  end
end
```

### ตัวอย่างการค้นหาเส้นทางในห่วงโซ่อุปทานด้วย Neo4J

```elixir
defmodule ProvChain.KnowledgeGraph.TraceabilityQueries do
  @moduledoc """
  Module สำหรับค้นหาข้อมูลเส้นทางในห่วงโซ่อุปทานด้วย Neo4J
  """
  
  alias ProvChain.KnowledgeGraph.Connector
  
  @doc """
  ค้นหาเส้นทางย้อนกลับของผลิตภัณฑ์จากรหัส QR
  """
  def trace_product_history(product_id) do
    query = """
    MATCH path = (product:Entity {id: $product_id})-[:WAS_DERIVED_FROM*]->(source:Entity)
    WHERE NOT (source)-[:WAS_DERIVED_FROM]->()
    WITH nodes(path) as entities
    UNWIND entities as entity
    MATCH (entity)-[:WAS_GENERATED_BY]->(activity)
    MATCH (activity)-[:WAS_ASSOCIATED_WITH]->(agent)
    RETURN entity, activity, agent
    ORDER BY activity.startTime
    """
    
    # ส่ง query ไปยัง Neo4J
    conn = Connector.get_connection()
    Bolt.Sips.query(conn, query, %{product_id: product_id})
  end
  
  @doc """
  ค้นหาผลิตภัณฑ์ทั้งหมดที่ผลิตจากวัตถุดิบที่ระบุ
  """
  def find_products_from_source(source_id) do
    query = """
    MATCH (source:Entity {id: $source_id})<-[:WAS_DERIVED_FROM*]-(product:Entity)
    WHERE product.type = 'PackagedMilk'
    RETURN product
    """
    
    conn = Connector.get_connection()
    Bolt.Sips.query(conn, query, %{source_id: source_id})
  end
  
  @doc """
  ค้นหาผู้มีส่วนร่วมทั้งหมดในห่วงโซ่อุปทานของผลิตภัณฑ์
  """
  def find_supply_chain_participants(product_id) do
    query = """
    MATCH (product:Entity {id: $product_id})-[:WAS_DERIVED_FROM*]->(source:Entity)
    WITH product, collect(source) as sources
    UNWIND [product] + sources as entity
    MATCH (entity)-[:WAS_ATTRIBUTED_TO]->(agent)
    RETURN DISTINCT agent
    """
    
    conn = Connector.get_connection()
    Bolt.Sips.query(conn, query, %{product_id: product_id})
  end
end
```

## Current Implementation

### Block Structure
```elixir
defstruct [
  :hash,            # Block hash
  :prev_hashes,     # Previous block hashes (DAG structure)
  :timestamp,       # Block creation time
  :height,          # Block height
  :validator,       # Block validator public key
  :signature,       # Validator signature
  :transactions,    # List of transactions
  :merkle_root,     # Merkle root of transactions
  :supply_chain_type, # Type of supply chain event
  :dag_weight,      # Block weight in DAG
  :metadata         # Additional metadata
]
```

### Transaction Structure
The transaction format follows the PROV-O model with:
- Entity: Represents physical objects (milk batch, package, etc.)
- Activity: Represents actions (collection, processing, etc.)
- Agent: Represents participants (farmer, processor, etc.)
- Relations: PROV-O relationships between entities, activities, and agents

### Storage
- Block storage using Mnesia with height and type indexes
- In-memory caching with ETS for recently accessed blocks and tip set
- Serialization for both binary and JSON formats

## Usage

Currently in development - API and usage examples will be provided as the project progresses.

## Dependencies

- **Core**
  - `libgraph` - Graph data structures
  - `jason` - JSON encoding/decoding
  - `eddy` - ED25519 cryptography
  - `:mnesia` - Distributed database system (built-in with Erlang/OTP)
  - `:ets` - In-memory storage (built-in with Erlang/OTP)

- **Future (Neo4J Integration)**
  - `bolt_sips` - Neo4J client for Elixir
  - `crontab` - Scheduler for ETL jobs
  - `flow` - Concurrent data processing pipeline

## Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/provchain.git
cd provchain

# Get dependencies
mix deps.get

# Compile
mix compile

# Run tests
mix test
```

## Configuration

ProvChain สามารถปรับแต่งผ่านไฟล์ config โดยมีค่า configuration ดังนี้:

```elixir
# config/dev.exs
import Config

config :provchain,
  dag_storage_path: "data/dev/dag",
  merkle_storage_path: "data/dev/merkle",
  network_port: 4000,
  validator_timeout: 5000

# สำหรับการเชื่อมต่อกับ Neo4J (จะเพิ่มในอนาคต)
config :bolt_sips,
  url: System.get_env("NEO4J_URL", "bolt://localhost:7687"),
  basic_auth: [
    username: System.get_env("NEO4J_USERNAME", "neo4j"),
    password: System.get_env("NEO4J_PASSWORD", "password")
  ]
```

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Contributors

Project maintainers and contact information will be added as the project progresses.