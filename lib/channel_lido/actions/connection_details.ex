defmodule ChannelLido.Actions.ConnectionDetails do
  @moduledoc false

  @type args :: map()
  @type response :: {:ok, map(), nil} | {:error, term(), nil}

  @doc false
  def perform(_args) do
    {:ok, nil, nil}
  end
end
