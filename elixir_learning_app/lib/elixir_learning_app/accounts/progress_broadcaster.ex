defmodule ElixirLearningApp.Accounts.ProgressBroadcaster do
  @moduledoc """
  Handles broadcasting of user progress updates using Phoenix PubSub.
  """

  alias Phoenix.PubSub

  @pubsub ElixirLearningApp.PubSub

  @doc """
  Broadcasts when a user completes a lesson.
  """
  def broadcast_lesson_completed(user_id, lesson_id, lesson_title) do
    PubSub.broadcast(@pubsub, "user_progress:#{user_id}", {
      :lesson_completed,
      %{user_id: user_id, lesson_id: lesson_id, lesson_title: lesson_title}
    })

    # Also broadcast to global progress topic for statistics
    PubSub.broadcast(@pubsub, "global_progress", {
      :lesson_completed,
      %{user_id: user_id, lesson_id: lesson_id, lesson_title: lesson_title}
    })
  end

  @doc """
  Broadcasts when a user starts working on a lesson.
  """
  def broadcast_lesson_started(user_id, lesson_id, lesson_title) do
    PubSub.broadcast(@pubsub, "user_progress:#{user_id}", {
      :lesson_started,
      %{user_id: user_id, lesson_id: lesson_id, lesson_title: lesson_title}
    })

    # Also broadcast to global progress topic for statistics
    PubSub.broadcast(@pubsub, "global_progress", {
      :lesson_started,
      %{user_id: user_id, lesson_id: lesson_id, lesson_title: lesson_title}
    })
  end

  @doc """
  Broadcasts when a lesson is unlocked for a user.
  """
  def broadcast_lesson_unlocked(user_id, lesson_id, lesson_title) do
    PubSub.broadcast(@pubsub, "user_progress:#{user_id}", {
      :lesson_unlocked,
      %{user_id: user_id, lesson_id: lesson_id, lesson_title: lesson_title}
    })
  end

  @doc """
  Broadcasts progress statistics updates.
  """
  def broadcast_progress_stats(stats) do
    PubSub.broadcast(@pubsub, "progress_stats", {
      :stats_updated,
      stats
    })
  end

  @doc """
  Subscribe to user progress updates for a specific user.
  """
  def subscribe_user_progress(user_id) do
    PubSub.subscribe(@pubsub, "user_progress:#{user_id}")
  end

  @doc """
  Subscribe to global progress updates.
  """
  def subscribe_global_progress do
    PubSub.subscribe(@pubsub, "global_progress")
  end

  @doc """
  Subscribe to progress statistics updates.
  """
  def subscribe_progress_stats do
    PubSub.subscribe(@pubsub, "progress_stats")
  end

  @doc """
  Unsubscribe from user progress updates.
  """
  def unsubscribe_user_progress(user_id) do
    PubSub.unsubscribe(@pubsub, "user_progress:#{user_id}")
  end

  @doc """
  Unsubscribe from global progress updates.
  """
  def unsubscribe_global_progress do
    PubSub.unsubscribe(@pubsub, "global_progress")
  end

  @doc """
  Unsubscribe from progress statistics updates.
  """
  def unsubscribe_progress_stats do
    PubSub.unsubscribe(@pubsub, "progress_stats")
  end
end