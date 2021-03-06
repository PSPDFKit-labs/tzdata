defmodule Tzdata.Mixfile do
  use Mix.Project

  def project do
    [app: :tzdata,
     name: "tzdata",
     version: "0.5.3",
     elixir: "~> 1.0 or ~> 1.1",
     package: package,
     description: description,
     deps: deps]
  end

  def application do
    [
      applications: [:hackney, :logger],
      env: env,
      mod: {Tzdata.App, []}
    ]
  end

  defp deps do
    [
      {:hackney, "~> 1.0"},
      {:earmark, "~> 0.1.17", only: :dev},
      {:ex_doc, "~> 0.8", only: :dev},
    ]
  end

  defp env do
    [autoupdate: :enabled]
  end

  defp description do
    """
    Tzdata is a parser and library for the tz database.
    """
  end

  defp package do
    %{ licenses: ["MIT"],
       contributors: ["Lau Taarnskov"],
       links: %{ "GitHub" => "https://github.com/lau/tzdata"},
       files: ~w(lib priv mix.exs README* LICENSE*
                 license* CHANGELOG* changelog* src source_data) }
  end
end
