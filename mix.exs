defmodule Freshness.MixProject do
  use Mix.Project

  def project do
    [
      app: :freshness,
      version: "0.1.0",
      elixir: "~> 1.9",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      source_url: "https://github.com/bottlenecked/freshness",
      docs: [main: "Freshness"]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:mint, "~> 1.0"},
      {:ex_doc, "~> 0.21", only: :dev, runtime: false}
    ]
  end

  def description(),
    do: """
    A minimal wrapper around Mint providing pooling functionality
    """

  def package(),
    do: [
      licenses: ["MIT License"],
      links: %{"GitHub" => "https://github.com/bottlenecked/freshness"}
    ]
end
