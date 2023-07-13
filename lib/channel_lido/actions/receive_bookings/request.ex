defmodule ChannelLido.Actions.ReceiveBookings.Request do
  @moduledoc false

  alias ChannelLido.Actions.ReceiveBookings.Mappings
  alias ChannelLido.Errors.SystemError

  @statuses %{
    "OTA_CancelRQ" => :cancelled,
    "OTA_HotelResModifyNotifRQ" => :modified,
    "OTA_HotelResNotifRQ" => :new
  }

  @doc false
  def parse(args) do
    case Saxmerl.parse_string(args.body, dynamic_atoms: false) do
      {:ok, payload} -> {:ok, parse_payload(payload, args)}
      {:error, exception} when is_exception(exception) -> raise exception
    end
  rescue
    exception ->
      error = Exception.message(exception)
      SystemError.new(__MODULE__, %{args: args, error: error}, __STACKTRACE__)
      {:error, prepare_error_response(args)}
  end

  defp parse_payload(payload, args) do
    status = get_status(payload)
    {root, mapping} = Mappings.get(status)

    payload
    |> SweetXml.xpath(root, mapping)
    |> Map.put(:raw_payload, args.body)
  end

  defp get_status(payload) do
    {root, mapping} = Mappings.get_basic()

    payload
    |> SweetXml.xpath(root, mapping)
    |> Map.get(:name)
    |> then(&@statuses[&1])
  end

  defp prepare_error_response(%{body: body}) when is_binary(body) do
    regexp = ~r/^<(?<root_tag>\w+)\s.+(<EchoToken=\"(?<echo_token>\w+))?/
    captures = Regex.named_captures(regexp, body)

    %{
      error: :xml_parse_error,
      meta: %{
        status: @statuses[captures["root_tag"]],
        echo_token: captures["echo_token"],
        confirmation_id: "",
        reservation_id: ""
      }
    }
  end
end
