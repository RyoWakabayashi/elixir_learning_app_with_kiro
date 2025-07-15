defmodule ElixirLearningApp.Content.LessonManagerTest do
  use ElixirLearningApp.DataCase

  alias ElixirLearningApp.Content.LessonManager
  alias ElixirLearningApp.Accounts

  describe "get_lesson/1" do
    test "returns lesson when it exists" do
      lesson = lesson_fixture(%{title: "Test Lesson", order_index: 1})
      
      assert {:ok, returned_lesson} = LessonManager.get_lesson(lesson.id)
      assert returned_lesson.id == lesson.id
      assert returned_lesson.title == "Test Lesson"
    end

    test "returns error when lesson does not exist" do
      assert {:error, :lesson_not_found} = LessonManager.get_lesson(999)
    end
  end

  describe "get_available_lessons/1" do
    setup do
      user = user_fixture()
      lesson1 = lesson_fixture(%{title: "Lesson 1", order_index: 1})
      lesson2 = lesson_fixture(%{title: "Lesson 2", order_index: 2})
      lesson3 = lesson_fixture(%{title: "Lesson 3", order_index: 3})
      
      %{user: user, lessons: [lesson1, lesson2, lesson3]}
    end

    test "returns first lesson as available for new user", %{user: user, lessons: [lesson1, lesson2, lesson3]} do
      available_lessons = LessonManager.get_available_lessons(user.id)
      
      assert length(available_lessons) == 3
      assert %{lesson: %{id: lesson1_id}, status: :available} = Enum.at(available_lessons, 0)
      assert %{lesson: %{id: lesson2_id}, status: :locked} = Enum.at(available_lessons, 1)
      assert %{lesson: %{id: lesson3_id}, status: :locked} = Enum.at(available_lessons, 2)
      
      assert lesson1_id == lesson1.id
      assert lesson2_id == lesson2.id
      assert lesson3_id == lesson3.id
    end

    test "unlocks next lesson when previous is completed", %{user: user, lessons: [lesson1, lesson2, lesson3]} do
      # Complete first lesson
      {:ok, _} = Accounts.complete_lesson(user.id, lesson1.id, "completed code")
      
      available_lessons = LessonManager.get_available_lessons(user.id)
      
      assert %{lesson: %{id: lesson1_id}, status: :completed} = Enum.at(available_lessons, 0)
      assert %{lesson: %{id: lesson2_id}, status: :available} = Enum.at(available_lessons, 1)
      assert %{lesson: %{id: lesson3_id}, status: :locked} = Enum.at(available_lessons, 2)
      
      assert lesson1_id == lesson1.id
      assert lesson2_id == lesson2.id
      assert lesson3_id == lesson3.id
    end

    test "shows progression through multiple lessons", %{user: user, lessons: [lesson1, lesson2, lesson3]} do
      # Complete first two lessons
      {:ok, _} = Accounts.complete_lesson(user.id, lesson1.id, "code1")
      {:ok, _} = Accounts.complete_lesson(user.id, lesson2.id, "code2")
      
      available_lessons = LessonManager.get_available_lessons(user.id)
      
      assert %{lesson: %{id: lesson1_id}, status: :completed} = Enum.at(available_lessons, 0)
      assert %{lesson: %{id: lesson2_id}, status: :completed} = Enum.at(available_lessons, 1)
      assert %{lesson: %{id: lesson3_id}, status: :available} = Enum.at(available_lessons, 2)
      
      assert lesson1_id == lesson1.id
      assert lesson2_id == lesson2.id
      assert lesson3_id == lesson3.id
    end
  end

  describe "get_next_lesson/1" do
    setup do
      user = user_fixture()
      lesson1 = lesson_fixture(%{title: "Lesson 1", order_index: 1})
      lesson2 = lesson_fixture(%{title: "Lesson 2", order_index: 2})
      
      %{user: user, lesson1: lesson1, lesson2: lesson2}
    end

    test "returns first lesson for new user", %{user: user, lesson1: lesson1} do
      assert {:ok, next_lesson} = LessonManager.get_next_lesson(user.id)
      assert next_lesson.id == lesson1.id
    end

    test "returns second lesson after completing first", %{user: user, lesson1: lesson1, lesson2: lesson2} do
      {:ok, _} = Accounts.complete_lesson(user.id, lesson1.id, "code")
      
      assert {:ok, next_lesson} = LessonManager.get_next_lesson(user.id)
      assert next_lesson.id == lesson2.id
    end

    test "returns nil when all lessons completed", %{user: user, lesson1: lesson1, lesson2: lesson2} do
      {:ok, _} = Accounts.complete_lesson(user.id, lesson1.id, "code1")
      {:ok, _} = Accounts.complete_lesson(user.id, lesson2.id, "code2")
      
      assert {:ok, nil} = LessonManager.get_next_lesson(user.id)
    end
  end

  describe "can_access_lesson?/2" do
    setup do
      user = user_fixture()
      lesson1 = lesson_fixture(%{title: "Lesson 1", order_index: 1})
      lesson2 = lesson_fixture(%{title: "Lesson 2", order_index: 2})
      
      %{user: user, lesson1: lesson1, lesson2: lesson2}
    end

    test "allows access to first lesson", %{user: user, lesson1: lesson1} do
      assert LessonManager.can_access_lesson?(user.id, lesson1.id) == true
    end

    test "denies access to locked lesson", %{user: user, lesson2: lesson2} do
      assert LessonManager.can_access_lesson?(user.id, lesson2.id) == false
    end

    test "allows access to unlocked lesson", %{user: user, lesson1: lesson1, lesson2: lesson2} do
      {:ok, _} = Accounts.complete_lesson(user.id, lesson1.id, "code")
      
      assert LessonManager.can_access_lesson?(user.id, lesson2.id) == true
    end

    test "allows access to completed lesson", %{user: user, lesson1: lesson1} do
      {:ok, _} = Accounts.complete_lesson(user.id, lesson1.id, "code")
      
      assert LessonManager.can_access_lesson?(user.id, lesson1.id) == true
    end
  end

  describe "check_solution/2" do
    test "validates correct solution with expected output" do
      lesson = lesson_fixture(%{
        title: "Simple Math",
        instructions: "Calculate 2 + 2",
        expected_output: "4",
        order_index: 1
      })
      
      assert {:ok, result} = LessonManager.check_solution(lesson.id, "2 + 2")
      assert result.passed == true
      assert result.execution_result.result == 4
      assert result.expected_output == "4"
    end

    test "detects incorrect solution" do
      lesson = lesson_fixture(%{
        title: "Simple Math",
        instructions: "Calculate 2 + 2",
        expected_output: "4",
        order_index: 1
      })
      
      assert {:ok, result} = LessonManager.check_solution(lesson.id, "2 + 3")
      assert result.passed == false
      assert result.execution_result.result == 5
      assert result.expected_output == "4"
      assert result.actual_output == "5"
    end

    test "handles code with output" do
      lesson = lesson_fixture(%{
        title: "IO Test",
        instructions: "Print Hello",
        expected_output: "Hello",
        order_index: 1
      })
      
      assert {:ok, result} = LessonManager.check_solution(lesson.id, "IO.puts(\"Hello\")")
      assert result.passed == true
      assert result.execution_result.output =~ "Hello"
    end

    test "handles code with errors" do
      lesson = lesson_fixture(%{
        title: "Error Test",
        expected_output: "42",
        order_index: 1
      })
      
      assert {:ok, result} = LessonManager.check_solution(lesson.id, "undefined_function()")
      assert result.passed == false
      assert result.execution_result.error != nil
      assert result.feedback =~ "error"
    end

    test "validates with test cases" do
      lesson = lesson_fixture(%{
        title: "Test Cases",
        test_cases: %{"expected_result" => 42},
        order_index: 1
      })
      
      assert {:ok, result} = LessonManager.check_solution(lesson.id, "6 * 7")
      assert result.passed == true
      assert result.execution_result.result == 42
    end

    test "returns error for non-existent lesson" do
      assert {:error, :lesson_not_found} = LessonManager.check_solution(999, "1 + 1")
    end

    test "handles dangerous code" do
      lesson = lesson_fixture(%{
        title: "Safe Test",
        expected_output: "safe",
        order_index: 1
      })
      
      assert {:error, :dangerous_code} = LessonManager.check_solution(lesson.id, "File.read(\"/etc/passwd\")")
    end
  end

  describe "submit_solution/3" do
    setup do
      user = user_fixture()
      lesson1 = lesson_fixture(%{
        title: "Math Lesson",
        instructions: "Calculate 5 + 5",
        expected_output: "10",
        order_index: 1
      })
      lesson2 = lesson_fixture(%{
        title: "Next Lesson",
        instructions: "Calculate 3 * 3",
        expected_output: "9",
        order_index: 2
      })
      
      %{user: user, lesson1: lesson1, lesson2: lesson2}
    end

    test "completes lesson with correct solution", %{user: user, lesson1: lesson1} do
      assert {:ok, result} = LessonManager.submit_solution(user.id, lesson1.id, "5 + 5")
      
      assert result.passed == true
      assert result.lesson_completed == true
      assert result.next_lesson_unlocked == true
      assert is_binary(result.feedback) and String.length(result.feedback) > 0
      
      # Verify progress was recorded
      progress = Accounts.get_user_progress(user.id, lesson1.id)
      assert progress.status == "completed"
      assert progress.last_code == "5 + 5"
    end

    test "records attempt with incorrect solution", %{user: user, lesson1: lesson1} do
      assert {:ok, result} = LessonManager.submit_solution(user.id, lesson1.id, "5 + 6")
      
      assert result.passed == false
      assert result.lesson_completed == false
      assert result.next_lesson_unlocked == false
      assert result.feedback =~ "Not quite right"
      
      # Verify attempt was recorded
      progress = Accounts.get_user_progress(user.id, lesson1.id)
      assert progress.status == "in_progress"
      assert progress.attempts == 1
      assert progress.last_code == "5 + 6"
    end

    test "prevents access to locked lesson", %{user: user, lesson2: lesson2} do
      assert {:error, :lesson_not_accessible} = LessonManager.submit_solution(user.id, lesson2.id, "3 * 3")
    end

    test "allows resubmission of completed lesson", %{user: user, lesson1: lesson1} do
      # Complete lesson first
      {:ok, _} = LessonManager.submit_solution(user.id, lesson1.id, "5 + 5")
      
      # Resubmit with different code
      assert {:ok, result} = LessonManager.submit_solution(user.id, lesson1.id, "div(20, 2)")
      assert result.passed == true
      assert result.lesson_completed == true
    end

    test "handles dangerous code submission", %{user: user, lesson1: lesson1} do
      assert {:error, :dangerous_code} = LessonManager.submit_solution(user.id, lesson1.id, "System.cmd(\"rm\", [\"-rf\", \"/\"])")
    end
  end

  describe "unlock_next_lesson/2" do
    setup do
      user = user_fixture()
      lesson1 = lesson_fixture(%{title: "Lesson 1", order_index: 1})
      lesson2 = lesson_fixture(%{title: "Lesson 2", order_index: 2})
      
      %{user: user, lesson1: lesson1, lesson2: lesson2}
    end

    test "unlocks next lesson after completion", %{user: user, lesson1: lesson1, lesson2: lesson2} do
      {:ok, _} = Accounts.complete_lesson(user.id, lesson1.id, "code")
      
      assert {:ok, next_lesson} = LessonManager.unlock_next_lesson(user.id, lesson1.id)
      assert next_lesson.id == lesson2.id
    end

    test "fails to unlock when prerequisite not completed", %{user: user, lesson1: lesson1} do
      assert {:error, :prerequisite_not_completed} = LessonManager.unlock_next_lesson(user.id, lesson1.id)
    end

    test "returns nil when no next lesson exists", %{user: user, lesson2: lesson2} do
      {:ok, _} = Accounts.complete_lesson(user.id, lesson2.id, "code")
      
      assert {:ok, nil} = LessonManager.unlock_next_lesson(user.id, lesson2.id)
    end
  end

  # Helper functions for creating test data
  defp user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        name: "Test User",
        email: "test#{System.unique_integer()}@example.com"
      })
      |> Accounts.create_user()

    user
  end

  defp lesson_fixture(attrs \\ %{}) do
    {:ok, lesson} =
      attrs
      |> Enum.into(%{
        title: "Test Lesson #{System.unique_integer()}",
        instructions: "Test instructions",
        order_index: System.unique_integer([:positive])
      })
      |> ElixirLearningApp.Content.create_lesson()

    lesson
  end
end