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
  extra_db_nodes_timeout: 5000,
  # บันทึกลงดิสก์ทุก 30 วินาที
  dump_log_time_threshold: 30000,
  # บันทึกหลังเขียนข้อมูล 10,000 รายการ
  dump_log_write_threshold: 10000,
  # พยายามซ่อมแซมอัตโนมัติ
  auto_repair: true

config :logger,
  level: :debug,
  backends: [:console]

config :cachex,
  default_args: [stats: true],
  stats: true
