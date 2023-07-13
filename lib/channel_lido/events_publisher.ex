defmodule ChannelLido.EventsPublisher do
  @moduledoc false

  @channel_events_queue "channel_events"

  @type args :: %{action: String.t(), channel_id: term(), result: tuple()}
  @type response :: :ok | {:error, term()}

  @doc "Publishes an event message."
  @spec publish(args()) :: response()
  def publish(message) do
    MessageQueue.publish(message, @channel_events_queue, durable: true, persistent: true)
  end
end
