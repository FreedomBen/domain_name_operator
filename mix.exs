defmodule DomainNameOperator.MixProject do
  use Mix.Project

  def project do
    [
      app: :domain_name_operator,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      releases: releases(),
      deps: deps(),
      aliases: aliases()
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
      {:bonny, "~> 1.4"},
      {:k8s, "~> 2.8"},
      {:tesla, "~> 1.15"},
      {:hackney, "~> 1.25"},
      {:cloudflare_api, "~> 0.6"},
      {:iptools, "~> 0.0.5"},
      {:number, "~> 1.0.5"},
      {:sentry, "~> 11.0"},
      {:jason, "~> 1.4"}
    ]
  end

  defp releases do
    [
      domain_name_operator: [
        applications: [bonny: :permanent]
      ]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases do
    [
      k8s_spec: "k8s.openapi.fetch"
    ]
  end
end
