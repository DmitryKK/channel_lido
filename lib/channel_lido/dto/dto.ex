defmodule ChannelLido.DTO do
  @moduledoc false

  defmacro __using__(_opts) do
    quote do
      @type t() :: %__MODULE__{}

      @spec new(map()) :: t()
      def new(data \\ %{}), do: struct(__MODULE__, data)

      @spec new!(map()) :: t()
      def new!(data), do: struct!(__MODULE__, data)

      @spec update(t(), map()) :: t()
      def update(struct, data \\ %{}), do: struct(struct, data)
    end
  end
end
