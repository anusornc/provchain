defmodule ProvChain.Application do
  use Application
  require Logger

  @impl true
  def start(_type, _args) do
    # เตรียม Mnesia ให้พร้อมใช้งาน
    ensure_mnesia_ready()

    Logger.info("Starting ProvChain Application")

    children = [
      {ProvChain.Storage.BlockStore, []},
      {ProvChain.Storage.MemoryStore, []},
      {ProvChain.Storage.RdfStore, []}
      # ลบ GraphStore ออกเพราะมันไม่ใช่ GenServer
    ]

    opts = [strategy: :one_for_one, name: ProvChain.Supervisor]
    Supervisor.start_link(children, opts)
  end

  @impl true
  def stop(_state) do
    # ตรวจสอบและปิด Mnesia อย่างปลอดภัย
    case :mnesia.system_info(:is_running) do
      :yes ->
        Logger.info("กำลังปิด Mnesia อย่างปลอดภัย")
        :mnesia.stop()
        # รอเพื่อให้มีเวลาปิดอย่างสมบูรณ์
        Process.sleep(1000)
      _ -> :ok
    end
    :ok
  end

  defp ensure_mnesia_ready do
    mnesia_dir = Application.get_env(:mnesia, :dir) |> to_string()
    Logger.info("กำลังเตรียม Mnesia ใน #{mnesia_dir}")

    # สร้างไดเรกทอรีหากยังไม่มี
    File.mkdir_p!(mnesia_dir)

    # เริ่ม Mnesia
    case :mnesia.start() do
      :ok ->
        Logger.info("Mnesia เริ่มต้นสำเร็จ")
        ProvChain.Helpers.MnesiaHelper.check_and_repair()
      {:error, {:already_started, _}} ->
        Logger.info("Mnesia กำลังทำงานอยู่แล้ว")
        ProvChain.Helpers.MnesiaHelper.check_and_repair()
      {:error, reason} ->
        Logger.error("ไม่สามารถเริ่ม Mnesia: #{inspect(reason)}")
        Logger.warning("กำลังพยายามสร้าง schema ใหม่")
        :mnesia.stop()
        :mnesia.delete_schema([node()])
        :mnesia.create_schema([node()])
        :mnesia.start()
    end
  end
end
