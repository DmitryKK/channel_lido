defmodule ChannelLido.Services.HotelAvail.Request do
  @moduledoc false

  alias ChannelLido.DTO.Services.Envelope
  alias Saxy.{Builder, XML}

  @doc false
  def execute(args) do
    %{payload: compose_payload(args)}
    |> requester().new()
    |> requester().perform()
  end

  defp compose_payload(args) do
    "AvailRequestSegments"
    |> XML.element([], request(args))
    |> envelope()
  end

  defp request(args) do
    XML.element("AvailRequestSegment", [], hotel_search_criteria(args))
  end

  defp hotel_search_criteria(args) do
    XML.element("HotelSearchCriteria", [AvailableOnlyIndicator: 0, HotelCode: args.hotel_id], [])
  end

  defp envelope(data) do
    [data: data, request: "OTA_HotelAvailRQ"]
    |> Envelope.new()
    |> Builder.build()
    |> Saxy.encode!(version: "1.0", encoding: :utf8)
  end

  defp requester, do: Application.fetch_env!(:channel_lido, :requester)
end
