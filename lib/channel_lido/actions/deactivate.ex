defmodule ChannelLido.Actions.Deactivate do
  @moduledoc false

  @type args :: map()
  @type response :: {:ok, term(), term()} | {:error, term(), term()}

  alias ChannelLido.ChannelsCache

  @doc false
  def perform(channel) do
    with :ok <- ChannelsCache.remove(channel) do
      {:ok, nil, nil}
    end
  end
end
