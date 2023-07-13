defmodule ChannelLido.Actions.ReceiveBookings.Response do
  @moduledoc false

  alias ChannelLido.DTO.Services.Envelope
  alias Saxy.{Builder, XML}

  @doc false
  def format({:ok, bms}) do
    params = get_response_params(bms)
    {:ok, :render, prepare_response(params)}
  end

  def format({:error, error}) do
    params = get_response_params(error)
    {:ok, :render, prepare_response(params)}
  end

  defp get_response_params(%{meta: meta} = data) do
    %{
      data: [
        compose_root_element(data),
        compose_unique_id_data(meta),
        compose_reservations_data(meta)
      ],
      attributes: compose_attributes(meta),
      status: meta.status
    }
  end

  defp compose_root_element(%{error: error}) do
    XML.element("Warnings", [], [compose_error(error)])
  end

  defp compose_root_element(_data) do
    XML.empty_element("Success", [])
  end

  defp compose_error(error) do
    XML.element("Warning", [Type: "1"], compose_message(error))
  end

  defp compose_message(:xml_parse_error), do: "XML Parse Error"
  defp compose_message(:message_convert_error), do: "Invalid XML Error"
  defp compose_message(_), do: "Server Error"

  defp compose_unique_id_data(%{status: :cancelled} = meta) do
    XML.empty_element("UniqueID",
      Type: "14",
      ID: meta.reservation_id,
      ID_Context: "CrsConfirmNumber"
    )
  end

  defp compose_unique_id_data(_), do: nil

  defp compose_reservations_data(%{status: status} = data) do
    {root_tag, child_tag} = get_nested_tags(status)

    XML.element(
      root_tag,
      [],
      [compose_child_reservations_data(child_tag, data)]
    )
  end

  defp compose_child_reservations_data(nil, data) do
    XML.empty_element("UniqueID",
      Type: "14",
      ID: data.confirmation_id,
      ID_Context: "PmsConfirmNumber"
    )
  end

  defp compose_child_reservations_data(tag, data) do
    XML.element(tag, [], [
      XML.empty_element("UniqueID",
        Type: "14",
        ID: data.reservation_id,
        ID_Context: "CrsConfirmNumber"
      ),
      compose_res_global_info(data)
    ])
  end

  defp compose_res_global_info(data) do
    XML.element("ResGlobalInfo", [], compose_hotel_reservation_ids(data))
  end

  defp compose_hotel_reservation_ids(data) do
    XML.element("HotelReservationIDs", [], compose_hotel_reservation_id(data))
  end

  defp compose_hotel_reservation_id(data) do
    XML.empty_element("HotelReservationID",
      ResID_Type: "14",
      ResID_SourceContext: "PmsConfirmNumber",
      ResID_Value: data.confirmation_id
    )
  end

  defp compose_attributes(%{meta: meta}), do: compose_attributes(meta)

  defp compose_attributes(data) do
    []
    |> put_unless_empty(:EchoToken, data.echo_token)
  end

  defp put_unless_empty(data, _key, ""), do: data
  defp put_unless_empty(data, key, value), do: Keyword.put(data, key, value)

  defp prepare_response(data) do
    body =
      data
      |> Map.put(:request, get_root_tag(data.status))
      |> Envelope.new()
      |> Builder.build()
      |> Saxy.encode!(version: "1.0", encoding: :utf8)

    {"text/xml", 200, body}
  end

  defp get_root_tag(:new), do: "OTA_HotelResNotifRS"
  defp get_root_tag(:modified), do: "OTA_HotelResModifyRS"
  defp get_root_tag(:cancelled), do: "OTA_CancelRS"

  defp get_nested_tags(:new), do: {"HotelReservations", "HotelReservation"}
  defp get_nested_tags(:modified), do: {"HotelResModifies", "HotelResModify"}
  defp get_nested_tags(:cancelled), do: {"CancelInfoRS", nil}
end
