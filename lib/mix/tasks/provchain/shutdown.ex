# ใน lib/mix/tasks/provchain/shutdown.ex
defmodule Mix.Tasks.Provchain.Shutdown do
  @moduledoc """
  Mix task for safely shutting down the Mnesia database.

  This task ensures proper shutdown of Mnesia to prevent data corruption,
  allowing for graceful termination of the application's persistent storage.
  Usage: `mix provchain.shutdown`
  """
  use Mix.Task

  @shortdoc "Safely shutdown Mnesia"
  def run(_) do
    # เริ่มต้น application
    Application.load(:mnesia)

    # ถ้า Mnesia รันอยู่ ให้ปิด
    if :mnesia.system_info(:is_running) == :yes do
      IO.puts("Stopping Mnesia...")
      :mnesia.stop()
      Process.sleep(200)
      IO.puts("Mnesia stopped")
    else
      IO.puts("Mnesia is not running")
    end

    IO.puts("Shutdown completed")
  end
end
