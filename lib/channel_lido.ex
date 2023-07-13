defmodule ChannelLido do
  @moduledoc """
  Documentation for `ChannelLido`.
  """

  alias __MODULE__.{Actions, EventsPublisher}

  defdelegate activate(args), to: Actions
  defdelegate check_readiness(args), to: Actions
  defdelegate connection_details(args), to: Actions
  defdelegate deactivate(args), to: Actions
  defdelegate disconnect(args), to: Actions
  defdelegate enrich_settings(args), to: Actions
  defdelegate handle_push(event, data), to: Actions
  defdelegate mapping_details(args), to: Actions
  defdelegate receive_bookings(args), to: Actions
  defdelegate sync_rate_plan(channel_rate_plan, settings), to: Actions
  defdelegate test_connection(args), to: Actions
  defdelegate update_cache(args), to: Actions

  @spec log_action(EventsPublisher.args()) :: EventsPublisher.response()
  def log_action(args) do
    EventsPublisher.publish(args)
  end
end
