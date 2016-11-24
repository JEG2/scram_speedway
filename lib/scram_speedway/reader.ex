defmodule ScramSpeedway.Reader do
  use GenServer
  require Logger
  alias ScramSpeedway.Player

  defstruct ~w[socket last_play]a

  @hostname 'speedwayr-10-4e-fa.local'
  @port 14150
  @table %{
    "300833B2DDD9014000000000" => "kaylee",
    "35E0170102000000008A6B05" => "kaylee"
  }

  def start_link do
    GenServer.start_link(__MODULE__, nil)
  end

  def connect(reader) do
    GenServer.cast(reader, :connect)
  end

  def init(nil) do
    connect(self)
    reader = %__MODULE__{last_play: now}
    {:ok, reader}
  end

  def handle_cast(:connect, reader) do
    Logger.debug("Connecting…")
    socket =
      case :gen_tcp.connect(@hostname, @port, [ ]) do
        {:ok, socket} ->
          socket
        _ ->
          :timer.apply_after(500, __MODULE__, :connect, [self])
          nil
      end
    {:noreply, %__MODULE__{reader | socket: socket}}
  end

  def handle_info({:tcp, _socket, read}, reader) do
    [tag_id, _epc] =
      read
      |> to_string
      |> String.split("\n", parts: 2)
      |> hd
      |> String.split(",", parts: 2)
    chip = @table[tag_id]
    new_reader =
      if chip && now - reader.last_play > 5 do
          Logger.info("Detected #{chip}.")
          sound = Path.expand("../../priv/#{chip}.mp3", __DIR__)
          Player.play(sound)
          %__MODULE__{reader | last_play: now}
        else
          Logger.debug("Ignoring #{tag_id}.")
          reader
        end
    {:noreply, reader}
  end
  def handle_info({:tcp_closed, _socket}, reader) do
    connect(self)
    {:noreply, %__MODULE__{reader | socket: nil}}
  end
  def handle_info(message, reader) do
    Logger.debug("Unexpected message:  #{inspect message}")
    {:noreply, reader}
  end

  defp now do
    System.monotonic_time(:seconds)
  end
end
