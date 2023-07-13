defmodule ChannelLido.Errors do
  @moduledoc """
  Errors data type definitions
  """

  defmacro __using__(_opts) do
    quote do
      require Logger

      defexception code: nil, message: nil, stacktrace: nil, meta: %{}

      @doc false
      def message(%__MODULE__{message: message, meta: meta, stacktrace: stacktrace}) do
        """
        Message: #{message}
        Metadata: #{inspect(meta, limit: :infinity)}
        Stacktrace: #{inspect(stacktrace)}
        """
      end

      @doc false
      def new(message, meta, stacktrace \\ [], env \\ get_env())

      def new(message, meta, stacktrace, env) when env not in [:dev, :test] do
        Appsignal.send_error(:error, format_reason(message, meta), stacktrace)

        __MODULE__
        |> struct(code: :sytem_error, message: message, meta: meta, stacktrace: stacktrace)
        |> message()
        |> Logger.error()
      end

      defp format_reason(message, meta) when is_map(meta) do
        info = Map.put(meta, :context, inspect(message, limit: :infinity))
        %RuntimeError{message: inspect(info, limit: :infinity)}
      end

      defp format_reason(message, meta) do
        info = %{
          meta: inspect(meta, limit: :infinity),
          context: inspect(message, limit: :infinity)
        }

        %RuntimeError{message: inspect(info, limit: :infinity)}
      end

      defp get_env, do: Application.get_env(:channel_lido, :env)

      defimpl Jason.Encoder, for: __MODULE__ do
        def encode(struct, opts) do
          struct
          |> Map.from_struct()
          |> Jason.Encode.map(opts)
        end
      end
    end
  end
end
