import Config

config :channel_lido,
  requester: ChannelLido.Request,
  booking_processor: ChannelLido.Actions.PushBookings,
  broadway_producer_module: BroadwayRabbitMQ.Producer,
  rmq_connection: [host: "localhost", username: "guest", password: "guest"],
  api_url: System.get_env("LIDO_API_URL"),
  password: System.get_env("LIDO_API_PASSWORD"),
  username: System.get_env("LIDO_API_USERNAME"),
  target: System.get_env("LIDO_REQUEST_TARGET", "Development"),
  sync_chunk_size: 5000,
  pci_card_headers: %{
    tokens: "x-pci-channex-tokens",
    warnings: "x-pci-channex-warnings",
    errors: "x-pci-channex-errors"
  },
  env: config_env()

config :channel_lido, ChannelLido.PromEx,
  disabled: true,
  manual_metrics_start_delay: :no_delay,
  drop_metrics_groups: [],
  grafana: :disabled,
  metrics_server: [
    port: 4021,
    path: "/metrics",
    protocol: :http,
    pool_size: 5,
    cowboy_opts: [],
    auth_strategy: :none
  ]

config :message_queue,
  adapter: :rabbitmq,
  connection: [host: "localhost", username: "guest", password: "guest"]

config :service_agent,
  dns: 'service-discovery.default.svc.cluster.local',
  app_name: "service_discovery",
  env: config_env()

config :elixir, :time_zone_database, Tzdata.TimeZoneDatabase

config :money,
  default_currency: :EUR,
  separator: "",
  delimeter: ".",
  symbol: false

import_config "#{config_env()}.exs"
