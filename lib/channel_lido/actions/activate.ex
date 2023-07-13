defmodule ChannelLido.Actions.Activate do
  @moduledoc false

  require Logger

  @type args() :: map()
  @type response() :: {:ok, term(), term()} | {:error, term(), term()}

  alias ChannelLido.ChannelsCache

  @doc false
  def perform(channel) do
    with :ok <- ChannelsCache.update(channel) do
      {:ok, nil, nil}
    end
  end
end
