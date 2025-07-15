defmodule ElixirLearningApp.Repo do
  use Ecto.Repo,
    otp_app: :elixir_learning_app,
    adapter: Ecto.Adapters.Postgres
end
