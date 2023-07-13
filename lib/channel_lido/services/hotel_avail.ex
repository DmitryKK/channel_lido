defmodule ChannelLido.Services.HotelAvail do
  @moduledoc """
  Get general information about a hotel.
  """

  alias __MODULE__.{Request, Response}

  @type args() :: %{hotel_id: String.t()}
  @type response() :: {:ok, map(), struct()} | {:error, %{errors: list()}, struct()}

  @doc false
  def perform(args) do
    args
    |> Request.execute()
    |> Response.parse()
  end
end
