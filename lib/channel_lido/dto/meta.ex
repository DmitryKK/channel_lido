defmodule ChannelLido.DTO.Meta do
  @moduledoc false

  use ChannelLido.DTO

  defstruct request: nil,
            response: nil,
            status_code: nil,
            method: nil,
            started_at: nil,
            finished_at: nil,
            errors: [],
            warnings: []

  defimpl Jason.Encoder do
    def encode(struct, opts) do
      struct
      |> Map.from_struct()
      |> Jason.Encode.map(opts)
    end
  end
end
