defmodule ChannelLido.Subscriber do
  @moduledoc false

  use GenServer

  require Logger

  alias ChannelLido.{ChangesConsumer, ChannelsCache}

  @channel_name "Lido"
  @module_name inspect(__MODULE__)

  @channel_preloads [
    :channel_rate_plans,
    :properties,
    :rate_plans
  ]

  @register_timeout :timer.minutes(1)
  @data_loading_timeout :timer.minutes(1)
  @re_register_timeout :timer.seconds(5)
  @exponential_modifier 2
  @max_registration_retries 9

  defstruct config: nil,
            init_data: %{},
            status: nil,
            registration_retries: 0

  @doc "Handles events pushed from ChannelManager."
  def handle_push(event, data) do
    GenServer.cast(__MODULE__, {event, data})
  end

  @doc false
  def start_link(_init_arg) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__, hibernate_after: 15_000)
  end

  @impl true
  def init(init_arg) when is_list(init_arg) do
    opts = Keyword.merge([config: %{channel_preloads: @channel_preloads}], init_arg)
    state = update_state(__MODULE__, opts)
    {:ok, update_state(state, status: :initializing), {:continue, :register}}
  end

  @impl true
  # TODO Remove after tests. Should not be called
  def handle_cast({:channels_loading, %{channels: channels}}, %{status: :registered} = state) do
    Logger.warning("#{@module_name} channels are loaded after registering")
    Enum.each(channels, &ChannelsCache.update/1)
    {:noreply, state}
  end

  def handle_cast({:channels_loading, %{channels: channels, finished: false}}, state)
      when is_map_key(state.init_data, :total_channel_delivered) do
    state =
      state
      |> put_channels_to_state(channels)
      |> update_state(status: :data_loading)

    {:noreply, state, {:continue, :check_all_channels_delivered}}
  end

  def handle_cast({:channels_loading, %{channels: channels, finished: false}}, state) do
    state = put_channels_to_state(state, channels)
    {:noreply, update_state(state, status: :data_loading)}
  end

  def handle_cast({:channels_loading, %{channels: channels, finished: true} = data}, state) do
    state =
      state
      |> put_channels_to_state(channels)
      |> put_total_channel_delivered(data[:total])

    {:noreply, state, {:continue, :check_all_channels_delivered}}
  end

  def handle_cast({:register_channel_provider, nil}, %{status: :data_loading} = state) do
    {:noreply, state, @data_loading_timeout}
  end

  def handle_cast({:register_channel_provider, nil}, %{status: :registered} = state) do
    register_channel_provider(state.config)
    {:noreply, state, set_timeout(state)}
  end

  def handle_cast({:register_channel_provider, nil}, state) do
    {:noreply, state, set_timeout(state)}
  end

  @impl true
  def handle_continue(:register, state) do
    Logger.info("#{@module_name} registering channel provider")
    connect_channel_provider(state.config)
    state = increment_retries(state)
    {:noreply, update_state(state, status: :registering), @register_timeout}
  end

  def handle_continue(:check_all_channels_delivered, state)
      when is_map_key(state.init_data, :total_channel_delivered) do
    if get_channels_count(state) >= state.init_data.total_channel_delivered do
      {:noreply, state, {:continue, :start_workers}}
    else
      {:noreply, state, set_timeout(state)}
    end
  end

  def handle_continue(:check_all_channels_delivered, state) do
    {:noreply, state, set_timeout(state)}
  end

  def handle_continue(:start_workers, state) do
    Logger.info("#{@module_name} channel provider is registered")
    ChannelsCache.fill_cache(state.init_data.channels)
    Supervisor.start_child(ChannelLido.Supervisor, ChangesConsumer)
    state = reset_retries(state)
    {:noreply, update_state(state, status: :registered, init_data: %{})}
  end

  @impl true
  def handle_info(:timeout, %{registration_retries: retries} = state)
      when retries >= @max_registration_retries do
    Logger.error("#{@module_name} registering channel provider is failed")
    {:noreply, reset_retries(state)}
  end

  def handle_info(:timeout, %{status: :registering, registration_retries: retries} = state) do
    state = increment_retries(state)
    Logger.info("#{@module_name} registering channel provider attempt ##{retries + 1}")
    connect_channel_provider(state.config)
    {:noreply, state, set_timeout(state)}
  end

  def handle_info(:timeout, %{status: :data_loading} = state) do
    Logger.warning("#{@module_name} data loading timeout, attempt ##{state.registration_retries}")
    state = reset_retries(state)
    {:noreply, update_state(state, init_data: %{}), {:continue, :register}}
  end

  def handle_info(:timeout, state) do
    {:noreply, reset_retries(state)}
  end

  defp put_total_channel_delivered(state, nil), do: state

  defp put_total_channel_delivered(state, total) do
    put_in(state.init_data[:total_channel_delivered], total)
  end

  defp put_channels_to_state(state, channels) do
    channels = Enum.map(channels, &ChannelsCache.prepare_channel/1)
    update_in(state.init_data[:channels], &append_channels(&1, channels))
  end

  defp append_channels(nil, new_channels), do: new_channels
  defp append_channels(channels, new_channels), do: channels ++ new_channels

  defp register_channel_provider(config) do
    config
    |> Map.put(:data_loaded?, true)
    |> connect_channel_provider()
  end

  defp connect_channel_provider(config) do
    MessageQueue.rpc_cast("ChannelManager", "connect_channel_provider", [@channel_name, config])
  end

  defp get_channels_count(state) when is_list(state.init_data.channels) do
    Enum.count(state.init_data.channels)
  end

  defp get_channels_count(_state), do: 0

  defp set_timeout(%{registration_retries: retries}) do
    round(@re_register_timeout * Integer.pow(@exponential_modifier, retries))
  end

  defp update_state(state, data), do: struct!(state, data)

  defp reset_retries(state), do: update_state(state, registration_retries: 0)

  defp increment_retries(%{registration_retries: retries} = state) do
    update_state(state, registration_retries: retries + 1)
  end
end
