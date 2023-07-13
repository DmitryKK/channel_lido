defmodule ChannelLido.Actions.UpdateCache do
  @moduledoc false

  @type args :: map()
  @type response :: {:ok, term()} | {:error, term()}

  alias ChannelLido.ChannelsCache

  @doc false
  def perform(channel) do
    with :ok <- ChannelsCache.update(channel) do
      {:ok, true}
    end
  end
end
