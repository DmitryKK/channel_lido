defmodule ChannelLido.Services.HotelAvail.Response do
  @moduledoc false

  alias ChannelLido.Services.HotelAvail.Mappings

  @doc false
  def parse({:ok, "<?xml" <> _ = body, meta}) do
    with {:ok, payload} <- parse_body(body, meta) do
      payload
      |> parse_xml()
      |> check_issues()
      |> append_meta(meta)
    end
  end

  def parse({:error, body, meta}) do
    {:error, %{errors: List.wrap(body)}, meta}
  end

  defp parse_body(body, meta) do
    case Saxmerl.parse_string(body, dynamic_atoms: false) do
      {:ok, payload} ->
        {:ok, payload}

      {:error, exception} when is_exception(exception) ->
        error = %{binary: exception.binary, message: Exception.message(exception)}
        {:error, %{errors: List.wrap(error)}, meta}
    end
  end

  defp parse_xml(payload) do
    {root, mapping} = Mappings.get()
    SweetXml.xpath(payload, root, mapping)
  end

  defp check_issues(%{errors: []} = parsed_xml), do: {:ok, parsed_xml}
  defp check_issues(parsed_xml), do: {:error, parsed_xml}

  defp append_meta(result, meta) do
    Tuple.append(result, meta)
  end
end
