defmodule ChannelLido.DTO.Services.AvailStatusMessage do
  @moduledoc false

  use ChannelLido.DTO

  defstruct [
    :closed,
    :date,
    :inv_type_code
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
      for {key, value} <- Map.take(data, [:closed]), not empty?(value) do
        element("AvailStatusMessage", [], [
          empty_element("StatusApplicationControl",
            Start: data.date,
            End: data.date,
            InvTypeCode: data.inv_type_code
          ),
          compose_restriction(key, value)
        ])
      end
    end

    defp compose_restriction(:closed, value) do
      empty_element("RestrictionStatus", Status: restriction_status(value))
    end

    defp restriction_status(true), do: "Close"
    defp restriction_status(false), do: "Open"

    defp empty?(nil), do: true
    defp empty?(""), do: true
    defp empty?([]), do: true
    defp empty?(_value), do: false
  end
end
