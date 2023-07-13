defmodule ChannelLido.Actions do
  @moduledoc """
  Actions of the channel necessary for its operational work.
  """

  alias __MODULE__.{
    Activate,
    CheckReadiness,
    ConnectionDetails,
    Deactivate,
    Disconnect,
    EnrichSettings,
    MappingDetails,
    ReceiveBookings,
    SyncRatePlan,
    TestConnection,
    UpdateCache
  }

  alias ChannelLido.Subscriber

  defdelegate handle_push(event, data), to: Subscriber

  @spec activate(Activate.args()) :: Activate.response()
  def activate(args) do
    Activate.perform(args)
  end

  @spec check_readiness(CheckReadiness.args()) :: CheckReadiness.response()
  def check_readiness(args) do
    CheckReadiness.perform(args)
  end

  @spec connection_details(ConnectionDetails.args()) :: ConnectionDetails.response()
  def connection_details(args) do
    ConnectionDetails.perform(args)
  end

  @spec deactivate(Deactivate.args()) :: Deactivate.response()
  def deactivate(args) do
    Deactivate.perform(args)
  end

  @spec disconnect(Disconnect.args()) :: Disconnect.response()
  def disconnect(args) do
    Disconnect.perform(args)
  end

  @spec enrich_settings(EnrichSettings.args()) :: EnrichSettings.response()
  def enrich_settings(args) do
    EnrichSettings.perform(args)
  end

  @spec mapping_details(MappingDetails.args()) :: MappingDetails.response()
  def mapping_details(args) do
    MappingDetails.perform(args)
  end

  @spec receive_bookings(ReceiveBookings.args()) :: ReceiveBookings.response()
  def receive_bookings(args) do
    ReceiveBookings.perform(args)
  end

  @spec sync_rate_plan(SyncRatePlan.channel_rate_plan(), SyncRatePlan.settings()) ::
          SyncRatePlan.response()
  def sync_rate_plan(channel_rate_plan, settings) do
    SyncRatePlan.perform(channel_rate_plan, settings)
  end

  @spec test_connection(TestConnection.args()) :: TestConnection.response()
  def test_connection(args) do
    TestConnection.perform(args)
  end

  @spec update_cache(UpdateCache.args()) :: UpdateCache.response()
  def update_cache(args) do
    UpdateCache.perform(args)
  end
end
