import Config

config :provchain,
  dag_storage_path: "data/test/dag",
  merkle_storage_path: "data/test/merkle",
  network_port: 4001,
  validator_timeout: 1000

config :logger,
  level: :warning,
  backends: [:console]
