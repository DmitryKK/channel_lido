defmodule ChannelLido.Application do
  @moduledoc false

  use Application

  alias ChannelLido.{
    ChannelsCache,
    PromEx,
    RPCReceiver,
    Subscriber
  }

  @impl true
  def start(_type, _args) do
    children = [
      ChannelsCache,
      {RPCReceiver, rpc_receiver_opts()},
      Subscriber,
      PromEx
    ]

    opts = [strategy: :one_for_one, name: ChannelLido.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp rpc_receiver_opts do
    [
      service_name: "Lido",
      queue: "channel_lido.rpcs",
      connection: connection(),
      module: ChannelLido
    ]
  end

  defp connection, do: Application.fetch_env!(:channel_lido, :rmq_connection)
end
