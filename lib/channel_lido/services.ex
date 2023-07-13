defmodule ChannelLido.Services do
  @moduledoc """
  Service that enables suppliers to push availability, rate, and
  inventory updates.
  """

  alias __MODULE__.{
    HotelAvail,
    HotelAvailNotif,
    HotelInvCountNotif,
    HotelRateAmountNotif
  }

  @spec hotel_avail(HotelAvail.args()) :: HotelAvail.response()
  def hotel_avail(args) do
    HotelAvail.perform(args)
  end

  @spec hotel_avail_notif(HotelAvailNotif.args()) :: HotelAvailNotif.response()
  def hotel_avail_notif(args) do
    HotelAvailNotif.perform(args)
  end

  @spec hotel_inv_count_notif(HotelInvCountNotif.args()) :: HotelInvCountNotif.response()
  def hotel_inv_count_notif(args) do
    HotelInvCountNotif.perform(args)
  end

  @spec hotel_rate_amount_notif(HotelRateAmountNotif.args()) :: HotelRateAmountNotif.response()
  def hotel_rate_amount_notif(args) do
    HotelRateAmountNotif.perform(args)
  end
end
