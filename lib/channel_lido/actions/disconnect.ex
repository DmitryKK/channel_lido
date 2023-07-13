defmodule ChannelLido.Actions.Disconnect do
  @moduledoc false

  @type args :: map()
  @type response :: {:ok, term(), term()} | {:error, term(), term()}

  @doc false
  def perform(_args) do
    {:ok, true}
  end
end
