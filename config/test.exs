# config/test.exs
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
  extra_db_nodes_timeout: 5000,
  access: :read_write,
  dump_log_write_threshold: 1000

config :logger,
  level: :debug,
  backends: [:console]

config :cachex,
  default_args: [stats: true],
  stats: true

# Require Logger for macro usage
require Logger

# Log to confirm config loading
Logger.info("Loaded test config with Cachex stats: #{inspect(Application.get_env(:cachex, :default_args))}")
