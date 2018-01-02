defmodule BitfinexApi.Mixfile do
  use Mix.Project

  def project do
    [
      app: :bitfinex_api,
      version: "0.1.0",
      elixir: "~> 1.5",
      source_url: "https://github.com/slavaVA/BitfinexApi.Ex.git",
      start_permanent: Mix.env == :prod,
      deps: deps(),
      aliases: aliases(),
      test_coverage: [tool: Coverex.Task, log: :info, coveralls: true],
      dialyzer: [plt_add_deps: :apps_direct]
    ]
  end

  defp aliases do
    [
      test_cover: "test --cover"
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :websockex, :tesla],
      mod: {BitfinexApi.Public.Ws.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"},
      {:websockex, "~> 0.4.0"},
      {:poison, "~> 3.1"}, # json parser
      {:exactor, "~> 2.2.3", warn_missing: false},
      {:ok, "~> 1.9"},
      {:tesla, "~> 0.9.0"},
      {:mock, "~> 0.2.0", only: :test},
      {:credo, "~> 0.3", only: [:dev, :test], runtime: false},
      {:coverex, "~> 1.4.10", only: :test},
      {:dialyxir, "~> 0.5", only: [:dev], runtime: false}
    ]
  end
end
