# ProvChain

ProvChain is an innovative permissioned blockchain system that combines Block-DAG structure with PROV-O ontology and Knowledge Graph technology to create a high-throughput supply chain traceability solution. Using UHT milk production as a practical application case, the system tracks products from farm to consumer while overcoming limitations of traditional blockchain implementations.

## Architecture

The architecture leverages Elixir's concurrency model and combines three powerful paradigms:

1. **Specialized Block-DAG Structure**: A directed acyclic graph of blocks for high throughput and performance
2. **PROV-O Ontology**: Standardized provenance tracking using the W3C PROV-O model
3. **Knowledge Graph Technology**: Efficient traceability queries using graph-based data representation

The system includes a Hybrid Proof of Authority (PoA) consensus with a social trust model to ensure security while maintaining performance.

## Features

- High-throughput blockchain designed for supply chain tracking
- PROV-O compliant data model for standardized provenance tracking
- Complete farm-to-consumer traceability for dairy products
- Adaptive block referencing for optimized performance
- Knowledge graph-based query system for efficient traceability
- Designed for the specific requirements of UHT milk supply chains

## Project Structure

```
lib/
├── prov_chain/
│   ├── application.ex          # Application supervisor
│   ├── block_dag/              # Block-DAG structures
│   │   └── block.ex            # Block structure
│   ├── crypto/                 # Cryptography
│   │   ├── hash.ex             # Hashing functions
│   │   └── signature.ex        # Transaction signing
│   └── utils/                  # Utilities
│       └── serialization.ex    # Data serialization
├── prov_chain.ex               # Main module
```

## Installation

```bash
# Clone the repository
git clone https://github.com/yourusername/provchain.git
cd provchain

# Install dependencies
mix deps.get

# Compile the project
mix compile
```

## Development

ProvChain is built with Elixir 1.18+ and uses a variety of libraries for blockchain operations, cryptography, and data storage.

### Requirements

- Elixir 1.18+
- Erlang OTP 26+
- Optional: Neo4j for Knowledge Graph queries

### Testing

```bash
# Run all tests
mix test

# Run specific test files
mix test test/block_dag/block_test.exs

# Run tests with detailed output
mix test --trace
```

## Development Plan

The project is being developed in several phases:

### Phase 1: Core Architecture & Foundation
- [x] Set up Elixir project structure with dependency management
- [x] Define specialized Block-DAG data structures for dairy supply chain
- [x] Create serialization utilities
- [x] Implement basic cryptographic utilities
- [x] Design PROV-O data model for UHT milk supply chain
- [ ] Implement transaction format with PROV-O entity-activity-agent model
- [ ] Create hybrid persistence layer (ETS/DETS + RocksDB + Neo4j)
- [ ] Develop adaptive block referencing mechanism with multi-level structure
- [ ] Complete transaction signing and verification

### Phase 2: PROV-O & Supply Chain Integration
- [ ] Create CSV to PROV-O transformation pipeline with templates for UHT milk events
- [ ] Implement parallel processing for transformation using Elixir concurrency
- [ ] Design validation rules specific to dairy supply chain transitions
- [ ] Develop explicit transaction linking using PROV-O relationships
- [ ] Create specialized Merkle structures for UHT milk traceability
- [ ] Implement edge computing support for resource-constrained participants

### Phase 3: Consensus & Network Layer
- [ ] Implement Hybrid PoA with reputation-weighted validation
- [ ] Develop multi-level vouching system with trust scores
- [ ] Build validator rotation mechanism to prevent centralization
- [ ] Create social trust model with probation period for new validators
- [ ] Implement block propagation optimized for DAG structure
- [ ] Design and implement conflict resolution protocol for DAG consistency

### Phase 4-7: Knowledge Graph, Query Optimization, Performance, Compliance
See full development plan for details on these phases.

## Acknowledgements

This project aims to surpass existing blockchain solutions like PHANTOM through domain-specific optimizations, sophisticated materialized path strategies, and parallel validation pipelines that leverage Elixir's actor model.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.