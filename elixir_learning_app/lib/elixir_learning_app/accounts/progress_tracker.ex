defmodule ElixirLearningApp.Accounts.ProgressTracker do
  @moduledoc """
  High-level progress tracking functionality for user learning progress.
  
  This module provides functions for:
  - Progress updates and retrieval
  - Lesson completion tracking  
  - Progress statistics calculation
  """

  import Ecto.Query, warn: false
  alias ElixirLearningApp.Repo
  alias ElixirLearningApp.Accounts.{User, UserProgress}
  alias ElixirLearningApp.Content.Lesson

  @doc """
  Gets comprehensive user progress including statistics.

  Returns a map with:
  - user: User struct
  - progress_list: List of UserProgress with preloaded lessons
  - statistics: Progress statistics map

  ## Examples

      iex> get_user_progress(user_id)
      %{
        user: %User{},
        progress_list: [%UserProgress{}, ...],
        statistics: %{
          total_lessons: 10,
          completed_lessons: 3,
          in_progress_lessons: 2,
          completion_percentage: 30.0,
          total_attempts: 15,
          average_attempts_per_lesson: 5.0
        }
      }

  """
  def get_user_progress(user_id) do
    user = Repo.get!(User, user_id)
    progress_list = get_progress_list_with_lessons(user_id)
    statistics = calculate_progress_statistics(user_id, progress_list)

    %{
      user: user,
      progress_list: progress_list,
      statistics: statistics
    }
  end

  @doc """
  Gets user progress for display with lesson information.

  Returns list of progress entries with preloaded lesson data,
  ordered by lesson order_index.

  ## Examples

      iex> get_progress_list_with_lessons(user_id)
      [%UserProgress{lesson: %Lesson{}}, ...]

  """
  def get_progress_list_with_lessons(user_id) do
    UserProgress
    |> where([up], up.user_id == ^user_id)
    |> join(:inner, [up], l in assoc(up, :lesson))
    |> order_by([up, l], l.order_index)
    |> preload(:lesson)
    |> Repo.all()
  end

  @doc """
  Marks a lesson as completed and updates progress statistics.

  ## Examples

      iex> mark_lesson_completed(user_id, lesson_id, "final code")
      {:ok, %UserProgress{}}

  """
  def mark_lesson_completed(user_id, lesson_id, last_code \\ nil) do
    case ElixirLearningApp.Accounts.get_user_progress(user_id, lesson_id) do
      nil ->
        %UserProgress{}
        |> UserProgress.changeset(%{user_id: user_id, lesson_id: lesson_id})
        |> UserProgress.complete_changeset(%{last_code: last_code})
        |> Repo.insert()
      
      existing_progress ->
        existing_progress
        |> UserProgress.complete_changeset(%{last_code: last_code})
        |> Repo.update()
    end
  end

  @doc """
  Updates lesson attempt and progress status.

  ## Examples

      iex> update_lesson_attempt(user_id, lesson_id, "attempted code")
      {:ok, %UserProgress{}}

  """
  def update_lesson_attempt(user_id, lesson_id, last_code) do
    case ElixirLearningApp.Accounts.get_user_progress(user_id, lesson_id) do
      nil ->
        %UserProgress{}
        |> UserProgress.changeset(%{user_id: user_id, lesson_id: lesson_id})
        |> UserProgress.attempt_changeset(%{last_code: last_code})
        |> Repo.insert()
      
      existing_progress ->
        existing_progress
        |> UserProgress.attempt_changeset(%{last_code: last_code})
        |> Repo.update()
    end
  end

  @doc """
  Calculates comprehensive progress statistics for a user.

  Returns a map with various progress metrics:
  - total_lessons: Total number of lessons available
  - completed_lessons: Number of completed lessons
  - in_progress_lessons: Number of lessons currently in progress
  - not_started_lessons: Number of lessons not yet started
  - completion_percentage: Percentage of lessons completed
  - total_attempts: Total attempts across all lessons
  - average_attempts_per_lesson: Average attempts per lesson (for lessons with attempts)

  ## Examples

      iex> calculate_progress_statistics(user_id)
      %{
        total_lessons: 10,
        completed_lessons: 3,
        in_progress_lessons: 2,
        not_started_lessons: 5,
        completion_percentage: 30.0,
        total_attempts: 15,
        average_attempts_per_lesson: 5.0
      }

  """
  def calculate_progress_statistics(user_id, progress_list \\ nil) do
    progress_list = progress_list || get_progress_list_with_lessons(user_id)
    total_lessons = get_total_lesson_count()
    
    # Count lessons by status
    status_counts = Enum.reduce(progress_list, %{"completed" => 0, "in_progress" => 0, "not_started" => 0}, fn progress, acc ->
      Map.update(acc, progress.status, 1, &(&1 + 1))
    end)
    
    completed_lessons = status_counts["completed"]
    in_progress_lessons = status_counts["in_progress"]
    not_started_lessons = total_lessons - completed_lessons - in_progress_lessons
    
    # Calculate completion percentage
    completion_percentage = if total_lessons > 0 do
      (completed_lessons / total_lessons) * 100
    else
      0.0
    end
    
    # Calculate attempt statistics
    total_attempts = Enum.reduce(progress_list, 0, fn progress, acc ->
      acc + (progress.attempts || 0)
    end)
    
    lessons_with_attempts = Enum.count(progress_list, fn progress ->
      (progress.attempts || 0) > 0
    end)
    
    average_attempts_per_lesson = if lessons_with_attempts > 0 do
      total_attempts / lessons_with_attempts
    else
      0.0
    end

    %{
      total_lessons: total_lessons,
      completed_lessons: completed_lessons,
      in_progress_lessons: in_progress_lessons,
      not_started_lessons: not_started_lessons,
      completion_percentage: Float.round(completion_percentage, 1),
      total_attempts: total_attempts,
      average_attempts_per_lesson: Float.round(average_attempts_per_lesson, 1)
    }
  end

  @doc """
  Gets the total number of lessons available in the system.

  ## Examples

      iex> get_total_lesson_count()
      10

  """
  def get_total_lesson_count do
    Lesson
    |> select([l], count(l.id))
    |> Repo.one()
  end

  @doc """
  Gets lessons available to a user based on their progress.
  
  A lesson is available if:
  - It's the first lesson (order_index = 1), OR
  - The previous lesson has been completed

  ## Examples

      iex> get_available_lessons(user_id)
      [%Lesson{}, ...]

  """
  def get_available_lessons(user_id) do
    # Get all completed lesson IDs for this user
    completed_lesson_ids = 
      UserProgress
      |> where([up], up.user_id == ^user_id and up.status == "completed")
      |> select([up], up.lesson_id)
      |> Repo.all()

    # Get the highest order_index of completed lessons
    max_completed_order = if Enum.empty?(completed_lesson_ids) do
      0
    else
      Lesson
      |> where([l], l.id in ^completed_lesson_ids)
      |> select([l], max(l.order_index))
      |> Repo.one() || 0
    end

    # Return lessons up to the next available lesson
    Lesson
    |> where([l], l.order_index <= ^(max_completed_order + 1))
    |> order_by([l], l.order_index)
    |> Repo.all()
  end

  @doc """
  Checks if a specific lesson is available to a user.

  ## Examples

      iex> lesson_available?(user_id, lesson_id)
      true

  """
  def lesson_available?(user_id, lesson_id) do
    lesson = Repo.get!(Lesson, lesson_id)
    
    # First lesson is always available
    if lesson.order_index == 1 do
      true
    else
      # Check if previous lesson is completed
      previous_lesson = 
        Lesson
        |> where([l], l.order_index == ^(lesson.order_index - 1))
        |> Repo.one()

      if previous_lesson do
        case ElixirLearningApp.Accounts.get_user_progress(user_id, previous_lesson.id) do
          %UserProgress{status: "completed"} -> true
          _ -> false
        end
      else
        false
      end
    end
  end
end