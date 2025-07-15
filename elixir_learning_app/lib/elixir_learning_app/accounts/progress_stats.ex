defmodule ElixirLearningApp.Accounts.ProgressStats do
  @moduledoc """
  Handles calculation and caching of progress statistics for the learning application.
  """

  import Ecto.Query, warn: false
  
  alias ElixirLearningApp.Repo
  alias ElixirLearningApp.Content.Lesson
  alias ElixirLearningApp.Accounts.UserProgress
  alias ElixirLearningApp.Accounts.ProgressBroadcaster

  @doc """
  Gets comprehensive progress statistics for the application.
  
  Returns statistics including:
  - Total lessons available
  - Total users with progress
  - Completion rates per lesson
  - Overall completion statistics
  """
  def get_global_stats do
    total_lessons = get_total_lessons()
    total_users = get_total_users_with_progress()
    lesson_completion_stats = get_lesson_completion_stats()
    overall_completion_rate = calculate_overall_completion_rate()
    
    %{
      total_lessons: total_lessons,
      total_users: total_users,
      lesson_completion_stats: lesson_completion_stats,
      overall_completion_rate: overall_completion_rate,
      updated_at: DateTime.utc_now()
    }
  end

  @doc """
  Gets progress statistics for a specific user.
  """
  def get_user_stats(user_id) when is_integer(user_id) do
    user_progress = get_user_progress_summary(user_id)
    total_lessons = get_total_lessons()
    
    completed_count = Enum.count(user_progress, fn up -> up.status == "completed" end)
    in_progress_count = Enum.count(user_progress, fn up -> up.status == "in_progress" end)
    completion_percentage = if total_lessons > 0, do: (completed_count / total_lessons * 100) |> Float.round(1), else: 0.0
    
    %{
      user_id: user_id,
      total_lessons: total_lessons,
      completed_lessons: completed_count,
      in_progress_lessons: in_progress_count,
      completion_percentage: completion_percentage,
      total_attempts: Enum.sum(Enum.map(user_progress, fn up -> up.attempts || 0 end)),
      updated_at: DateTime.utc_now()
    }
  end

  @doc """
  Gets completion statistics for a specific lesson.
  """
  def get_lesson_stats(lesson_id) when is_integer(lesson_id) do
    total_users = get_total_users_with_progress()
    
    lesson_progress = 
      UserProgress
      |> where([up], up.lesson_id == ^lesson_id)
      |> Repo.all()
    
    completed_count = Enum.count(lesson_progress, fn up -> up.status == "completed" end)
    in_progress_count = Enum.count(lesson_progress, fn up -> up.status == "in_progress" end)
    total_attempts = Enum.sum(Enum.map(lesson_progress, fn up -> up.attempts || 0 end))
    
    completion_rate = if total_users > 0, do: (completed_count / total_users * 100) |> Float.round(1), else: 0.0
    
    %{
      lesson_id: lesson_id,
      total_users: total_users,
      completed_count: completed_count,
      in_progress_count: in_progress_count,
      completion_rate: completion_rate,
      total_attempts: total_attempts,
      average_attempts: (if completed_count > 0, do: (total_attempts / completed_count) |> Float.round(1), else: 0.0),
      updated_at: DateTime.utc_now()
    }
  end

  @doc """
  Updates and broadcasts global statistics.
  This should be called when significant progress events occur.
  """
  def update_and_broadcast_stats do
    stats = get_global_stats()
    ProgressBroadcaster.broadcast_progress_stats(stats)
    stats
  end

  @doc """
  Updates and broadcasts statistics for a specific lesson.
  """
  def update_and_broadcast_lesson_stats(lesson_id) when is_integer(lesson_id) do
    lesson_stats = get_lesson_stats(lesson_id)
    ProgressBroadcaster.broadcast_progress_stats(%{lesson_stats: lesson_stats})
    lesson_stats
  end

  # Private helper functions

  defp get_total_lessons do
    Lesson
    |> select([l], count(l.id))
    |> Repo.one()
  end

  defp get_total_users_with_progress do
    UserProgress
    |> select([up], count(fragment("DISTINCT ?", up.user_id)))
    |> Repo.one()
  end

  defp get_lesson_completion_stats do
    query = from up in UserProgress,
      join: l in Lesson, on: l.id == up.lesson_id,
      group_by: [l.id, l.title, l.order_index],
      select: %{
        lesson_id: l.id,
        lesson_title: l.title,
        order_index: l.order_index,
        completed_count: count(fragment("CASE WHEN ? = 'completed' THEN 1 END", up.status)),
        in_progress_count: count(fragment("CASE WHEN ? = 'in_progress' THEN 1 END", up.status)),
        total_attempts: sum(up.attempts)
      },
      order_by: l.order_index

    Repo.all(query)
  end

  defp calculate_overall_completion_rate do
    total_possible_completions = get_total_lessons() * get_total_users_with_progress()
    
    if total_possible_completions > 0 do
      actual_completions = 
        UserProgress
        |> where([up], up.status == "completed")
        |> select([up], count(up.id))
        |> Repo.one()
      
      (actual_completions / total_possible_completions * 100) |> Float.round(1)
    else
      0.0
    end
  end

  defp get_user_progress_summary(user_id) do
    UserProgress
    |> where([up], up.user_id == ^user_id)
    |> Repo.all()
  end
end