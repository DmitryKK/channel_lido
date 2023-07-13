defmodule ChannelLido.RPCReceiver do
  @moduledoc false

  use Broadway

  alias ChannelLido.Errors.SystemError

  @opts_schema [
    name: [
      doc: "Used for name registration",
      type: :atom,
      default: __MODULE__
    ],
    queue: [
      doc: "Queue we're going to consume from and bind it to the rpc exchange.",
      type: :string,
      required: true
    ],
    service_name: [
      doc:
        "The name of the service that serves as a header in the exchange to which the queue is binded.",
      type: :string,
      required: true
    ],
    concurrency: [
      doc: "The number of requests which can be proceed in parallel.",
      type: :pos_integer,
      default: 10
    ],
    connection: [
      doc: "The connection info (either a URI or a keyword list of options).",
      type: {:or, [:string, :keyword_list]},
      required: true
    ],
    module: [
      doc: "Module that contains called functions.",
      type: :atom,
      required: true
    ]
  ]

  @doc """
  Starts RPC server.

  ### Using options
  #{NimbleOptions.docs(@opts_schema)}
  """
  def start_link(init_arg) do
    opts = NimbleOptions.validate!(init_arg, @opts_schema)

    Broadway.start_link(__MODULE__,
      name: opts[:name],
      producer: [
        module:
          {producer(),
           queue: opts[:queue],
           declare: [durable: true],
           after_connect: &after_connect/1,
           bindings: [{"rpc", [arguments: binding_arguments(opts)]}],
           connection: opts[:connection],
           on_failure: :reject_and_requeue,
           qos: [prefetch_count: opts[:concurrency]],
           metadata: [:correlation_id, :reply_to]},
        concurrency: 1
      ],
      processors: [
        default: [
          concurrency: opts[:concurrency],
          max_demand: 1
        ]
      ],
      context: opts
    )
  end

  def handle_message(:default, message, context) do
    :ok =
      message.data
      |> decode_request()
      |> process_request(context)
      |> encode_response()
      |> publish_response(message.metadata)

    message
  rescue
    error ->
      report_error(error, message.data, __STACKTRACE__)
      message
  end

  defp after_connect(channel) do
    AMQP.Exchange.declare(channel, "rpc", :headers)
  end

  defp decode_request(request) do
    case MessageQueue.decode_data(request, type: :ext_binary) do
      {:ok, request} -> request
      {:error, error} -> raise error
    end
  end

  defp encode_response(response) do
    case MessageQueue.encode_data(response, type: :ext_binary) do
      {:ok, response} -> response
      {:error, error} -> raise error
    end
  end

  defp process_request(%{service_name: module, function: function, args: args}, ctx) do
    with {:ok, module} <- get_module_name(module, ctx),
         {:ok, function} <- get_function_name(function),
         true <- Code.ensure_loaded?(module),
         true <- function_exported?(module, function, length(args)) do
      apply(module, function, args)
    else
      _ -> {:error, :not_supported_method}
    end
  end

  defp publish_response(_response, %{reply_to: :undefined}), do: :ok

  defp publish_response(response, meta) do
    AMQP.Basic.publish(meta.amqp_channel, "", meta.reply_to, response,
      correlation_id: meta.correlation_id
    )
  end

  defp binding_arguments(opts) do
    [{opts[:service_name], true}, {"x-match", "any"}]
  end

  defp get_module_name(service_name, ctx) do
    case ctx[:service_name] == service_name do
      true -> {:ok, ctx[:module]}
      false -> :error
    end
  end

  defp get_function_name(function) do
    {:ok, to_atom(function)}
  rescue
    _ -> :error
  end

  defp report_error(error, message, stacktrace) do
    payload = %{error: error, message: message}
    SystemError.new("ChannelLido.RPCReceiver Error", payload, stacktrace)
  end

  defp producer, do: Application.fetch_env!(:channel_lido, :broadway_producer_module)

  defp to_atom(str) when is_atom(str), do: str
  defp to_atom(str) when is_binary(str), do: String.to_atom(str)
end
