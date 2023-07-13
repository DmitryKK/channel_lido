defmodule ChannelLido.DTO.ChangesToSync do
  @moduledoc false

  use ChannelLido.DTO

  @enforce_keys [
    :currency,
    :date,
    :occupancy,
    :inv_type_code,
    :rate_plan_code
  ]

  defstruct [
    :closed,
    :rate,
    :inv_count
    | @enforce_keys
  ]
end
