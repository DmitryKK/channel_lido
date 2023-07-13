defmodule ChannelLido.Services.HotelInvCountNotif do
  @moduledoc """
  Synchronizes the number of inventory items available for sale.
  """

  alias __MODULE__.{Request, Response}

  @type args() :: map()
  @type response() :: {:ok, term(), struct()} | {:error, term(), struct()}

  @doc false
  def perform(args) do
    args
    |> Request.execute()
    |> Response.parse()
  end
end
