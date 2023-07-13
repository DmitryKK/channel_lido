import Config

config :channel_lido,
  rmq_connection: [host: "rabbitmq", username: "guest", password: "guest"]

config :message_queue,
  connection: [host: "rabbitmq", username: "guest", password: "guest"]

config :appsignal, :config,
  otp_app: :channel_lido,
  active: true,
  env: config_env()
