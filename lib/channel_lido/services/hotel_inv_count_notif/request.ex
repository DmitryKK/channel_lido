defmodule ChannelLido.Services.HotelInvCountNotif.Request do
  @moduledoc false

  alias ChannelLido.DTO.Services.{Envelope, Inventory, Inventories}
  alias Saxy.Builder

  @inventories_fields Inventory.fields()

  @doc false
  def execute(params) do
    params
    |> prepare_payload()
    |> perform_request()
  end

  defp prepare_payload(params) do
    {changes, params} = Map.pop(params, :changes)

    changes
    |> Stream.reject(&is_nil(&1.inv_count))
    |> Stream.map(&Map.take(&1, @inventories_fields))
    |> Enum.to_list()
    |> compose_payload(params)
  end

  defp perform_request(:no_changes), do: {:ok, :no_changes, nil}

  defp perform_request(payload) do
    %{payload: payload}
    |> requester().new()
    |> requester().perform()
  end

  defp compose_payload([], _params), do: :no_changes

  defp compose_payload(messages, params) do
    messages
    |> compose_inventories(params)
    |> envelope()
  end

  defp compose_inventories(messages, params) do
    [inventories: messages, hotel_id: params.hotel_id]
    |> Inventories.new()
    |> Builder.build()
  end

  defp envelope(data) do
    [data: data, request: "OTA_HotelInvCountNotifRQ"]
    |> Envelope.new()
    |> Builder.build()
    |> Saxy.encode!(version: "1.0", encoding: :utf8)
  end

  defp requester, do: Application.fetch_env!(:channel_lido, :requester)
end
