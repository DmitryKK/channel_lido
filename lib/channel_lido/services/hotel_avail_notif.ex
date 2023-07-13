defmodule ChannelLido.Services.HotelAvailNotif do
  @moduledoc """
  Communicates minimum length of stay requirements, the close out flag, and
  closed to arrival restrictions.
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
