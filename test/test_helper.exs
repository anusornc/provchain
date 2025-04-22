# test/test_helper.exs
# Updated: 2025-04-21 to fix Cachex Config: nil issue
# ------------------------------------------------------------
# Helper for ProvChain test suite (non-distributed mode):
# – Uses local node (:nonode@nohost) – no Node.start call
# – Creates a fresh Mnesia schema in configured dir
# – Boots the application under test
# – Cleans up after tests
# ------------------------------------------------------------

ExUnit.start()
require Logger

# Force load config/test.exs before any application code
Logger.info("Loading test config before application start")
Application.load(:provchain)
config = Config.Reader.read!("config/test.exs", env: :test)
Enum.each(config, fn {app, opts} -> Application.put_all_env([{app, opts}]) end)

# Log to confirm config loading
Logger.info("Test config loaded: Cachex default_args: #{inspect(Application.get_env(:cachex, :default_args))}")

# 1) Non-distributed: no Node.start/2 call -> node() remains :nonode@nohost
Logger.debug("Running tests on node #{inspect(node())} (nonode@nohost)")

# 2) Prepare Mnesia directory from config
mnesia_dir_string = Application.fetch_env!(:mnesia, :dir) |> to_string()
File.rm_rf!(mnesia_dir_string)
File.mkdir_p!(mnesia_dir_string)

# 3) Fresh Mnesia schema
_mnesia_stop_result = :mnesia.stop()
:ok = :mnesia.delete_schema([node()])

# Convert string dir to charlist for Erlang
mnesia_dir = to_charlist(mnesia_dir_string)
:application.set_env(:mnesia, :dir, mnesia_dir)

:ok = :mnesia.create_schema([node()])
:ok = :mnesia.start()
:ok = :mnesia.wait_for_tables([:schema], 30_000)

# 4) Start the ProvChain application
{:ok, _} = Application.ensure_all_started(:provchain)

# 5) Cleanup after suite
ExUnit.after_suite(fn _ ->
  Logger.info("Stopping Mnesia and cleaning temp dir #{mnesia_dir_string}")
  :mnesia.stop()
  File.rm_rf!(mnesia_dir_string)
end)
