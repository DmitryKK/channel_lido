defmodule ChannelLido.Actions.ReceiveBookings.Mappings do
  @moduledoc """
  Mappings for parsing notifications for any new, modified, forwarded or cancellation
  reservation.
  """

  import SweetXml

  @doc false
  def get_basic do
    {
      ~x"/child::*",
      name: ~x"name(/*)"s
    }
  end

  @doc false
  def get(status) when status in [:new, :modified] do
    {root_element, reservation_element} = get_root_elements(status)

    {
      root_element,
      echo_token: ~x"./@EchoToken"s,
      timestamp: ~x"./@TimeStamp"s,
      status: transform_by(~x".", &set_status(&1, status)),
      reservation: [
        reservation_element,
        creation_date: transform_by(~x"./@CreateDateTime"os, &normalize_date/1),
        unique_id: ~x"./UniqueID/@ID"s,
        room_stays: [
          ~x"./RoomStays/RoomStay"ol,
          hotel_code: ~x"./BasicPropertyInfo/@HotelCode"s,
          hotel_name: ~x"./BasicPropertyInfo/@HotelName"s,
          room_type_codes: ~x"./RoomRates/RoomRate/@RoomTypeCode"ols,
          rate_plan_codes: ~x"./RoomRates/RoomRate/@RatePlanCode"ols,
          checkin_date: transform_by(~x"./TimeSpan/@Start"os, &to_date/1),
          checkout_date: transform_by(~x"./TimeSpan/@End"os, &to_date/1),
          room_types: [
            ~x"./RoomTypes/RoomType"ol,
            number_of_units: ~x"./@NumberOfUnits"i,
            room_type_code: ~x"./@RoomTypeCode"s
          ],
          room_rates: [
            ~x"./RoomRates/RoomRate"ol,
            rate_plan_code: ~x"./@RatePlanCode"s,
            room_type_code: ~x"./@RoomTypeCode"s,
            rates: [
              ~x"./Rates/Rate"ol,
              effective_date: transform_by(~x"./@EffectiveDate"s, &to_date/1),
              expire_date: transform_by(~x"./@ExpireDate"s, &to_date/1),
              amount_after_tax: ~x"./Base/@AmountAfterTax"s,
              amount_before_tax: ~x"./Base/@AmountBeforeTax"s,
              currency_code: ~x"./Base/@CurrencyCode"s,
              total: [
                ~x"./Total"o,
                amount_after_tax: ~x"./@AmountAfterTax"s,
                amount_before_tax: ~x"./@AmountBeforeTax"s,
                currency_code: ~x"./@CurrencyCode"s
              ]
            ]
          ],
          guest_counts: [
            ~x"./GuestCounts/GuestCount"ol,
            age_qualifying_code: ~x"./@AgeQualifyingCode"s,
            count: ~x"./@Count"i
          ],
          comments: ~x"./Comments/Comment/Text/text()"sl,
          special_requests: ~x"./SpecialRequests/SpecialRequest/Text/text()"sl,
          amount_after_tax: ~x"./Total/@AmountAfterTax"s,
          amount_before_tax: ~x"./Total/@AmountBeforeTax"s,
          currency_code: ~x"./Total/@CurrencyCode"s
        ],
        res_guests: [
          ~x"./ResGuests/ResGuest"ol,
          profiles: [
            ~x"./Profiles/ProfileInfo/Profile"ol,
            type: ~x"./@ProfileType"s,
            given_name: ~x"./Customer/PersonName/GivenName/text()"s,
            surname: ~x"./Customer/PersonName/Surname/text()"s,
            telephone: ~x"./Customer/Telephone/@PhoneNumber"s,
            email: ~x"./Customer/Email/text()"s,
            address: [
              ~x"./Customer/Address"o,
              address_line: ~x"./AddressLine/text()"s,
              city_name: ~x"./CityName/text()"s,
              postal_code: ~x"./PostalCode/text()"s,
              state_prov: ~x"./StateProv/text()"s,
              country_name: ~x"./CountryName/text()"s
            ]
          ]
        ],
        res_global_info: [
          ~x"./ResGlobalInfo"o,
          comments: ~x"./Comments/Comment/Text/text()"sl,
          guarantee: [
            ~x"./Guarantee/GuaranteesAccepted/GuaranteeAccepted"o,
            card_number: ~x"./PaymentCard/@CardNumber"os,
            card_type: ~x"./PaymentCard/@CardType"os,
            expire_date: ~x"./PaymentCard/@ExpireDate"os,
            series_code: ~x"./PaymentCard/@SeriesCode"os,
            card_code: ~x"./PaymentCard/@CardCode"os,
            card_holder_name: ~x"./PaymentCard/CardHolderName/text()"os,
            token: ~x"./PaymentCard/@Token"os,
            warning: ~x"./PaymentCard/@Warning"os,
            error: ~x"./PaymentCard/@Error"os
          ],
          special_requests: ~x"./SpecialRequests/SpecialRequest/Text/text()"sl,
          total_amount: [
            ~x"./Total"o,
            amount_after_tax: ~x"./@AmountAfterTax"s,
            amount_before_tax: ~x"./@AmountBeforeTax"s,
            currency_code: ~x"./@CurrencyCode"s
          ],
          profiles: [
            ~x"./Profiles/ProfileInfo/Profile"ol,
            type: ~x"./@ProfileType"s,
            agent: [
              ~x"./CompanyInfo"o,
              name: ~x"./CompanyName/@CompanyShortName"s,
              code: ~x"./CompanyName/@Code"s,
              email: ~x"./Email/text()"s,
              phone: ~x"./TelephoneInfo/@PhoneNumber"s,
              address: [
                ~x"./BusinessLocale"o,
                city: ~x"./CityName/text()"s,
                country: ~x"./CountryName/text()"s,
                post_code: ~x"./PostalCode/text()"s,
                state_code: ~x"./StateProv/text()"s,
                address_line: ~x"./AddressLine/text()"ol
              ]
            ]
          ],
          unique_ids:
            transform_by(
              ~x"./HotelReservationIDs/HotelReservationID"le,
              &get_unique_ids(&1, status)
            )
        ]
      ]
    }
  end

  def get(:cancelled) do
    {
      ~x"//OTA_CancelRQ",
      echo_token: ~x"./@EchoToken"s,
      timestamp: ~x"./@TimeStamp"s,
      status: transform_by(~x".", &set_status(&1, :cancelled)),
      reservation: [
        ~x"//*",
        unique_id:
          transform_by(
            ~x"./UniqueID"le,
            &(get_unique_ids(&1, :cancelled) |> Map.get(:reservation_id))
          ),
        hotel_code: ~x"./TPA_Extensions/BasicPropertyInfo/@HotelCode"s,
        hotel_name: ~x"./TPA_Extensions/BasicPropertyInfo/@HotelName"s,
        res_guests: [
          ~x"./Verification"ol,
          profiles: [
            ~x"//*[1]"l,
            given_name: ~x"./PersonName/GivenName/text()"s,
            surname: ~x"./PersonName/Surname/text()"s,
            telephone: ~x"./TelephoneInfo/@PhoneNumber"s,
            email: ~x"./Email/text()"s,
            address: [
              ~x"./AddressInfo"o,
              address_line: ~x"./AddressLine/text()"s,
              city_name: ~x"./CityName/text()"s,
              postal_code: ~x"./PostalCode/text()"s,
              state_prov: ~x"./StateProv/text()"s,
              country_name: ~x"./CountryName/text()"s
            ]
          ]
        ],
        res_global_info: [
          ~x"//*",
          unique_ids: transform_by(~x"./UniqueID"le, &get_unique_ids(&1, :cancelled))
        ]
      ]
    }
  end

  defp get_root_elements(:new),
    do: {~x"//OTA_HotelResNotifRQ", ~x"./HotelReservations/HotelReservation"o}

  defp get_root_elements(:modified),
    do: {~x"//OTA_HotelResModifyNotifRQ", ~x"./HotelResModifies/HotelResModify"o}

  defp get_unique_ids(elems, status) do
    {context_attr, value_attr} = get_id_attributes(status)

    Map.new(elems, fn elem ->
      case xpath(elem, context_attr) do
        "CrsConfirmNumber" -> {:reservation_id, xpath(elem, value_attr)}
        "PmsConfirmNumber" -> {:confirmation_id, xpath(elem, value_attr)}
        _ -> {:unknown, nil}
      end
    end)
  end

  defp get_id_attributes(:cancelled), do: {~x"./@ID_Context"s, ~x"./@ID"s}
  defp get_id_attributes(_), do: {~x"./@ResID_SourceContext"s, ~x"./@ResID_Value"s}

  defp to_date(<<date::binary-size(10)>> <> _ = term) do
    case Date.from_iso8601(date) do
      {:ok, date} -> date
      _error -> term
    end
  end

  defp normalize_date(date) when is_binary(date) do
    case NaiveDateTime.from_iso8601(date) do
      {:ok, date} -> date
      {:error, _error} -> nil
    end
  end

  defp set_status(_, status), do: status
end
