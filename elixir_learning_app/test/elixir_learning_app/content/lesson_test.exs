defmodule ElixirLearningApp.Content.LessonTest do
  use ElixirLearningApp.DataCase

  alias ElixirLearningApp.Content.Lesson

  describe "changeset/2" do
    test "valid changeset with required fields" do
      attrs = %{
        title: "Test Lesson",
        instructions: "Learn basic Elixir syntax",
        order_index: 1
      }
      changeset = Lesson.changeset(%Lesson{}, attrs)
      
      assert changeset.valid?
      assert changeset.changes.title == "Test Lesson"
      assert changeset.changes.instructions == "Learn basic Elixir syntax"
      assert changeset.changes.order_index == 1
    end

    test "valid changeset with all fields" do
      attrs = %{
        title: "Advanced Lesson",
        description: "This is a detailed lesson",
        instructions: "Complete the following tasks",
        template_code: "defmodule Test do\nend",
        expected_output: "Test output",
        test_cases: %{"input" => "output"},
        order_index: 5,
        difficulty: "advanced"
      }
      changeset = Lesson.changeset(%Lesson{}, attrs)
      
      assert changeset.valid?
      assert changeset.changes.difficulty == "advanced"
      assert changeset.changes.test_cases == %{"input" => "output"}
    end

    test "requires title" do
      attrs = %{instructions: "Learn something", order_index: 1}
      changeset = Lesson.changeset(%Lesson{}, attrs)
      
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).title
    end

    test "requires instructions" do
      attrs = %{title: "Test Lesson", order_index: 1}
      changeset = Lesson.changeset(%Lesson{}, attrs)
      
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).instructions
    end

    test "requires order_index" do
      attrs = %{title: "Test Lesson", instructions: "Learn something"}
      changeset = Lesson.changeset(%Lesson{}, attrs)
      
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).order_index
    end

    test "validates title length" do
      attrs = %{
        title: "",
        instructions: "Learn something",
        order_index: 1
      }
      changeset = Lesson.changeset(%Lesson{}, attrs)
      
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).title
    end

    test "validates title max length" do
      long_title = String.duplicate("a", 256)
      attrs = %{
        title: long_title,
        instructions: "Learn something",
        order_index: 1
      }
      changeset = Lesson.changeset(%Lesson{}, attrs)
      
      refute changeset.valid?
      assert "should be at most 255 character(s)" in errors_on(changeset).title
    end

    test "validates order_index is positive" do
      attrs = %{
        title: "Test Lesson",
        instructions: "Learn something",
        order_index: 0
      }
      changeset = Lesson.changeset(%Lesson{}, attrs)
      
      refute changeset.valid?
      assert "must be greater than 0" in errors_on(changeset).order_index
    end

    test "validates difficulty inclusion" do
      attrs = %{
        title: "Test Lesson",
        instructions: "Learn something",
        order_index: 1,
        difficulty: "invalid"
      }
      changeset = Lesson.changeset(%Lesson{}, attrs)
      
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).difficulty
    end

    test "allows valid difficulty values" do
      valid_difficulties = ["beginner", "intermediate", "advanced"]
      
      for difficulty <- valid_difficulties do
        attrs = %{
          title: "Test Lesson",
          instructions: "Learn something",
          order_index: 1,
          difficulty: difficulty
        }
        changeset = Lesson.changeset(%Lesson{}, attrs)
        
        assert changeset.valid?, "#{difficulty} should be valid"
      end
    end

    test "allows nil difficulty" do
      attrs = %{
        title: "Test Lesson",
        instructions: "Learn something",
        order_index: 1,
        difficulty: nil
      }
      changeset = Lesson.changeset(%Lesson{}, attrs)
      
      assert changeset.valid?
    end
  end
end