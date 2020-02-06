defmodule ParallelDownload.MixProject do
  use Mix.Project

  def project do
    [
      app: :parallel_download,
      version: "0.1.0",
      elixir: "~> 1.9",
      config_path: "config/config.exs",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["test/support" | elixirc_paths()]
  defp elixirc_paths(_), do: elixirc_paths()
  defp elixirc_paths, do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {ParallelDownload.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end
end
