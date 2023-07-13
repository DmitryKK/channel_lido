defmodule ChannelLido.DTO.Services.Inventory do
  @moduledoc false

  use ChannelLido.DTO

  defstruct [:date, :inv_count, :inv_type_code]

  @doc false
  def fields do
    %__MODULE__{}
    |> Map.from_struct()
    |> Map.keys()
  end

  defimpl Saxy.Builder do
    import Saxy.XML

    def build(data) do
      element("Inventory", [], [
        empty_element("StatusApplicationControl",
          Start: data.date,
          End: data.date,
          InvTypeCode: data.inv_type_code
        ),
        element("InvCounts", [], compose_inventories(data))
      ])
    end

    defp compose_inventories(data) do
      empty_element("InvCount", CountType: "1", Count: data.inv_count)
    end
  end
end
