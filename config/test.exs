import Config

config :provchain,
  dag_storage_path: "data/test/dag",
  merkle_storage_path: "data/test/merkle",
  network_port: 4001,
  validator_timeout: 1000

# Configuration of Mnesia
config :mnesia,
  dir: "data/test/mnesia",
  extra_db_nodes: [],
  extra_db_nodes_timeout: 5000

config :logger,
  level: :warning,
  backends: [:console]
