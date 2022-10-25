defmodule DomainNameOperator.MixProject do
  use Mix.Project

  def project do
    [
      app: :domain_name_operator,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      releases: releases(),
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {DomainNameOperator.Application, []},
      extra_applications: [:logger, :sentry]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:bonny, "~> 0.4"},
      # {:bonny, "~> 0.5"},
      # {:bonny, path: "/home/ben/gitclone/bonny2"},
      {:tesla, "~> 1.4"},
      {:hackney, "~> 1.17"},
      # {:cloudflare_api, "~> 0.0"},
      {:cloudflare_api, "~> 0.1"},
      {:iptools, "~> 0.0"},
      # {:k8s, "~> 1.1.3"},
      {:number, "~> 1.0.3"},
      {:sentry, "~> 8.0"},
      {:jason, "~> 1.1"}
      # {:hackney, "~> 1.8"},
      # if you are using plug_cowboy
      # {:plug_cowboy, "~> 2.3"}
    ]
  end

  defp releases do
    [
      domain_name_operator: [
        applications: [bonny: :permanent]
      ]
    ]
  end
end
