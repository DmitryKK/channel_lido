defmodule ChannelLido.Services.HotelInvCountNotif.Mappings do
  @moduledoc false

  import SweetXml

  @errors [~x"./Errors/Error"ol, type: ~x"./@Type"os, message: ~x"./@ShortText"os]

  @doc false
  def get do
    {~x"//OTA_HotelInvCountNotifRS", success: ~x"./Success/text()"os, errors: @errors}
  end

  def get_error do
    {~x"//soap:Fault"ol,
     code: ~x"./soap:Code/soap:Value/text()"os, message: ~x"./soap:Reason/soap:Text/text()"os}
  end
end
