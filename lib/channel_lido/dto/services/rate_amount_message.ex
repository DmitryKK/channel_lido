defmodule ChannelLido.DTO.Services.RateAmountMessage do
  @moduledoc false

  use ChannelLido.DTO

  defstruct [
    :date,
    :inv_type_code,
    :occupancy,
    :rate,
    :rate_plan_code
  ]

  @doc false
  def fields do
    %__MODULE__{}
    |> Map.from_struct()
    |> Map.keys()
  end

  defimpl Saxy.Builder do
    import Saxy.XML

    def build(data) do
      element("RateAmountMessage", [], [
        empty_element("StatusApplicationControl",
          InvTypeCode: data.inv_type_code,
          RatePlanCode: data.rate_plan_code
        ),
        element("Rates", [], compose_rates(data))
      ])
    end

    defp compose_rates(data) do
      element("Rate", [Start: data.date, End: data.date], [
        base_by_guest_amts(data)
      ])
    end

    defp base_by_guest_amts(%{rate: rates, occupancy: occupancies}) when is_list(rates) do
      for {occupancy, rate} <- Enum.zip(occupancies, rates) do
        base_by_guest_amts(%{rate: rate, occupancy: occupancy})
      end
    end

    defp base_by_guest_amts(data) do
      element("BaseByGuestAmts", [], base_by_guest_amt(data))
    end

    defp base_by_guest_amt(data) do
      empty_element("BaseByGuestAmt", AmountAfterTax: data.rate, NumberOfGuests: data.occupancy)
    end
  end
end
