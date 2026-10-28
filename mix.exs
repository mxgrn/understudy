defmodule Understudy.MixProject do
  use Mix.Project

  def project do
    [
      app: :understudy,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto],
      mod: {Understudy.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:gettext, "~> 0.26"},
      {:ecto_sql, "~> 3.12"},
      {:req_llm, "~> 1.0", optional: true},
      {:postgrex, ">= 0.0.0", only: :test},
      {:mimic, "~> 1.10", only: :test}
    ]
  end
end
