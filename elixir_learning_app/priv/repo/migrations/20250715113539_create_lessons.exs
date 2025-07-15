defmodule ElixirLearningApp.Repo.Migrations.CreateLessons do
  use Ecto.Migration

  def change do
    create table(:lessons) do
      add :title, :string, null: false
      add :description, :text
      add :instructions, :text, null: false
      add :template_code, :text
      add :expected_output, :text
      add :test_cases, :map
      add :order_index, :integer, null: false
      add :difficulty, :string

      timestamps()
    end

    create unique_index(:lessons, [:order_index])
    create index(:lessons, [:difficulty])
  end
end
