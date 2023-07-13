defmodule ChannelLido.ChannelsCache do
  @moduledoc """
  Channels Cache for ChannelLido connection.
  """

  use GenServer

  require Logger

  alias ChannelLido.DTO.CachedChannel

  @module_name inspect(__MODULE__)
  @channels_table Module.concat(__MODULE__, Channels)
  @properties_table Module.concat(__MODULE__, Properties)

  @doc """
  Get channels from cache by id or list of ids
  """
  @spec get(term() | list(term())) :: {:ok, list(struct()) | nil} | {:error, :invalid_arguments}
  def get(id) when is_binary(id) do
    case :ets.lookup(@channels_table, id) do
      [{_, _, channel}] -> {:ok, channel}
      [] -> {:ok, nil}
    end
  end

  def get([]), do: {:ok, []}

  def get(ids) when is_list(ids) do
    id_condition = Enum.map(ids, fn id -> {:==, :"$1", id} end)
    condition = List.to_tuple([:or] ++ id_condition)
    {:ok, :ets.select(@channels_table, [{{:"$1", :_, :"$3"}, [condition], [:_, :_, :"$3"]}])}
  end

  def get(_), do: {:error, :invalid_arguments}

  @doc """
  Get channels from cache by property_id
  """
  @spec get_channels(term()) :: {:ok, list(struct())} | {:error, :invalid_arguments}
  def get_channels(property_id) when is_binary(property_id) do
    case :ets.lookup(@properties_table, property_id) do
      [{_, channels}] -> {:ok, channels}
      [] -> {:ok, []}
    end
  end

  def get_channels(_), do: {:error, :invalid_arguments}

  @doc """
  Get all channels.
  """
  @spec all() :: {:ok, list(struct())}
  def all do
    match_spec = [{{:"$1", :"$2", :"$3"}, [], [:"$3"]}]
    {:ok, :ets.select(@channels_table, match_spec)}
  end

  @doc """
  Get all channels by hotel_id.
  """
  @spec all(String.t()) :: {:ok, list(struct())}
  def all(hotel_id) do
    match_spec = [{{:"$1", :"$2", :"$3"}, [{:==, :"$2", to_string(hotel_id)}], [:"$3"]}]
    {:ok, :ets.select(@channels_table, match_spec)}
  end

  @doc """
  Get all channels lazily.
  """
  @spec stream_all() :: Enumerable.t()
  def stream_all do
    Stream.resource(&stream_all_channels/0, &stream_all_channels/1, &Function.identity/1)
  end

  @doc """
  Fills settings  cache
  """
  def fill_cache(channels) do
    insert_channels_and_properties(channels)

    Logger.info(fn ->
      if Enum.empty?(channels),
        do: "#{@module_name} is loaded and empty",
        else: "#{@module_name} is full of #{Enum.count(channels)} channels"
    end)
  end

  @doc """
  Update channel at channels cache
  """
  @spec update(struct()) :: :ok
  def update(channel) do
    Logger.info("#{@module_name} #{Map.get(channel, :id)} updated")
    channel = prepare_channel(channel)
    insert_channel(channel)
    insert_to_property_channels_list(channel)
    :ok
  end

  @doc """
  Removes channel from channels cache
  """
  @spec remove(struct()) :: :ok
  def remove(channel) do
    Logger.info("#{@module_name} #{Map.get(channel, :id)} removed")
    remove_channel(channel)
    remove_from_property_channels_list(channel)
    :ok
  end

  @doc """
  Prepares channel for cache by taking only needed fields
  """
  @spec prepare_channel(struct()) :: map()
  def prepare_channel(channel) do
    CachedChannel.build(channel)
  end

  @doc false
  def start_link(init_arg) do
    GenServer.start_link(__MODULE__, init_arg, name: __MODULE__, hibernate_after: 15_000)
  end

  @impl true
  def init(init_arg) do
    Logger.info("#{@module_name} started")
    :ets.new(@channels_table, [:named_table, :public, read_concurrency: true])
    :ets.new(@properties_table, [:named_table, :public, read_concurrency: true])
    {:ok, init_arg}
  end

  #
  # Private methods
  #

  defp insert_channels_and_properties(channels) do
    insert_channels(channels)

    channels
    |> invert_channels()
    |> Map.to_list()
    |> update_channels_list_for_property()
  end

  defp insert_channels(channels) do
    channels
    |> Stream.map(&insert_channel/1)
    |> Stream.run()
  end

  defp insert_channel(channel) do
    :ets.insert(@channels_table, {channel.id, to_string(channel.settings.hotel_id), channel})
  end

  defp remove_channel(channel) do
    :ets.delete(@channels_table, channel.id)
  end

  defp invert_channels(channels) do
    for %{properties: properties} = channel <- channels,
        property <- properties,
        reduce: %{} do
      acc -> Map.update(acc, property.id, List.wrap(channel), &[channel | &1])
    end
  end

  defp insert_to_property_channels_list(%{properties: properties} = channel) do
    Enum.each(properties, &insert_to_channels_list(&1.id, channel))
  end

  defp insert_to_channels_list(property_id, channel) do
    channels = get_channels_list_except_channel(property_id, channel)
    update_channels_list_for_property({property_id, [channel | channels]})
  end

  defp remove_from_property_channels_list(%{properties: properties} = channel) do
    Enum.each(properties, &remove_from_channels_list(&1.id, channel))
  end

  defp remove_from_channels_list(property_id, channel) do
    channels = get_channels_list_except_channel(property_id, channel)
    update_channels_list_for_property({property_id, channels})
  end

  defp update_channels_list_for_property({property_id, []}) do
    :ets.delete(@properties_table, property_id)
  end

  defp update_channels_list_for_property(data) do
    :ets.insert(@properties_table, data)
  end

  defp get_channels_list_except_channel(property_id, channel) do
    property_id
    |> get_channels_list()
    |> Enum.filter(&(&1.id != channel.id))
  end

  defp get_channels_list(property_id) do
    case :ets.lookup(@properties_table, property_id) do
      [{_, channels}] -> channels
      [] -> []
    end
  end

  defp stream_all_channels, do: :ets.match(@channels_table, {:_, :_, :"$1"}, 10)
  defp stream_all_channels(:"$end_of_table"), do: {:halt, nil}
  defp stream_all_channels({channels, cont}), do: {Enum.concat(channels), :ets.match(cont)}
end
