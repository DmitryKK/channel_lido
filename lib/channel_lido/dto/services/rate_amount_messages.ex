defmodule ChannelLido.DTO.Services.RateAmountMessages do
  @moduledoc false

  use ChannelLido.DTO

  alias ChannelLido.DTO.Services.RateAmountMessage
  alias Saxy.Builder

  defstruct [:rates, :hotel_id]

  defimpl Saxy.Builder do
    import Saxy.XML

    def build(data) do
      element("RateAmountMessages", [HotelCode: data.hotel_id], build_rates(data.rates))
    end

    def build_rates(rates) do
      for rate <- rates do
        rate
        |> RateAmountMessage.new()
        |> Builder.build()
      end
    end
  end
end
