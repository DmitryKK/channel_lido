defmodule ChannelLido.Services.HotelRateAmountNotif do
  @moduledoc """
  Transmits new rates and changes to existing rates.
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
