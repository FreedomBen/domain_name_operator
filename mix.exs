defmodule DomainNameOperator.MixProject do
  use Mix.Project

  def project do
    [
      app: :domain_name_operator,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {DomainNameOperator.Application, []},
      extra_applications: [:logger]
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
      {:number, "~> 1.0.3"}
    ]
  end
end
