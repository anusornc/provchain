defmodule ProvChain.Helpers.MnesiaHelper do
  @moduledoc """
  Helper utilities for Mnesia database management in ProvChain.

  This module provides functions for safely managing the Mnesia database:
  - Safely shutting down Mnesia to prevent data corruption
  - Checking schema integrity and repairing when necessary
  - Creating backups before schema modifications
  - Recovery mechanisms for damaged schema

  These utilities ensure data durability and system robustness when using
  Mnesia for persistent storage.
  """
  require Logger

  @doc """
  ปิด Mnesia อย่างปลอดภัย
  """
  def safe_shutdown do
    Logger.info("กำลังปิด Mnesia อย่างปลอดภัย")

    # ปิด applications ที่อาจใช้ Mnesia อยู่
    Application.stop(:provchain)

    # ปิด Mnesia อย่างปลอดภัย
    :mnesia.stop()

    # รอให้ข้อมูลถูกบันทึกลงดิสก์
    Process.sleep(1000)

    :ok
  end

  @doc """
  ตรวจสอบว่า Mnesia schema เสียหายหรือไม่ และซ่อมแซมหากจำเป็น
  """
  def check_and_repair do
    case :mnesia.system_info(:is_running) do
      :yes ->
        # ลองทำ transaction เพื่อตรวจสอบความสมบูรณ์
        case :mnesia.transaction(fn -> :ok end) do
          {:atomic, :ok} ->
            Logger.info("Mnesia schema ทำงานได้ปกติ")
            :ok

          {:aborted, reason} ->
            Logger.error("Mnesia schema เสียหาย: #{inspect(reason)}")
            recover_schema()
        end

      _ ->
        Logger.warning("Mnesia ไม่ได้ทำงาน จะเริ่มต้นใหม่...")
        :mnesia.start()
        check_and_repair()
    end
  end

  defp recover_schema do
    Logger.warning("กำลังพยายามกู้คืน Mnesia schema")
    mnesia_dir = Application.get_env(:mnesia, :dir) |> to_string()

    :mnesia.stop()
    Process.sleep(1000)

    # สำรองข้อมูลเก่าก่อนสร้างใหม่
    backup_dir = "#{mnesia_dir}_backup_#{System.system_time(:second)}"
    File.mkdir_p!(backup_dir)
    File.cp_r(mnesia_dir, backup_dir)

    # สร้าง schema ใหม่
    :mnesia.delete_schema([node()])
    :mnesia.create_schema([node()])
    :mnesia.start()

    Logger.info("Schema กู้คืนแล้ว จะต้องสร้างตารางใหม่")
    :ok
  end
end
