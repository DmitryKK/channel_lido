defmodule ChannelLido.Errors.SystemError do
  @moduledoc """
  System Error definition
  """

  use ChannelLido.Errors

  def new(message, meta, stacktrace, env) when env in [:dev, :test] do
    __MODULE__
    |> struct(code: :sytem_error, message: message, meta: meta, stacktrace: stacktrace)
    |> message()
    |> Logger.error()
  end
end
