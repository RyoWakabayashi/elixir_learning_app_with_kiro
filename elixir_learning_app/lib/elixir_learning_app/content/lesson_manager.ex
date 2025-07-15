defmodule ElixirLearningApp.Content.LessonManager do
  @moduledoc """
  Manages lesson retrieval, validation, solution checking, and progression logic.
  
  This module provides the core business logic for the learning application:
  - Retrieving lessons based on user progress
  - Validating user solutions against expected outputs
  - Managing lesson progression and unlocking
  - Checking lesson prerequisites
  """

  import Ecto.Query, warn: false
  
  alias ElixirLearningApp.Repo
  alias ElixirLearningApp.Content.Lesson
  alias ElixirLearningApp.Accounts
  alias ElixirLearningApp.Accounts.ProgressBroadcaster
  alias ElixirLearningApp.Accounts.ProgressStats
  alias ElixirLearningApp.Execution.CodeExecutor

  @doc """
  Gets a lesson by ID with validation.
  
  Returns the lesson if it exists, otherwise returns an error.
  
  ## Examples
  
      iex> LessonManager.get_lesson(1)
      {:ok, %Lesson{}}
      
      iex> LessonManager.get_lesson(999)
      {:error, :lesson_not_found}
  """
  def get_lesson(lesson_id) when is_integer(lesson_id) do
    case Repo.get(Lesson, lesson_id) do
      nil -> {:error, :lesson_not_found}
      lesson -> {:ok, lesson}
    end
  end

  @doc """
  Gets available lessons for a user based on their progress.
  
  Returns a list of lessons with their availability status:
  - completed: User has completed this lesson
  - available: User can access this lesson
  - locked: User cannot access this lesson yet
  
  ## Examples
  
      iex> LessonManager.get_available_lessons(user_id)
      [
        %{lesson: %Lesson{order_index: 1}, status: :completed},
        %{lesson: %Lesson{order_index: 2}, status: :available},
        %{lesson: %Lesson{order_index: 3}, status: :locked}
      ]
  """
  def get_available_lessons(user_id) when is_integer(user_id) do
    lessons = 
      Lesson
      |> order_by(:order_index)
      |> Repo.all()
    
    user_progress = Accounts.get_user_progress_list(user_id)
    progress_map = Map.new(user_progress, fn up -> {up.lesson_id, up.status} end)
    
    {result, _} = Enum.map_reduce(lessons, true, fn lesson, can_access ->
      progress_status = Map.get(progress_map, lesson.id, "not_started")
      
      status = cond do
        progress_status == "completed" -> 
          {:completed, true}
        can_access -> 
          {:available, progress_status == "completed"}
        true -> 
          {:locked, false}
      end
      
      {lesson_status, next_can_access} = status
      
      {%{lesson: lesson, status: lesson_status}, next_can_access}
    end)
    
    result
  end

  @doc """
  Gets the next available lesson for a user.
  
  Returns the first lesson that is available but not completed,
  or nil if all lessons are completed.
  
  ## Examples
  
      iex> LessonManager.get_next_lesson(user_id)
      {:ok, %Lesson{}}
      
      iex> LessonManager.get_next_lesson(user_id) # all completed
      {:ok, nil}
  """
  def get_next_lesson(user_id) when is_integer(user_id) do
    available_lessons = get_available_lessons(user_id)
    
    next_lesson = 
      available_lessons
      |> Enum.find(fn %{status: status} -> status == :available end)
      |> case do
        nil -> nil
        %{lesson: lesson} -> lesson
      end
    
    {:ok, next_lesson}
  end

  @doc """
  Checks if a user can access a specific lesson.
  
  ## Examples
  
      iex> LessonManager.can_access_lesson?(user_id, lesson_id)
      true
      
      iex> LessonManager.can_access_lesson?(user_id, locked_lesson_id)
      false
  """
  def can_access_lesson?(user_id, lesson_id) when is_integer(user_id) and is_integer(lesson_id) do
    available_lessons = get_available_lessons(user_id)
    
    Enum.any?(available_lessons, fn
      %{lesson: %{id: ^lesson_id}, status: status} when status in [:available, :completed] -> true
      _ -> false
    end)
  end

  @doc """
  Checks a user's solution against the lesson requirements.
  
  Executes the user's code and compares the output with expected results.
  Returns detailed feedback about the solution.
  
  ## Examples
  
      iex> LessonManager.check_solution(lesson_id, user_code)
      {:ok, %{
        passed: true,
        execution_result: %{result: 42, output: "", error: nil},
        expected_output: "42",
        feedback: "Correct! Well done."
      }}
      
      iex> LessonManager.check_solution(lesson_id, wrong_code)
      {:ok, %{
        passed: false,
        execution_result: %{result: 24, output: "", error: nil},
        expected_output: "42",
        feedback: "Expected 42, but got 24. Try again!"
      }}
  """
  def check_solution(lesson_id, user_code) when is_integer(lesson_id) and is_binary(user_code) do
    with {:ok, lesson} <- get_lesson(lesson_id),
         {:ok, execution_result} <- CodeExecutor.execute(user_code) do
      
      check_result = evaluate_solution(lesson, execution_result)
      {:ok, check_result}
    else
      {:error, :lesson_not_found} -> {:error, :lesson_not_found}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Submits a solution and updates user progress if correct.
  
  This function combines solution checking with progress tracking.
  If the solution is correct, it marks the lesson as completed and
  potentially unlocks the next lesson.
  
  ## Examples
  
      iex> LessonManager.submit_solution(user_id, lesson_id, correct_code)
      {:ok, %{
        passed: true,
        lesson_completed: true,
        next_lesson_unlocked: true,
        feedback: "Excellent work!"
      }}
  """
  def submit_solution(user_id, lesson_id, user_code) 
      when is_integer(user_id) and is_integer(lesson_id) and is_binary(user_code) do
    
    with {:ok, lesson} <- get_lesson(lesson_id),
         true <- can_access_lesson?(user_id, lesson_id),
         {:ok, check_result} <- check_solution(lesson_id, user_code) do
      
      # Record the attempt
      {:ok, _} = Accounts.record_attempt(user_id, lesson_id, user_code)
      
      result = if check_result.passed do
        # Mark lesson as completed
        {:ok, _} = Accounts.complete_lesson(user_id, lesson_id, user_code)
        
        # Broadcast lesson completion
        ProgressBroadcaster.broadcast_lesson_completed(user_id, lesson_id, lesson.title)
        
        # Update and broadcast statistics
        Task.start(fn -> 
          ProgressStats.update_and_broadcast_stats()
          ProgressStats.update_and_broadcast_lesson_stats(lesson_id)
        end)
        
        # Check if next lesson is unlocked
        next_lesson_unlocked = check_next_lesson_unlocked(user_id, lesson.order_index)
        
        # If next lesson is unlocked, broadcast that too
        if next_lesson_unlocked do
          case get_lesson_by_order(lesson.order_index + 1) do
            {:ok, next_lesson} ->
              ProgressBroadcaster.broadcast_lesson_unlocked(user_id, next_lesson.id, next_lesson.title)
            _ -> :ok
          end
        end
        
        Map.merge(check_result, %{
          lesson_completed: true,
          next_lesson_unlocked: next_lesson_unlocked,
          feedback: generate_success_feedback(lesson)
        })
      else
        Map.merge(check_result, %{
          lesson_completed: false,
          next_lesson_unlocked: false,
          feedback: generate_failure_feedback(lesson, check_result)
        })
      end
      
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
      false -> {:error, :lesson_not_accessible}
    end
  end

  @doc """
  Unlocks the next lesson for a user if prerequisites are met.
  
  This is typically called after a lesson is completed to ensure
  the next lesson becomes available.
  """
  def unlock_next_lesson(user_id, current_lesson_id) 
      when is_integer(user_id) and is_integer(current_lesson_id) do
    
    with {:ok, current_lesson} <- get_lesson(current_lesson_id),
         {:ok, next_lesson} <- get_lesson_by_order(current_lesson.order_index + 1) do
      
      # Check if current lesson is completed
      case Accounts.get_user_progress(user_id, current_lesson_id) do
        %{status: "completed"} ->
          # Next lesson is automatically available due to progression logic
          {:ok, next_lesson}
        _ ->
          {:error, :prerequisite_not_completed}
      end
    else
      {:error, :lesson_not_found} -> {:ok, nil} # No next lesson exists
      error -> error
    end
  end

  # Private helper functions

  defp get_lesson_by_order(order_index) when is_integer(order_index) do
    case Repo.get_by(Lesson, order_index: order_index) do
      nil -> {:error, :lesson_not_found}
      lesson -> {:ok, lesson}
    end
  end

  defp evaluate_solution(lesson, execution_result) do
    %{result: result, output: output, error: error} = execution_result
    
    cond do
      error != nil ->
        %{
          passed: false,
          execution_result: execution_result,
          expected_output: lesson.expected_output,
          feedback: "Your code has an error: #{error}"
        }
      
      lesson.expected_output != nil ->
        # Compare with expected output (string comparison)
        actual_output = format_result_for_comparison(result, output)
        expected = String.trim(lesson.expected_output)
        
        passed = String.trim(actual_output) == expected
        
        %{
          passed: passed,
          execution_result: execution_result,
          expected_output: lesson.expected_output,
          actual_output: actual_output
        }
      
      lesson.test_cases != nil ->
        # Run test cases if available
        evaluate_test_cases(lesson.test_cases, result, output)
      
      true ->
        # No specific validation - just check that code runs without error
        %{
          passed: true,
          execution_result: execution_result,
          expected_output: nil
        }
    end
  end

  defp format_result_for_comparison(result, output) do
    cond do
      output != "" -> String.trim(output)
      result != nil -> inspect(result)
      true -> ""
    end
  end

  defp evaluate_test_cases(test_cases, result, output) when is_map(test_cases) do
    # Simple test case evaluation - can be extended for more complex scenarios
    expected_result = test_cases["expected_result"]
    expected_output = test_cases["expected_output"]
    
    passed = cond do
      expected_result != nil -> result == expected_result
      expected_output != nil -> String.trim(output) == String.trim(expected_output)
      true -> true
    end
    
    %{
      passed: passed,
      execution_result: %{result: result, output: output, error: nil},
      expected_output: expected_output || inspect(expected_result)
    }
  end

  defp check_next_lesson_unlocked(_user_id, current_order_index) do
    case get_lesson_by_order(current_order_index + 1) do
      {:ok, _next_lesson} -> true
      {:error, :lesson_not_found} -> false
    end
  end

  defp generate_success_feedback(lesson) do
    success_messages = [
      "Excellent work! You've mastered this concept.",
      "Perfect! Your solution is correct.",
      "Great job! You're making excellent progress.",
      "Well done! Your understanding is solid.",
      "Fantastic! You've got it right."
    ]
    
    base_message = Enum.random(success_messages)
    
    if lesson.difficulty == "advanced" do
      base_message <> " This was a challenging lesson!"
    else
      base_message
    end
  end

  defp generate_failure_feedback(lesson, check_result) do
    base_message = "Not quite right. "
    
    specific_feedback = cond do
      check_result.execution_result.error != nil ->
        "Fix the error in your code and try again."
      
      Map.has_key?(check_result, :actual_output) ->
        "Expected: #{check_result.expected_output}\nGot: #{check_result.actual_output}"
      
      true ->
        "Review the lesson instructions and try a different approach."
    end
    
    hint = case lesson.difficulty do
      "beginner" -> " Remember to follow the examples closely."
      "intermediate" -> " Think about the problem step by step."
      "advanced" -> " Consider edge cases and alternative approaches."
      _ -> ""
    end
    
    base_message <> specific_feedback <> hint
  end
end