defmodule ChannelLido.ChangesConverter do
  @moduledoc """
  Converters changes into updates of rates, availability and restrictions to
  sync through Lido ARI API.
  """

  alias ChannelLido.DTO.ChangesToSync

  @valid_date_range 0..365

  @doc false
  def convert(channel, changes) do
    %{
      channel_rate_plans: channel_rate_plans,
      rate_plans: rate_plans,
      settings: settings,
      timezone: timezone
    } = channel

    converted_changes =
      settings
      |> Map.put(:timezone, timezone)
      |> group_changes(changes, channel_rate_plans, rate_plans)

    %{channel_id: channel.id, changes: converted_changes, hotel_id: settings.hotel_id}
  end

  defp group_changes(settings, changes, channel_rate_plans, rate_plans) do
    grouped_channel_rate_plans = map_group_by(channel_rate_plans, :rate_plan_id)
    grouped_rate_plans = map_group_by(rate_plans, :id)

    for {rate_plan_id, rate_plan_changes} <- Enum.group_by(changes, & &1.rate_plan_id),
        channel_rate_plan = Map.get(grouped_channel_rate_plans, rate_plan_id),
        reduce: [] do
      acc ->
        rate_plan = Map.get(grouped_rate_plans, rate_plan_id)

        channel_rate_plan
        |> Map.get(:settings)
        |> Map.put(:timezone, settings.timezone)
        |> filter_and_compose_changes(rate_plan_changes, rate_plan)
        |> Enum.concat(acc)
    end
  end

  defp filter_and_compose_changes(_settings, _changes, nil), do: []

  defp filter_and_compose_changes(settings, changes, rate_plan) do
    for {key, changes_by_date} <- group_changes(changes, settings),
        valid_date?(key, settings) do
      changes_by_date
      |> compose_changes(rate_plan.currency)
      |> Map.put(:inv_type_code, settings.room_type_code)
      |> Map.put(:rate_plan_code, settings.rate_plan_code)
      |> Map.put(:occupancy, rate_plan.occupancy)
      |> Map.put(:currency, rate_plan.currency)
      |> Map.put(:date, get_date(key))
      |> ChangesToSync.new!()
    end
  end

  defp group_changes(changes, %{timezone: timezone}) when is_map(timezone) do
    Enum.group_by(changes, &{&1.date, &1.property_id})
  end

  defp group_changes(changes, _settings) do
    Enum.group_by(changes, & &1.date)
  end

  defp valid_date?({date, property_id}, %{timezone: timezone}) do
    diff_dates(date, timezone[property_id]) in @valid_date_range
  end

  defp valid_date?(date, %{timezone: timezone}) do
    diff_dates(date, timezone) in @valid_date_range
  end

  defp compose_changes(changes, currency) do
    for change <- changes, {key, value} <- change, reduce: %{} do
      acc ->
        key
        |> map_changes(value, acc)
        |> map_rate_change(key, value, currency)
    end
  end

  defp map_changes(:availability, availability, acc) when availability <= 0 do
    acc
    |> Map.put(:inv_count, 0)
    |> Map.put(:closed, true)
  end

  defp map_changes(:availability, availability, acc) do
    Map.put(acc, :inv_count, availability)
  end

  defp map_changes(:stop_sell, stop_sell, acc) do
    Map.put(acc, :closed, stop_sell)
  end

  defp map_changes(:room_type_id, room_type_id, acc) do
    Map.put(acc, :inv_type_code, room_type_id)
  end

  defp map_changes(_key, _value, acc), do: acc

  defp map_rate_change(acc, :rate, 0, _currency) do
    Map.put(acc, :closed, true)
  end

  defp map_rate_change(acc, :rate, rate, currency) do
    Map.put(acc, :rate, to_money(rate, currency))
  end

  defp map_rate_change(acc, _key, _rate, _currency), do: acc

  defp get_date({date, _}), do: date
  defp get_date(date), do: date

  defp to_money(nil, currency), do: to_money(0, currency)

  defp to_money(rate, currency) when is_binary(rate) do
    rate
    |> Money.parse!(currency)
    |> Money.to_string()
  end

  defp to_money(rate, currency) when is_integer(rate) do
    rate
    |> Money.new(currency)
    |> Money.to_string()
  end

  defp today_date(timezone) do
    case DateTime.now(timezone) do
      {:ok, date} -> DateTime.to_date(date)
      _ -> Date.utc_today()
    end
  end

  defp map_group_by(items, field) do
    Map.new(items, &{Map.get(&1, field), &1})
  end

  defp diff_dates(date, timezone) do
    date
    |> to_date()
    |> Date.diff(today_date(timezone))
  end

  defp to_date(%Date{} = date), do: date
  defp to_date(date) when is_binary(date), do: Date.from_iso8601!(date)
end
