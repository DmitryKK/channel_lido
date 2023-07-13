defmodule ChannelLido.MixProject do
  use Mix.Project

  @version "0.2.1"

  def project do
    [
      app: :channel_lido,
      version: @version,
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      releases: releases(),
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {ChannelLido.Application, []}
    ]
  end

  defp releases do
    [
      channel_lido: [
        applications: [
          channel_lido: :permanent,
          runtime_tools: :permanent
        ],
        version: @version
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:booking_message, git: "git@github.com:ChannexIO/booking_message.git", tag: "v0.3.0"},
      {:service_agent, git: "git@github.com:ChannexIO/core_service_agent.git", tag: "v1.0.1"},
      {:http_client, github: "ChannexIO/http_client", branch: "add-steps"},
      {:message_queue, github: "ChannexIO/message_queue", tag: "v0.6.4"},
      {:saxy, "~> 1.5"},
      {:saxmerl, "~> 0.1"},
      {:sweet_xml, "~> 0.7"},
      {:appsignal, "~> 2.7"},
      {:broadway_rabbitmq, "~> 0.7"},
      {:observer_cli, "~> 1.7"},
      {:tzdata, "~> 1.1"},
      {:prom_ex, "~> 1.8"},
      {:money, "~> 1.12"},
      {:ex_doc, "~> 0.29", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:mox, "~> 1.0", only: :test}
    ]
  end
end
