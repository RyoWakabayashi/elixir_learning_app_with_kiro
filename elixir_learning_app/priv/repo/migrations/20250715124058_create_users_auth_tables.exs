defmodule ElixirLearningApp.Repo.Migrations.CreateUsersAuthTables do
  use Ecto.Migration

  def change do
    execute "CREATE EXTENSION IF NOT EXISTS citext", ""

    # Add authentication fields to existing users table
    alter table(:users) do
      add :hashed_password, :string
      add :confirmed_at, :utc_datetime
    end

    # Change email column to citext for case-insensitive emails
    execute "ALTER TABLE users ALTER COLUMN email TYPE citext", "ALTER TABLE users ALTER COLUMN email TYPE varchar(255)"

    create table(:users_tokens) do
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false
      add :sent_to, :string

      timestamps(type: :utc_datetime, updated_at: false)
    end

    create index(:users_tokens, [:user_id])
    create unique_index(:users_tokens, [:context, :token])
  end
end
