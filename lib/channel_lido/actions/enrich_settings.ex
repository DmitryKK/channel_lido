defmodule ChannelLido.Actions.EnrichSettings do
  @moduledoc false

  @type args :: map()
  @type response :: {:ok, map()}

  @doc false
  def perform(args) do
    {:ok, args}
  end
end
