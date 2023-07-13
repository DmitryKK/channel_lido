defmodule ChannelLido.Services.HotelAvail.Mappings do
  @moduledoc false

  import SweetXml

  @errors [~x"./Errors/Error"ol, type: ~x"./@Type"os, message: ~x"./@ShortText"os]

  @doc false
  def get do
    {~x"//OTA_HotelAvailRS",
     success: ~x"./Success/text()"os,
     rooms: [
       ~x"./RoomStays/RoomStay"ol,
       id: ~x"./RoomTypes/RoomType/@RoomTypeCode"os,
       title: transform_by(~x"./RoomTypes/RoomType/RoomDescription/Text"os, &String.trim/1),
       rate: [
         ~x"./RatePlans/RatePlan"o,
         id: ~x"./@RatePlanCode"os,
         title: transform_by(~x"./RatePlanDescription/Text"os, &String.trim/1)
       ]
     ],
     errors: @errors}
  end
end
