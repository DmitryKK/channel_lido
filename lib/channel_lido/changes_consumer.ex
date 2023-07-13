defmodule ChannelLido.ChangesConsumer do
  @moduledoc false

  use Broadway

  require Logger

  alias Broadway.Message
  alias ChannelLido.Actions.Sync
  alias ChannelLido.ChannelsCache

  @channel_name "Lido"
  @queue "channel_lido.changes"
  @batch_timeout :timer.seconds(5)
  @concurrency 20

  @doc false
  def start_link(_args) do
    Broadway.start_link(__MODULE__,
      name: __MODULE__,
      producer: [
        module:
          {producer(),
           queue: @queue,
           declare: [durable: true],
           bindings: [{"changes", [arguments: binding_arguments()]}],
           connection: connection(),
           on_failure: :reject_and_requeue,
           qos: [prefetch_count: @concurrency],
           metadata: [:delivery_tag]},
        concurrency: 1
      ],
      processors: [
        default: [concurrency: @concurrency, max_demand: 1]
      ],
      batchers: [
        default: [
          batch_size: 10,
          batch_timeout: @batch_timeout,
          concurrency: @concurrency,
          partition_by: &partition_by_batch_key/1
        ],
        discarded: [batch_size: 3, batch_timeout: @batch_timeout, concurrency: 1]
      ]
    )
  end

  @impl true
  def handle_message(:default, message, _context) do
    message
    |> Message.update_data(&decode_data/1)
    |> put_batcher()
  end

  @impl true
  def handle_batch(:default, messages, _batch_info, _context) do
    messages
    |> Enum.sort_by(&message_sorter/1)
    |> Stream.map(&handle_payload(&1.data))
    |> Stream.run()

    messages
  end

  def handle_batch(:discarded, messages, _batch_info, _context) do
    messages
  end

  defp partition_by_batch_key(message) do
    :erlang.phash2(message.batch_key)
  end

  defp handle_payload(%{channels: channels, changes: changes}) do
    sync_channels(channels, changes)
  end

  defp decode_data(data) when is_binary(data) do
    case MessageQueue.decode_data(data, parser_opts: [keys: :atoms]) do
      {:ok, payload} -> payload
      _ -> {:invalid_payload, data}
    end
  end

  defp put_batcher(%{data: %{changes: []}} = message) do
    Message.put_batcher(message, :discarded)
  end

  defp put_batcher(%{data: {:invalid_payload, data}} = message) do
    Logger.error("[#{@channel_name}] ChangesConsumer invalid payload: #{inspect(data)}")
    Message.put_batcher(message, :discarded)
  end

  defp put_batcher(%{data: %{event: :channel_updated, channel: channel}} = message) do
    ChannelLido.update_cache(channel)
    Message.put_batcher(message, :discarded)
  end

  defp put_batcher(message) do
    case get_channels(message.data) do
      {:error, :invalid_channel} -> Message.put_batcher(message, :discarded)
      {:error, :invalid_payload} -> Message.put_batcher(message, :discarded)
      {:error, :no_connected_channels} -> Message.put_batcher(message, :discarded)
      {:ok, channels} -> update_with_batch_key(message, channels)
    end
  end

  defp update_with_batch_key(message, channels) do
    batch_key = compose_batch_key(channels)

    message
    |> Message.update_data(&Map.put(&1, :channels, channels))
    |> Message.put_batch_key(batch_key)
  end

  defp message_sorter(%{metadata: metadata}), do: metadata[:delivery_tag]

  defp get_channels(%{property_id: property_id}) do
    case ChannelsCache.get_channels(property_id) do
      {:ok, []} -> {:error, :no_connected_channels}
      {:ok, channels} -> {:ok, prepare_channels(channels, property_id)}
      {:error, _} -> {:error, :no_connected_channels}
    end
  end

  defp get_channels(%{channel_id: channel_id}) do
    case ChannelsCache.get(channel_id) do
      {:ok, nil} -> {:error, :no_connected_channels}
      {:ok, channel} -> prepare_channel(channel)
      {:error, _} -> {:error, :no_connected_channels}
    end
  end

  defp get_channels(_payload), do: {:error, :invalid_payload}

  defp prepare_channel(channel) do
    if valid_channel?(channel) do
      {:ok, channel |> compose_channel_data() |> List.wrap()}
    else
      {:error, :invalid_channel}
    end
  end

  defp prepare_channels(channels, property_id) do
    for channel <- channels, valid_channel?(channel) do
      compose_channel_data(channel, property_id)
    end
  end

  defp sync_channels(channels, changes) do
    Enum.each(channels, &Sync.perform(&1, changes))
  end

  defp binding_arguments do
    [{@channel_name, true}, {"x-match", "any"}]
  end

  defp valid_channel?(%{channel: @channel_name, is_active: true}), do: true
  defp valid_channel?(_channel), do: false

  defp compose_channel_data(channel, property_id \\ nil) do
    channel
    |> Map.take([:id])
    |> Map.put(:property_id, get_property_id(channel.properties, property_id))
    |> Map.put(:timezone, compose_timezone(channel.properties))
  end

  defp get_property_id([%{id: property_id}], nil), do: property_id
  defp get_property_id(_properties, property_id), do: property_id

  defp compose_timezone([%{timezone: timezone}]), do: timezone

  defp compose_batch_key(channels) when is_list(channels), do: Enum.map(channels, & &1.id)
  defp compose_batch_key(channel) when is_map_key(channel, :id), do: [channel.id]

  defp connection, do: Application.fetch_env!(:channel_lido, :rmq_connection)
  defp producer, do: Application.fetch_env!(:channel_lido, :broadway_producer_module)
end
