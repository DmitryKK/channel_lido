defmodule ChannelLido.DTO.Services.Inventories do
  @moduledoc false

  use ChannelLido.DTO

  alias ChannelLido.DTO.Services.Inventory
  alias Saxy.Builder

  defstruct [:inventories, :hotel_id]

  defimpl Saxy.Builder do
    import Saxy.XML

    def build(data) do
      element("Inventories", [HotelCode: data.hotel_id], build_inventories(data.inventories))
    end

    def build_inventories(inventories) do
      for inventory <- inventories do
        inventory
        |> Inventory.new()
        |> Builder.build()
      end
    end
  end
end
