defmodule ElixirLearningApp.Accounts.UserProgress do
  use Ecto.Schema
  import Ecto.Changeset

  alias ElixirLearningApp.Accounts.User
  alias ElixirLearningApp.Content.Lesson

  schema "user_progress" do
    field :status, :string, default: "not_started"
    field :attempts, :integer, default: 0
    field :last_code, :string
    field :completed_at, :naive_datetime

    belongs_to :user, User
    belongs_to :lesson, Lesson

    timestamps()
  end

  @doc false
  def changeset(user_progress, attrs) do
    user_progress
    |> cast(attrs, [:status, :attempts, :last_code, :completed_at, :user_id, :lesson_id])
    |> validate_required([:status, :attempts, :user_id, :lesson_id])
    |> validate_inclusion(:status, ["not_started", "in_progress", "completed"])
    |> validate_number(:attempts, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:lesson_id)
    |> unique_constraint([:user_id, :lesson_id])
  end

  @doc """
  Changeset for marking a lesson as completed.
  """
  def complete_changeset(user_progress, attrs \\ %{}) do
    completed_at = attrs[:completed_at] || NaiveDateTime.utc_now() |> NaiveDateTime.truncate(:second)
    
    user_progress
    |> cast(attrs, [:last_code, :completed_at])
    |> put_change(:status, "completed")
    |> put_change(:completed_at, completed_at)
  end

  @doc """
  Changeset for updating progress during lesson attempt.
  """
  def attempt_changeset(user_progress, attrs \\ %{}) do
    current_attempts = Map.get(user_progress, :attempts, 0) || 0
    
    user_progress
    |> cast(attrs, [:last_code])
    |> put_change(:status, "in_progress")
    |> put_change(:attempts, current_attempts + 1)
  end
end