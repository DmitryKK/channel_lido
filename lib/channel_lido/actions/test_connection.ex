defmodule ChannelLido.Actions.TestConnection do
  @moduledoc false

  @type args :: map()
  @type response :: {:ok, term(), term()} | {:error, term(), term()}

  alias ChannelLido.Services

  @doc false
  def perform(args) do
    case Services.hotel_avail(args) do
      {:ok, %{errors: []}, _meta} -> {:ok, nil, nil}
      _error -> {:error, "invalid_credentials", nil}
    end
  end
end
