defmodule ChannelLido.DTO.CachedChannel do
  @moduledoc false

  use ChannelLido.DTO

  defstruct channel: nil,
            channel_rate_plans: nil,
            group_id: nil,
            id: nil,
            inserted_at: nil,
            is_active: nil,
            properties: nil,
            rate_plans: nil,
            settings: nil,
            title: nil,
            updated_at: nil

  @spec build(struct()) :: t()
  def build(channel) do
    %{}
    |> Map.put(:channel, channel.channel)
    |> Map.put(:channel_rate_plans, prepare_channel_rate_plans(channel.channel_rate_plans))
    |> Map.put(:group_id, channel.group_id)
    |> Map.put(:id, channel.id)
    |> Map.put(:inserted_at, channel.inserted_at)
    |> Map.put(:is_active, channel.is_active)
    |> Map.put(:properties, prepare_properties(channel.properties))
    |> Map.put(:rate_plans, prepare_rate_plans(channel.rate_plans))
    |> Map.put(:settings, prepare_channel_settings(channel))
    |> Map.put(:title, channel.title)
    |> Map.put(:updated_at, channel.updated_at)
    |> new()
  end

  defp prepare_channel_rate_plans(items) when is_list(items) do
    Enum.map(items, &prepare_channel_rate_plan/1)
  end

  defp prepare_channel_rate_plan(item) when is_map(item) do
    Map.take(item, [:id, :rate_plan_id, :settings])
  end

  defp prepare_properties(items) when is_list(items) do
    Enum.map(items, &prepare_property/1)
  end

  defp prepare_property(item) when is_map(item) do
    Map.take(item, [:id, :title, :timezone, :currency])
  end

  defp prepare_rate_plans(items) when is_list(items) do
    Enum.map(items, &prepare_rate_plan/1)
  end

  defp prepare_rate_plan(item) when is_map(item) do
    Map.take(item, [:id, :title, :currency, :occupancy, :parent_rate_plan_id, :room_type_id])
  end

  defp prepare_channel_settings(channel) do
    channel
    |> Map.get(:settings)
    |> Map.delete(:mappingSettings)
    |> Map.put(:mapping_settings, %{})
    |> put_in([:mapping_settings, :rooms], compose_mapping_settings_rooms(channel))
  end

  defp compose_mapping_settings_rooms(channel) do
    grouped_rate_plans = Map.new(channel.rate_plans, &{&1.id, &1.room_type_id})

    for %{rate_plan_id: rate_plan_id, settings: %{room_type_code: room_type_code}} <-
          channel.channel_rate_plans,
        room_type_id = grouped_rate_plans[rate_plan_id],
        into: %{} do
      {to_string(room_type_code), room_type_id}
    end
  end

  defimpl Jason.Encoder do
    def encode(struct, opts) do
      struct
      |> Map.from_struct()
      |> Jason.Encode.map(opts)
    end
  end
end
