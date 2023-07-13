defmodule ChannelLido.DTO.Services.Envelope do
  @moduledoc false

  use ChannelLido.DTO

  defstruct [:attributes, :data, :request, :wrap]

  defimpl Saxy.Builder do
    import Saxy.XML

    @default_attributes [xmlns: "http://www.opentravel.org/OTA/2003/05", Version: "1.0"]

    @envelope_attributes [
      "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
      "xmlns:xsd": "http://www.w3.org/2001/XMLSchema",
      "xmlns:soap": "http://schemas.xmlsoap.org/soap/envelope/"
    ]

    def build(params) do
      element("soap:Envelope", @envelope_attributes, [compose_header(), compose_body(params)])
    end

    defp compose_header do
      element("soap:Header", [], compose_auth_header())
    end

    defp compose_auth_header do
      element("HTNGHeader", [xmlns: "http://htng.org/1.1/Header/"], [
        element("From", [], [
          element("systemId", [], "Channex"),
          element("Credential", [], [
            element("userName", [], username()),
            element("password", [], password())
          ])
        ]),
        element("To", [], [
          element("systemId", [], "Lido")
        ]),
        element("timeStamp", [], timestamp()),
        element("echoToken", [], echo_token()),
        element("action", [], "Request")
      ])
    end

    defp compose_body(params) do
      element("soap:Body", [], wrap_request(params))
    end

    defp wrap_request(%{data: data, request: request, attributes: attributes, wrap: nil}) do
      element(request, set_attrs(attributes), data)
    end

    defp wrap_request(%{request: request, wrap: :xml_rq} = params) do
      element(request, [xmlns: "http://htng.org/"], xml_rq(params))
    end

    defp xml_rq(%{data: data, request: request, attributes: attributes}) do
      element("xmlRQ", [], element(request, set_attrs(attributes), data))
    end

    defp set_attrs(nil), do: Keyword.merge(@default_attributes, dynamic_attrs())

    defp set_attrs(attributes) do
      @default_attributes
      |> Keyword.merge(dynamic_attrs())
      |> Keyword.merge(attributes)
    end

    defp dynamic_attrs do
      [TimeStamp: timestamp(), EchoToken: echo_token(), Target: target()]
    end

    defp timestamp do
      DateTime.utc_now()
      |> DateTime.truncate(:millisecond)
      |> DateTime.to_iso8601()
    end

    defp echo_token, do: Ecto.UUID.generate()

    defp target do
      Application.fetch_env!(:channel_lido, :target)
    end

    defp username, do: Application.fetch_env!(:channel_lido, :username)
    defp password, do: Application.fetch_env!(:channel_lido, :password)
  end
end
