defmodule ChannelLido.Actions.ReceiveBookings do
  @moduledoc false

  alias __MODULE__.{Request, Response}
  alias ChannelLido.MessageConverter

  @type args() :: %{body: String.t(), headers: keyword()}
  @type response() :: {:ok, :render, tuple()}

  @doc false
  def perform(args) do
    args
    |> Request.parse()
    |> MessageConverter.convert()
    |> booking_processor().process()
    |> Response.format()
  end

  defp booking_processor do
    Application.fetch_env!(:channel_lido, :booking_processor)
  end
end
