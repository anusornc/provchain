import Config

config :provchain,
  dag_storage_path: "data/dev/dag",
  merkle_storage_path: "data/dev/merkle",
  network_port: 4000,
  validator_timeout: 5000

# Configuration of Mnesia
config :mnesia,
  dir: "data/dev/mnesia",
  extra_db_nodes: [],
  extra_db_nodes_timeout: 5000

config :logger,
  level: :debug,
  backends: [:console]
