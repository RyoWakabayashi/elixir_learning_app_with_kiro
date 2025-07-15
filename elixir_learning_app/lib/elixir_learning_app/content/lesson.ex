defmodule ElixirLearningApp.Content.Lesson do
  use Ecto.Schema
  import Ecto.Changeset

  alias ElixirLearningApp.Accounts.UserProgress

  schema "lessons" do
    field :title, :string
    field :description, :string
    field :instructions, :string
    field :template_code, :string
    field :expected_output, :string
    field :test_cases, :map
    field :order_index, :integer
    field :difficulty, :string

    has_many :user_progress, UserProgress

    timestamps()
  end

  @doc false
  def changeset(lesson, attrs) do
    lesson
    |> cast(attrs, [:title, :description, :instructions, :template_code, :expected_output, :test_cases, :order_index, :difficulty])
    |> validate_required([:title, :instructions, :order_index])
    |> validate_length(:title, min: 1, max: 255)
    |> validate_number(:order_index, greater_than: 0)
    |> validate_inclusion(:difficulty, ["beginner", "intermediate", "advanced"], allow_nil: true)
    |> unique_constraint(:order_index)
  end
end