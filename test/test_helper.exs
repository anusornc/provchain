ExUnit.start()
require Logger

# Load test config
Logger.info("Loading test config")
Application.load(:provchain)
config = Config.Reader.read!("config/test.exs", env: :test)
Enum.each(config, fn {app, opts} -> Application.put_all_env([{app, opts}]) end)

Logger.info(
  "Test config loaded: Cachex default_args: #{inspect(Application.get_env(:cachex, :default_args))}"
)

# Non-distributed node
Logger.debug("Running tests on node #{inspect(node())} (nonode@nohost)")

# Prepare Mnesia directory
mnesia_dir_string = Application.fetch_env!(:mnesia, :dir) |> to_string()
File.rm_rf!(mnesia_dir_string)
File.mkdir_p!(mnesia_dir_string)

# Fresh Mnesia schema
:mnesia.stop()
:ok = :mnesia.delete_schema([node()])
mnesia_dir = to_charlist(mnesia_dir_string)
:application.set_env(:mnesia, :dir, mnesia_dir)
:ok = :mnesia.create_schema([node()])
:ok = :mnesia.start()
:ok = :mnesia.wait_for_tables([:schema], 30_000)

# Start required apps
{:ok, _} = Application.ensure_all_started(:mnesia)
# เริ่ม MemoryStore, application.ex ข้าม BlockStore และ KG.Store
{:ok, _} = Application.ensure_all_started(:provchain)

# Cleanup after suite
ExUnit.after_suite(fn _ ->
  Logger.info("Stopping Mnesia and cleaning temp dir #{mnesia_dir_string}")
  :mnesia.stop()
  File.rm_rf!(mnesia_dir_string)
end)
