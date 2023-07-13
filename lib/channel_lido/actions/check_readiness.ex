defmodule ChannelLido.Actions.CheckReadiness do
  @moduledoc false

  @type args() :: map()
  @type response() :: {:ok, true} | {:error, %{ID.t() => list(atom())}}

  @doc false
  def perform(_args) do
    {:ok, true}
  end
end
