defmodule ElixirLearningApp.Accounts.UserProgressTest do
  use ElixirLearningApp.DataCase

  alias ElixirLearningApp.Accounts.{User, UserProgress}
  alias ElixirLearningApp.Content.Lesson

  describe "changeset/2" do
    setup do
      user = %User{id: 1, email: "test@example.com", name: "Test User"}
      lesson = %Lesson{id: 1, title: "Test Lesson", instructions: "Learn", order_index: 1}
      
      {:ok, user: user, lesson: lesson}
    end

    test "valid changeset with required fields", %{user: user, lesson: lesson} do
      attrs = %{
        user_id: user.id,
        lesson_id: lesson.id,
        status: "in_progress",
        attempts: 1
      }
      changeset = UserProgress.changeset(%UserProgress{}, attrs)
      
      assert changeset.valid?
      assert changeset.changes.user_id == user.id
      assert changeset.changes.lesson_id == lesson.id
      assert changeset.changes.status == "in_progress"
      assert changeset.changes.attempts == 1
    end

    test "valid changeset with all fields", %{user: user, lesson: lesson} do
      completed_at = ~N[2023-01-01 12:00:00]
      attrs = %{
        user_id: user.id,
        lesson_id: lesson.id,
        status: "completed",
        attempts: 3,
        last_code: "IO.puts(\"Hello\")",
        completed_at: completed_at
      }
      changeset = UserProgress.changeset(%UserProgress{}, attrs)
      
      assert changeset.valid?
      assert changeset.changes.last_code == "IO.puts(\"Hello\")"
      assert changeset.changes.completed_at == completed_at
    end

    test "requires user_id", %{lesson: lesson} do
      attrs = %{
        lesson_id: lesson.id,
        status: "in_progress",
        attempts: 1
      }
      changeset = UserProgress.changeset(%UserProgress{}, attrs)
      
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).user_id
    end

    test "requires lesson_id", %{user: user} do
      attrs = %{
        user_id: user.id,
        status: "in_progress",
        attempts: 1
      }
      changeset = UserProgress.changeset(%UserProgress{}, attrs)
      
      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).lesson_id
    end

    test "uses default status when not provided", %{user: user, lesson: lesson} do
      attrs = %{
        user_id: user.id,
        lesson_id: lesson.id,
        attempts: 1
      }
      changeset = UserProgress.changeset(%UserProgress{}, attrs)
      
      assert changeset.valid?
      # Default status should be applied by the schema
    end

    test "uses default attempts when not provided", %{user: user, lesson: lesson} do
      attrs = %{
        user_id: user.id,
        lesson_id: lesson.id,
        status: "in_progress"
      }
      changeset = UserProgress.changeset(%UserProgress{}, attrs)
      
      assert changeset.valid?
      # Default attempts should be applied by the schema
    end

    test "validates status inclusion", %{user: user, lesson: lesson} do
      attrs = %{
        user_id: user.id,
        lesson_id: lesson.id,
        status: "invalid_status",
        attempts: 1
      }
      changeset = UserProgress.changeset(%UserProgress{}, attrs)
      
      refute changeset.valid?
      assert "is invalid" in errors_on(changeset).status
    end

    test "allows valid status values", %{user: user, lesson: lesson} do
      valid_statuses = ["not_started", "in_progress", "completed"]
      
      for status <- valid_statuses do
        attrs = %{
          user_id: user.id,
          lesson_id: lesson.id,
          status: status,
          attempts: 1
        }
        changeset = UserProgress.changeset(%UserProgress{}, attrs)
        
        assert changeset.valid?, "#{status} should be valid"
      end
    end

    test "validates attempts is non-negative", %{user: user, lesson: lesson} do
      attrs = %{
        user_id: user.id,
        lesson_id: lesson.id,
        status: "in_progress",
        attempts: -1
      }
      changeset = UserProgress.changeset(%UserProgress{}, attrs)
      
      refute changeset.valid?
      assert "must be greater than or equal to 0" in errors_on(changeset).attempts
    end

    test "allows zero attempts", %{user: user, lesson: lesson} do
      attrs = %{
        user_id: user.id,
        lesson_id: lesson.id,
        status: "not_started",
        attempts: 0
      }
      changeset = UserProgress.changeset(%UserProgress{}, attrs)
      
      assert changeset.valid?
    end
  end

  describe "complete_changeset/2" do
    test "sets status to completed and completed_at" do
      user_progress = %UserProgress{status: "in_progress", attempts: 2}
      attrs = %{last_code: "final code"}
      
      changeset = UserProgress.complete_changeset(user_progress, attrs)
      
      assert changeset.valid?
      assert changeset.changes.status == "completed"
      assert changeset.changes.last_code == "final code"
      assert changeset.changes.completed_at
    end

    test "uses provided completed_at" do
      user_progress = %UserProgress{status: "in_progress", attempts: 2}
      completed_at = ~N[2023-01-01 12:00:00]
      attrs = %{completed_at: completed_at}
      
      changeset = UserProgress.complete_changeset(user_progress, attrs)
      
      assert changeset.valid?
      assert changeset.changes.completed_at == completed_at
    end
  end

  describe "attempt_changeset/2" do
    test "sets status to in_progress and increments attempts" do
      user_progress = %UserProgress{status: "not_started", attempts: 0}
      attrs = %{last_code: "attempt code"}
      
      changeset = UserProgress.attempt_changeset(user_progress, attrs)
      
      assert changeset.valid?
      assert changeset.changes.status == "in_progress"
      assert changeset.changes.last_code == "attempt code"
      assert changeset.changes.attempts == 1
    end

    test "increments attempts from existing value" do
      user_progress = %UserProgress{status: "in_progress", attempts: 3}
      attrs = %{last_code: "another attempt"}
      
      changeset = UserProgress.attempt_changeset(user_progress, attrs)
      
      assert changeset.valid?
      assert changeset.changes.attempts == 4
    end

    test "handles nil attempts" do
      user_progress = %UserProgress{status: "not_started", attempts: nil}
      attrs = %{last_code: "first attempt"}
      
      changeset = UserProgress.attempt_changeset(user_progress, attrs)
      
      assert changeset.valid?
      assert changeset.changes.attempts == 1
    end
  end
end