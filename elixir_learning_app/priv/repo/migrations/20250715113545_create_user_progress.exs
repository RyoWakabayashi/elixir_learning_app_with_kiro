defmodule ElixirLearningApp.Repo.Migrations.CreateUserProgress do
  use Ecto.Migration

  def change do
    create table(:user_progress) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :lesson_id, references(:lessons, on_delete: :delete_all), null: false
      add :status, :string, default: "not_started", null: false
      add :attempts, :integer, default: 0, null: false
      add :last_code, :text
      add :completed_at, :naive_datetime

      timestamps()
    end

    create unique_index(:user_progress, [:user_id, :lesson_id])
    create index(:user_progress, [:user_id])
    create index(:user_progress, [:lesson_id])
    create index(:user_progress, [:status])
  end
end
