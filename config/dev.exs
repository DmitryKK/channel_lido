import Config

config :channel_lido,
  base_url: "http://localhost:4000/api/v1"

if File.exists?("config/custom.exs"), do: import_config("custom.exs")
