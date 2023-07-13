defmodule ChannelLido.Services.HotelAvailNotif.Request do
  @moduledoc false

  alias ChannelLido.DTO.Services.{AvailStatusMessage, AvailStatusMessages, Envelope}
  alias Saxy.Builder

  @restrictions_fields [:closed]
  @avail_status_messages_fields AvailStatusMessage.fields()

  @doc false
  def execute(params) do
    params
    |> prepare_payload()
    |> perform_request()
  end

  defp prepare_payload(params) do
    {changes, params} = Map.pop(params, :changes)

    changes
    |> Stream.reject(&all_restrictions_is_nil/1)
    |> Stream.map(&Map.take(&1, @avail_status_messages_fields))
    |> Enum.to_list()
    |> compose_payload(params)
  end

  defp all_restrictions_is_nil(change) do
    change
    |> Map.take(@restrictions_fields)
    |> Map.values()
    |> Enum.all?(&is_nil/1)
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
    [avail_status_messages: messages, hotel_id: params.hotel_id]
    |> AvailStatusMessages.new()
    |> Builder.build()
  end

  defp envelope(data) do
    [data: data, request: "OTA_HotelAvailNotifRQ"]
    |> Envelope.new()
    |> Builder.build()
    |> Saxy.encode!(version: "1.0", encoding: :utf8)
  end

  defp requester, do: Application.fetch_env!(:channel_lido, :requester)
end
