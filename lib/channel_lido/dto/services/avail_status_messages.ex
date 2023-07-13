defmodule ChannelLido.DTO.Services.AvailStatusMessages do
  @moduledoc false

  use ChannelLido.DTO

  alias ChannelLido.DTO.Services.AvailStatusMessage
  alias Saxy.Builder

  defstruct [:avail_status_messages, :hotel_id]

  defimpl Saxy.Builder do
    import Saxy.XML

    def build(data) do
      element(
        "AvailStatusMessages",
        [HotelCode: data.hotel_id],
        build_avail_status_messages(data.avail_status_messages)
      )
    end

    def build_avail_status_messages(avail_status_messages) do
      for avail_status_message <- avail_status_messages do
        avail_status_message
        |> AvailStatusMessage.new()
        |> Builder.build()
      end
    end
  end
end
