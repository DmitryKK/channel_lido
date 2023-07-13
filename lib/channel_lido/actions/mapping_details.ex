defmodule ChannelLido.Actions.MappingDetails do
  @moduledoc false

  @type args :: map()
  @type response :: {:ok, term(), term()} | {:error, term(), term()}

  alias ChannelLido.Services

  @doc false
  def perform(args) when is_map(args) do
    args
    |> Services.hotel_avail()
    |> format_response()

    # {:ok, %{rooms: [%{id: "MOHU", rates: [%{id: "EZI001", title: "Ezibed.com NZ"}], title: "EcoScapes"}]}, %{}}
  end

  defp format_response({:ok, %{rooms: rooms}, meta}) do
    {:ok, %{rooms: compose_rooms(rooms)}, meta}
  end

  defp format_response({:error, _result, _meta} = error_result), do: error_result

  defp compose_rooms(rooms) do
    for {{id, title}, rooms} <- Enum.group_by(rooms, &{&1.id, &1.title}) do
      %{id: id, title: title, rates: compose_rates(rooms)}
    end
  end

  defp compose_rates(rooms) do
    for %{rate: %{id: id, title: title}} <- rooms, non_read_only_rate?(id) do
      %{id: id, title: title}
    end
  end

  # TODO check out condition for read only rates
  # defp non_read_only_rate?("G" <> _id), do: false
  # defp non_read_only_rate?("g" <> _id), do: false
  defp non_read_only_rate?(_id), do: true
end
