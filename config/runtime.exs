import Config

if config_env() == :prod do
  config :channel_lido,
    api_url: System.get_env("LIDO_API_URL"),
    password: System.get_env("LIDO_API_PASSWORD"),
    username: System.get_env("LIDO_API_USERNAME")

  config :channel_lido, ChannelLido.PromEx,
    disabled: false,
    grafana: [
      host: System.get_env("GRAFANA_HOST", "http://grafana-service:3000"),
      username: System.get_env("GRAFANA_USERNAME"),
      password: System.get_env("GRAFANA_PASSWORD"),
      upload_dashboards_on_start: true
    ]

  config :appsignal, :config,
    name: System.get_env("APPSIGNAL_APP_NAME"),
    push_api_key: System.get_env("APPSIGNAL_API_KEY")

  with proxies when is_binary(proxies) <- System.get_env("PROXY_ADDRESSES") do
    config :http_client,
           :proxy,
           proxies
           |> String.split(";")
           |> Enum.map(fn url ->
             [address, port] = String.split(url, ":")
             %{scheme: :http, address: address, port: port, opts: []}
           end)
  end
end
