# โมดูลช่วยเหลือสำหรับ IEx
defmodule ProvChainIExHelpers do
  def safe_exit do
    IO.puts("Safely shutting down...")

    # ปิด Mnesia โดยตรง
    if :erlang.function_exported(:mnesia, :system_info, 1) and
       :mnesia.system_info(:is_running) == :yes do
      IO.puts("Stopping Mnesia directly...")
      :mnesia.stop()
      # รอแค่เล็กน้อย
      Process.sleep(200)
      IO.puts("Mnesia stopped")
    end

    # ออกจาก IEx โดยตรง
    IO.puts("Exiting IEx immediately...")
    :erlang.halt(0)
  end
end

# นำฟังก์ชันมาใช้โดยตรง
import ProvChainIExHelpers

IO.puts("\nWelcome to ProvChain IEx session!")
IO.puts("Type 'safe_exit' to safely shutdown Mnesia and exit IEx.\n")
