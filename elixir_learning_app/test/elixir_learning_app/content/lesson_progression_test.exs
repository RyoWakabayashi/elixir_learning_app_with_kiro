defmodule ElixirLearningApp.Content.LessonProgressionTest do
  use ElixirLearningApp.DataCase

  alias ElixirLearningApp.Content.LessonManager
  alias ElixirLearningApp.Accounts

  describe "lesson progression flow with seed data" do
    setup do
      # Run seeds to create lesson data
      Code.eval_file("priv/repo/seeds.exs")
      
      # Create a test user
      {:ok, user} = Accounts.create_user(%{
        name: "Test User",
        email: "test#{System.unique_integer()}@example.com"
      })
      
      %{user: user}
    end

    test "user can progress through lessons sequentially", %{user: user} do
      # Test lesson 1 - Basic Arithmetic
      available_lessons = LessonManager.get_available_lessons(user.id)
      assert length(available_lessons) == 10
      
      # First lesson should be available, others locked
      assert %{lesson: lesson1, status: :available} = Enum.at(available_lessons, 0)
      assert %{lesson: _lesson2, status: :locked} = Enum.at(available_lessons, 1)
      
      # Complete lesson 1 with correct answer
      assert {:ok, result} = LessonManager.submit_solution(user.id, lesson1.id, "15 + 27")
      assert result.passed == true
      assert result.lesson_completed == true
      assert result.next_lesson_unlocked == true
      
      # Check that lesson 2 is now available
      available_lessons = LessonManager.get_available_lessons(user.id)
      assert %{lesson: _lesson1, status: :completed} = Enum.at(available_lessons, 0)
      assert %{lesson: lesson2, status: :available} = Enum.at(available_lessons, 1)
      assert %{lesson: _lesson3, status: :locked} = Enum.at(available_lessons, 2)
      
      # Complete lesson 2 - Variables
      code = """
      result = 8 * 7
      result
      """
      assert {:ok, result} = LessonManager.submit_solution(user.id, lesson2.id, code)
      assert result.passed == true
      assert result.lesson_completed == true
    end

    test "incorrect solutions don't unlock next lesson", %{user: user} do
      available_lessons = LessonManager.get_available_lessons(user.id)
      lesson1 = Enum.at(available_lessons, 0).lesson
      
      # Submit wrong answer
      assert {:ok, result} = LessonManager.submit_solution(user.id, lesson1.id, "15 + 28")
      assert result.passed == false
      assert result.lesson_completed == false
      assert result.next_lesson_unlocked == false
      
      # Verify lesson 2 is still locked
      available_lessons = LessonManager.get_available_lessons(user.id)
      assert %{lesson: _lesson1, status: :available} = Enum.at(available_lessons, 0)
      assert %{lesson: _lesson2, status: :locked} = Enum.at(available_lessons, 1)
    end

    test "can test various lesson solutions", %{user: user} do
      available_lessons = LessonManager.get_available_lessons(user.id)
      
      # Test lesson 1 - Basic Arithmetic
      lesson1 = Enum.at(available_lessons, 0).lesson
      assert {:ok, result} = LessonManager.check_solution(lesson1.id, "15 + 27")
      assert result.passed == true
      assert result.execution_result.result == 42
      
      # Complete lesson 1 to unlock lesson 2
      {:ok, _} = LessonManager.submit_solution(user.id, lesson1.id, "15 + 27")
      
      # Test lesson 2 - Variables
      available_lessons = LessonManager.get_available_lessons(user.id)
      lesson2 = Enum.at(available_lessons, 1).lesson
      
      code = """
      result = 8 * 7
      result
      """
      assert {:ok, result} = LessonManager.check_solution(lesson2.id, code)
      assert result.passed == true
      assert result.execution_result.result == 56
    end

    test "string interpolation lesson works correctly", %{user: user} do
      # Complete first two lessons to get to lesson 3
      available_lessons = LessonManager.get_available_lessons(user.id)
      lesson1 = Enum.at(available_lessons, 0).lesson
      {:ok, _} = LessonManager.submit_solution(user.id, lesson1.id, "15 + 27")
      
      available_lessons = LessonManager.get_available_lessons(user.id)
      lesson2 = Enum.at(available_lessons, 1).lesson
      {:ok, _} = LessonManager.submit_solution(user.id, lesson2.id, "result = 8 * 7\nresult")
      
      # Test lesson 3 - String interpolation
      available_lessons = LessonManager.get_available_lessons(user.id)
      lesson3 = Enum.at(available_lessons, 2).lesson
      
      code = ~S"""
      name = "Elixir"
      greeting = "Hello, #{name}!"
      greeting
      """
      assert {:ok, result} = LessonManager.check_solution(lesson3.id, code)
      assert result.passed == true
      assert result.execution_result.result == "Hello, Elixir!"
    end

    test "list operations lesson works correctly", %{user: user} do
      # Complete lessons 1-3 to get to lesson 4
      lessons = complete_lessons(user.id, 3)
      lesson4 = Enum.at(lessons, 3).lesson
      
      code = """
      numbers = [10, 20, 30, 40, 50]
      length(numbers)
      """
      assert {:ok, result} = LessonManager.check_solution(lesson4.id, code)
      assert result.passed == true
      assert result.execution_result.result == 5
    end

    test "function lesson works correctly", %{user: user} do
      # Complete lessons 1-4 to get to lesson 5
      lessons = complete_lessons(user.id, 4)
      lesson5 = Enum.at(lessons, 4).lesson
      
      code = """
      multiply = fn a, b -> a * b end
      multiply.(6, 9)
      """
      assert {:ok, result} = LessonManager.check_solution(lesson5.id, code)
      assert result.passed == true
      assert result.execution_result.result == 54
    end
  end

  # Helper function to complete multiple lessons
  defp complete_lessons(user_id, count) do
    solutions = [
      "15 + 27",                                    # Lesson 1
      "result = 8 * 7\nresult",                    # Lesson 2
      ~S[name = "Elixir"
greeting = "Hello, #{name}!"
greeting], # Lesson 3
      "numbers = [10, 20, 30, 40, 50]\nlength(numbers)"  # Lesson 4
    ]
    
    Enum.reduce(0..(count-1), [], fn i, _acc ->
      available_lessons = LessonManager.get_available_lessons(user_id)
      lesson = Enum.at(available_lessons, i).lesson
      {:ok, _} = LessonManager.submit_solution(user_id, lesson.id, Enum.at(solutions, i))
      LessonManager.get_available_lessons(user_id)
    end)
  end
end