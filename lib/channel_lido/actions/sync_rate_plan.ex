defmodule ChannelLido.Actions.SyncRatePlan do
  @moduledoc false

  @type channel_rate_plan :: map()
  @type settings :: map()
  @type response :: {:ok, term(), term()} | {:error, term(), term()}

  @doc false
  def perform(_channel_rate_plan, _settings) do
    {:ok, nil, nil}
  end
end
