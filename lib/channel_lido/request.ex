defmodule ChannelLido.Request do
  @moduledoc false

  defstruct method: :post,
            headers: [],
            opts: [],
            payload: "",
            url: nil

  use HTTPClient, adapter: :finch

  alias ChannelLido.DTO.Meta

  @type t() :: %__MODULE__{}
  @type response() :: {:ok | :error | :network_error, term(), Meta.t()}

  @callback new(data :: map()) :: t()
  @callback perform(request :: t()) :: response()

  @request_timeout :timer.seconds(60)

  @doc "Builds `ChannelLido.Request` struct with provided data."
  @spec new(map()) :: t()
  def new(data) do
    struct(%__MODULE__{}, data)
  end

  @doc "Sends HTTP requests to endpoints."
  def perform(request) do
    method = set_method(request)
    payload = set_payload(request)
    headers = set_headers(request)
    opts = set_opts(request)
    meta = Meta.new(%{request: payload, started_at: NaiveDateTime.utc_now()})

    case request(method, url(), payload, headers, opts) do
      {:ok, %{status: status} = response} when status in 200..204 ->
        {:ok, format_response(response), finalize_meta(meta, response)}

      {:ok, response} ->
        {:error, format_response(response), finalize_meta(meta, response)}

      {:error, exception} when is_exception(exception) ->
        message = Exception.message(exception)
        response = %{code: "network_error", message: message}
        {:network_error, response, finalize_meta(meta, response, message)}
    end
  end

  defp set_method(%{method: method}), do: method

  defp set_payload(%{payload: payload}), do: payload

  defp set_headers(%{headers: headers}) do
    Keyword.put(headers, :content_type, "application/soap+xml; charset=utf-8")
  end

  defp set_opts(%{opts: opts}) do
    opts
    |> Keyword.put(:raw, false)
    |> Keyword.put(:recv_timeout, @request_timeout)
    |> Keyword.put(:timeout, @request_timeout)
  end

  defp format_response(%{body: body}), do: body

  defp finalize_meta(meta, response, errors \\ []) do
    Meta.update(meta, %{
      status_code: Map.get(response, :status),
      response: format_response(response),
      finished_at: NaiveDateTime.utc_now(),
      errors: meta.errors ++ errors
    })
  end

  defp url, do: Application.fetch_env!(:channel_lido, :api_url)
end
