defmodule ChannelLido.Actions.PushBookings do
  @moduledoc false

  require Logger

  alias ChannelLido.DTO.Meta
  alias ChannelLido.Errors.SystemError

  @bookings_queue "bookings"

  @callback process({:ok, BookingMessage.t()} | {:error, map()}) ::
              {:ok, BookingMessage.t()} | {:error, map()}

  @doc false
  def process({:ok, bms}) do
    started_at = NaiveDateTime.utc_now()
    publish_options = prepare_publish_options()
    :ok = MessageQueue.publish(bms, @bookings_queue, publish_options)
    log_action(bms, started_at)
    {:ok, bms}
  rescue
    exception ->
      error = Exception.message(exception)
      metadata = %{payload: bms, error: error}
      Logger.debug(ctx: __MODULE__, bms: bms.unique_id, error: error)
      SystemError.new(__MODULE__, metadata, __STACKTRACE__)
      {:error, %{error: :publish_error, meta: bms.meta}}
  end

  def process({:error, error} = error_response) do
    Logger.debug(ctx: __MODULE__, error: error)
    error_response
  end

  defp log_action(bms, started_at) do
    Logger.debug(ctx: __MODULE__, bms: bms.unique_id)
    result = {:ok, bms, prepare_meta(bms, started_at)}
    message = %{action: "push_booking", channel_id: bms.channel_id, result: result}
    :ok = ChannelLido.log_action(message)
  end

  defp prepare_meta(bms, started_at) do
    %{}
    |> Map.put(:request, bms.raw_message)
    |> Map.put(:response, %{result: "Success"})
    |> Map.put(:started_at, started_at)
    |> Map.put(:finished_at, NaiveDateTime.utc_now())
    |> Meta.new()
  end

  defp prepare_publish_options do
    [
      durable: true,
      persistent: true,
      arguments: [
        {"x-dead-letter-exchange", :longstr, ""},
        {"x-dead-letter-routing-key", :longstr, @bookings_queue <> ".errors"}
      ]
    ]
  end
end
