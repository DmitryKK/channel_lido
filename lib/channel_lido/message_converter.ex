defmodule ChannelLido.MessageConverter do
  @moduledoc """
  Documentation for `ChannelLido.MessageConverter`.
  """

  alias ChannelLido.ChannelsCache
  alias ChannelLido.Errors.SystemError

  @channel_name "Lido"

  @doc false
  @spec convert({:ok, map()} | {:error, map()}) :: {:ok, Bookingreservation.t()} | {:error, map()}
  def convert({:ok, %{reservation: reservation} = message}) do
    channel = find_channel!(reservation)
    res_global_info = reservation.res_global_info
    booking_id = Ecto.UUID.generate()

    {:ok,
     %BookingMessage{
       amount: get_amount(res_global_info[:total_amount]),
       channel_id: channel.id,
       status: message.status,
       channel_name: @channel_name,
       channel_reservation_code: reservation.unique_id,
       primary_ota: @channel_name,
       booking_id: booking_id,
       property_id: set_property_id(channel),
       system_id: set_system_id(message.raw_payload),
       unique_id: "LDO-#{reservation.unique_id}",
       arrival_date: set_arrival_date(reservation[:room_stays]),
       departure_date: set_departure_date(reservation[:room_stays]),
       currency: set_currency(res_global_info, channel),
       customer: set_customer(reservation),
       agent: set_agent(reservation),
       notes: set_notes(reservation),
       rooms: set_rooms(reservation, channel),
       services: [],
       guests: [],
       deposits: [],
       discounts: [],
       guarantee: set_guarantee(res_global_info),
       payment_collect: set_payment_collect(res_global_info, message.status),
       payment_type: set_payment_type(res_global_info, message.status),
       raw_message: message.raw_payload,
       meta: set_meta(message, booking_id)
     }
     |> set_occupancy()
     |> set_is_mapped()}
  rescue
    exception ->
      error = Exception.message(exception)
      metadata = %{payload: message, error: error}
      SystemError.new(__MODULE__, metadata, __STACKTRACE__)
      {:error, %{error: :message_convert_error, meta: set_meta(message, nil)}}
  end

  def convert(error), do: error

  defp find_channel!(%{hotel_code: hotel_code}) do
    hotel_code
    |> ChannelsCache.all()
    |> case do
      {:ok, []} -> raise "no channel"
      {:ok, [channel]} -> channel
    end
  end

  defp find_channel!(%{room_stays: room_stays}) do
    room_stays
    |> Enum.map(& &1.hotel_code)
    |> Enum.uniq()
    |> ChannelsCache.all()
    |> case do
      {:ok, [channel]} -> channel
      {:ok, []} -> raise "no channel"
      {:ok, [_ | _]} -> raise "several channels"
    end
  end

  defp set_property_id(%{properties: [%{id: property_id}]}) do
    property_id
  end

  defp set_system_id(raw_payload) do
    raw_payload
    |> :erlang.md5()
    |> Base.url_encode64(padding: false)
  end

  defp set_arrival_date(nil), do: nil

  defp set_arrival_date(room_stays) do
    room_stays
    |> Enum.sort_by(& &1.checkin_date, {:asc, Date})
    |> List.first(%{})
    |> Map.get(:checkin_date)
  end

  defp set_departure_date(nil), do: nil

  defp set_departure_date(room_stays) do
    room_stays
    |> Enum.sort_by(& &1.checkout_date, {:desc, Date})
    |> List.first(%{})
    |> Map.get(:checkout_date)
  end

  defp set_currency(%{total_amount: %{currency_code: currency_code}}, _channel)
       when is_binary(currency_code) and currency_code != "" do
    currency_code
  end

  defp set_currency(_info, %{properties: [%{currency: currency}]}), do: currency

  defp set_customer(%{res_guests: [%{profiles: [profile | _]} | _]}) do
    %{}
    |> put_unless_empty(:name, profile.given_name)
    |> put_unless_empty(:surname, profile.surname)
    |> put_unless_empty(:phone, profile.telephone)
    |> put_unless_empty(:mail, profile.email)
    |> put_unless_empty(:country, profile.address[:country_name])
    |> put_unless_empty(:city, profile.address[:city_name])
    |> put_unless_empty(:address, profile.address[:address_line])
    |> put_unless_empty(:zip, profile.address[:postal_code])
  end

  defp set_customer(_reservation), do: %{name: "No", surname: "Name"}

  defp set_agent(%{res_global_info: %{profiles: [%{agent: agent} | _]}}) do
    %{}
    |> put_unless_empty(:name, agent.name)
    |> put_unless_empty(:code, agent.code)
    |> put_unless_empty(:email, agent.email)
    |> put_unless_empty(:phone, agent.phone)
    |> put_unless_empty(:address, set_agent_address(agent.address))
  end

  defp set_agent(_reservation), do: nil

  defp set_agent_address(nil), do: nil

  defp set_agent_address(address) do
    %{}
    |> put_unless_empty(:addressLine, prepare_address_list(address.address_line))
    |> put_unless_empty(:city, address.city)
    |> put_unless_empty(:countryCode, address.country)
    |> put_unless_empty(:postCode, address.post_code)
    |> put_unless_empty(:stateCode, address.state_code)
  end

  defp prepare_address_list(nil), do: nil
  defp prepare_address_list(list) when is_list(list), do: Enum.join(list, " ")

  defp set_notes(reservation) do
    [
      flat_join_strings(reservation[:room_stays] || [], :comments),
      get_comments(reservation.res_global_info),
      flat_join_strings(reservation[:room_stays] || [], :special_requests)
    ]
    |> Enum.join("\n")
    |> String.trim()
  end

  defp get_comments(%{comments: comments}), do: join_strings(comments)
  defp get_comments(_res_global_info), do: ""

  defp flat_join_strings(data, key) do
    data
    |> Enum.flat_map(&Map.get(&1, key))
    |> join_strings()
  end

  defp set_rooms(%{room_stays: _} = reservation, channel) do
    channel_rate_plans = prepare_channel_rate_plans(channel.channel_rate_plans)
    rate_plans = prepare_rate_plans(channel.rate_plans)

    for room <- reservation.room_stays do
      occupancy_by_age = get_occupancy_by_age(room.guest_counts)

      %{rate_plan_id: rate_plan_id, room_type_id: room_type_id} =
        room.room_type_codes
        |> List.first()
        |> get_rate_plan(channel_rate_plans, rate_plans)
        |> set_room_type_id(channel.settings)

      %{
        amount: get_amount(room),
        checkin_date: room.checkin_date,
        checkout_date: room.checkout_date,
        days: get_days(room.room_rates),
        guests: get_guests(reservation.res_guests),
        occ_adults: occupancy_by_age.adults,
        occ_children: occupancy_by_age.children,
        occ_infants: occupancy_by_age.infants,
        rate_plan_id: rate_plan_id,
        room_type_id: room_type_id,
        taxes: [],
        meta: %{
          hotel_code: room.hotel_code,
          rate_plan_code: List.first(room.rate_plan_codes),
          room_type_code: List.first(room.room_type_codes)
        }
      }
    end
  end

  defp set_rooms(_reservation, _channel), do: []

  defp prepare_channel_rate_plans(channel_rate_plans) do
    Map.new(channel_rate_plans, &{&1.settings.room_type_code, &1.rate_plan_id})
  end

  defp prepare_rate_plans(rate_plans) do
    for rate_plan <- rate_plans, rate_plan.parent_rate_plan_id, into: %{} do
      {rate_plan.id, Map.take(rate_plan, [:parent_rate_plan_id, :room_type_id])}
    end
  end

  defp get_rate_plan(nil, _channel_rate_plans, _rate_plans) do
    %{rate_plan_id: nil, room_type_id: nil}
  end

  defp get_rate_plan(room_type_code, channel_rate_plans, rate_plans) do
    case find_rate_plan(room_type_code, channel_rate_plans, rate_plans) do
      {:ok, rp} -> %{rate_plan_id: rp.parent_rate_plan_id, room_type_id: rp.room_type_id}
      {:error, data} -> data
    end
  end

  defp find_rate_plan(room_type_code, channel_rate_plans, rate_plans) do
    with rate_plan_id when is_binary(rate_plan_id) <- channel_rate_plans[room_type_code],
         rate_plan when is_map(rate_plan) <- rate_plans[rate_plan_id] do
      {:ok, rate_plan}
    else
      nil -> {:error, %{rate_plan_id: nil, room_type_code: room_type_code}}
    end
  end

  defp set_room_type_id(%{rate_plan_id: nil} = data, %{mapping_settings: settings})
       when is_map(settings.rooms) do
    case Map.get(settings.rooms, to_string(data.room_type_code)) do
      nil -> %{rate_plan_id: nil, room_type_id: nil}
      room_type_id -> %{rate_plan_id: nil, room_type_id: room_type_id}
    end
  end

  defp set_room_type_id(data, _channel_settings), do: data

  defp get_occupancy_by_age(guest_counts) do
    count_by_age = Map.new(guest_counts, &{&1.age_qualifying_code, &1.count})

    %{
      adults: count_by_age["10"] || 0,
      children: count_by_age["8"] || 0,
      infants: (count_by_age["7"] || 0) + (count_by_age["3"] || 0)
    }
  end

  defp get_days(room_rates) do
    for %{rates: rates} <- room_rates, rate <- rates, date <- get_date_range(rate), into: %{} do
      {date, get_amount(rate)}
    end
  end

  defp get_date_range(rate) do
    Date.range(rate.effective_date, Date.add(rate.expire_date, -1))
  end

  defp get_guests([%{profiles: [profile]}]) do
    [%{name: profile.given_name, surname: profile.surname, type: profile.type}]
  end

  defp get_guests(res_guests) do
    for %{profiles: profiles} <- res_guests, profile <- profiles, profile.type != "1" do
      %{name: profile.given_name, surname: profile.surname, type: profile.type}
    end
  end

  defp set_guarantee(%{guarantee: guarantee}) when is_map(guarantee) do
    guarantee
    |> Map.take([:card_number, :card_code, :expire_date])
    |> Map.values()
    |> Enum.any?(&empty?/1)
    |> unless do
      %{
        is_present: true,
        is_virtual: false,
        cardholder_name: guarantee.card_holder_name,
        card_number: guarantee.card_number,
        expiration_date: guarantee.expire_date,
        card_type: guarantee.card_code,
        token: guarantee.token,
        error: guarantee.error,
        warning: guarantee.warning
      }
    end
  end

  defp set_guarantee(_res_global_info), do: nil

  defp set_payment_collect(_, :cancelled), do: nil
  defp set_payment_collect(%{guarantee: %{}}, _), do: :property
  defp set_payment_collect(_res_global_info, _), do: :ota

  defp set_payment_type(_, :cancelled), do: nil
  defp set_payment_type(%{guarantee: %{}}, _), do: :credit_card
  defp set_payment_type(_res_global_info, _), do: :bank_transfer

  defp set_meta(message, booking_id) do
    confirmation_id =
      message.reservation.res_global_info.unique_ids[:confirmation_id] || booking_id

    %{
      confirmation_id: confirmation_id,
      echo_token: message.echo_token,
      timestamp: message.timestamp,
      status: message.status,
      reservation_id: message.reservation.unique_id
    }
  end

  defp set_occupancy(bms) do
    for room <- bms.rooms, reduce: bms do
      acc ->
        acc
        |> Map.put(:occ_adults, sum_occupancies(room.occ_adults, acc.occ_adults))
        |> Map.put(:occ_children, sum_occupancies(room.occ_children, acc.occ_children))
        |> Map.put(:occ_infants, sum_occupancies(room.occ_infants, acc.occ_infants))
    end
  end

  defp sum_occupancies(occupancy, nil), do: occupancy
  defp sum_occupancies(occupancy, 0), do: occupancy
  defp sum_occupancies(0, occupancy), do: occupancy
  defp sum_occupancies(occupancy1, occupancy2), do: occupancy1 + occupancy2

  defp set_is_mapped(%{rooms: []} = bms), do: Map.put(bms, :is_mapped, false)

  defp set_is_mapped(bms) do
    Map.put(bms, :is_mapped, Enum.all?(bms.rooms, &is_binary(&1.rate_plan_id)))
  end

  defp get_amount(nil), do: nil

  defp get_amount(%{total: %{amount_after_tax: amount, currency_code: currency}})
       when amount != "" do
    parse_money(amount, currency)
  end

  defp get_amount(%{amount_after_tax: amount, currency_code: currency}) when amount != "" do
    parse_money(amount, currency)
  end

  defp get_amount(%{amount_before_tax: amount, currency_code: currency}) when amount != "" do
    parse_money(amount, currency)
  end

  defp get_amount(%{amount: amount, currency_code: currency}) when amount != "",
    do: parse_money(amount, currency)

  defp get_amount(_), do: 0

  defp parse_money(amount, currency) do
    case Money.parse(amount, currency) do
      {:ok, %{amount: amount}} -> amount
      :error -> 0
    end
  end

  defp join_strings(strings) do
    strings
    |> Enum.uniq()
    |> Enum.join("\n")
    |> String.trim()
  end

  defp put_unless_empty(data, key, value) do
    if empty?(value), do: data, else: Map.put(data, key, value)
  end

  defp empty?(nil), do: true
  defp empty?(term) when is_binary(term), do: String.trim(term) == ""
  defp empty?(_term), do: false
end
