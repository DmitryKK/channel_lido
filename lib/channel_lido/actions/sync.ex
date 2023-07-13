defmodule ChannelLido.Actions.Sync do
  @moduledoc false

  require Logger

  alias ChannelLido.{ChangesConverter, ChannelsCache}
  alias ChannelLido.DTO.Meta
  alias ChannelLido.Services.{HotelAvailNotif, HotelInvCountNotif, HotelRateAmountNotif}

  @message_types [:rate_amount_notif]

  @doc false
  def perform(channel_data, changes) do
    case ChannelsCache.get(channel_data.id) do
      {:ok, nil} ->
        Logger.debug("Channel #{channel_data.id} is disapeared from cache. Skipping sync.")

      {:ok, channel} ->
        channel
        |> compose_channel_data(channel_data)
        |> ChangesConverter.convert(changes)
        |> stream_requests()
    end
  end

  defp compose_channel_data(channel, channel_data) do
    channel
    |> Map.take([:channel_rate_plans, :rate_plans, :settings])
    |> Map.merge(channel_data)
  end

  defp stream_requests(args) do
    args.changes
    |> Stream.chunk_every(sync_chunk_size())
    |> Stream.map(&perform_requests(&1, args))
    |> Stream.run()
  end

  defp perform_requests(changes, args) do
    for message_type <- @message_types do
      message_type
      |> perform_request(%{args | changes: changes})
      |> handle_response(message_type)
      |> log_response(args.channel_id)
    end
  end

  defp perform_request(:avail_notif, args), do: HotelAvailNotif.perform(args)
  defp perform_request(:inv_count_notif, args), do: HotelInvCountNotif.perform(args)
  defp perform_request(:rate_amount_notif, args), do: HotelRateAmountNotif.perform(args)

  defp handle_response({:ok, :no_changes, nil}, _message_type), do: :ok

  defp handle_response({res, result, meta}, message_type) do
    {res, result, update_meta(meta, result, message_type)}
  end

  defp log_response(:ok, _channel_id), do: :ok

  defp log_response({_res, result, meta} = response, channel_id) do
    meta
    |> Map.take([:method, :status_code, :finished_at])
    |> Map.merge(%{channel_id: channel_id, result: result})
    |> Logger.info()

    message = %{action: "sync", channel_id: channel_id, result: response}
    :ok = ChannelLido.log_action(message)
  end

  defp update_meta(meta, result, message_type) do
    meta
    |> Meta.update(method: get_method(message_type))
    |> add_warnings(result)
  end

  defp add_warnings(meta, %{warnings: [_ | _] = warnings}) do
    Meta.update(meta, warnings: warnings ++ meta.warnings)
  end

  defp add_warnings(meta, _result), do: meta

  defp get_method(:avail_notif), do: "OTA_HotelAvailNotif"
  defp get_method(:inv_count_notif), do: "OTA_HotelInvCountNotif"
  defp get_method(:rate_amount_notif), do: "OTA_HotelRateAmountNotif"

  defp sync_chunk_size, do: Application.fetch_env!(:channel_lido, :sync_chunk_size)
end
