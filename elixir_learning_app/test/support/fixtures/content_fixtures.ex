defmodule ElixirLearningApp.ContentFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `ElixirLearningApp.Content` context.
  """

  alias ElixirLearningApp.Content.Lesson
  alias ElixirLearningApp.Repo

  @doc """
  Generate a lesson.
  """
  def lesson_fixture(attrs \\ %{}) do
    attrs =
      attrs
      |> Enum.into(%{
        title: "Sample Lesson",
        description: "A sample lesson for testing",
        instructions: "Complete the following task",
        template_code: "# Write your code here",
        expected_output: "Hello, World!",
        order_index: 1,
        difficulty: "beginner"
      })

    %Lesson{}
    |> Lesson.changeset(attrs)
    |> Repo.insert!()
  end
end