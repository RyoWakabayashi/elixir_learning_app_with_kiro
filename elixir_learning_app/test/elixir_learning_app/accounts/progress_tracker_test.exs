defmodule ElixirLearningApp.Accounts.ProgressTrackerTest do
  use ElixirLearningApp.DataCase

  alias ElixirLearningApp.Accounts.{User, UserProgress, ProgressTracker}
  alias ElixirLearningApp.Content.Lesson
  alias ElixirLearningApp.Repo

  describe "get_user_progress/1" do
    setup do
      user = Repo.insert!(%User{email: "test@example.com", name: "Test User"})
      
      lesson1 = Repo.insert!(%Lesson{title: "Lesson 1", instructions: "Learn basics", order_index: 1})
      lesson2 = Repo.insert!(%Lesson{title: "Lesson 2", instructions: "Learn more", order_index: 2})
      lesson3 = Repo.insert!(%Lesson{title: "Lesson 3", instructions: "Advanced", order_index: 3})
      
      {:ok, user: user, lessons: [lesson1, lesson2, lesson3]}
    end

    test "returns comprehensive progress data", %{user: user, lessons: [lesson1, lesson2, _lesson3]} do
      # Create some progress
      Repo.insert!(%UserProgress{user_id: user.id, lesson_id: lesson1.id, status: "completed", attempts: 2})
      Repo.insert!(%UserProgress{user_id: user.id, lesson_id: lesson2.id, status: "in_progress", attempts: 1})

      result = ProgressTracker.get_user_progress(user.id)

      assert result.user.id == user.id
      assert length(result.progress_list) == 2
      assert result.statistics.total_lessons == 3
      assert result.statistics.completed_lessons == 1
      assert result.statistics.in_progress_lessons == 1
    end

    test "handles user with no progress", %{user: user} do
      result = ProgressTracker.get_user_progress(user.id)

      assert result.user.id == user.id
      assert result.progress_list == []
      assert result.statistics.total_lessons == 3
      assert result.statistics.completed_lessons == 0
      assert result.statistics.completion_percentage == 0.0
    end
  end

  describe "get_progress_list_with_lessons/1" do
    setup do
      user = Repo.insert!(%User{email: "test@example.com", name: "Test User"})
      
      lesson1 = Repo.insert!(%Lesson{title: "Lesson 1", instructions: "Learn basics", order_index: 1})
      lesson2 = Repo.insert!(%Lesson{title: "Lesson 2", instructions: "Learn more", order_index: 2})
      
      {:ok, user: user, lessons: [lesson1, lesson2]}
    end

    test "returns progress with preloaded lessons ordered by lesson order", %{user: user, lessons: [lesson1, lesson2]} do
      # Insert progress in reverse order to test ordering
      Repo.insert!(%UserProgress{user_id: user.id, lesson_id: lesson2.id, status: "in_progress"})
      Repo.insert!(%UserProgress{user_id: user.id, lesson_id: lesson1.id, status: "completed"})

      result = ProgressTracker.get_progress_list_with_lessons(user.id)

      assert length(result) == 2
      assert hd(result).lesson.id == lesson1.id  # Should be first due to order_index
      assert hd(result).lesson.title == "Lesson 1"
      assert List.last(result).lesson.id == lesson2.id
    end

    test "returns empty list for user with no progress", %{user: user} do
      result = ProgressTracker.get_progress_list_with_lessons(user.id)
      assert result == []
    end
  end

  describe "mark_lesson_completed/3" do
    setup do
      user = Repo.insert!(%User{email: "test@example.com", name: "Test User"})
      lesson = Repo.insert!(%Lesson{title: "Test Lesson", instructions: "Learn", order_index: 1})
      
      {:ok, user: user, lesson: lesson}
    end

    test "creates new progress record when none exists", %{user: user, lesson: lesson} do
      {:ok, progress} = ProgressTracker.mark_lesson_completed(user.id, lesson.id, "final code")

      assert progress.user_id == user.id
      assert progress.lesson_id == lesson.id
      assert progress.status == "completed"
      assert progress.last_code == "final code"
      assert progress.completed_at
    end

    test "updates existing progress record", %{user: user, lesson: lesson} do
      existing = Repo.insert!(%UserProgress{
        user_id: user.id, 
        lesson_id: lesson.id, 
        status: "in_progress", 
        attempts: 3
      })

      {:ok, progress} = ProgressTracker.mark_lesson_completed(user.id, lesson.id, "final code")

      assert progress.id == existing.id
      assert progress.status == "completed"
      assert progress.last_code == "final code"
      assert progress.attempts == 3  # Should preserve existing attempts
      assert progress.completed_at
    end
  end

  describe "update_lesson_attempt/3" do
    setup do
      user = Repo.insert!(%User{email: "test@example.com", name: "Test User"})
      lesson = Repo.insert!(%Lesson{title: "Test Lesson", instructions: "Learn", order_index: 1})
      
      {:ok, user: user, lesson: lesson}
    end

    test "creates new progress record when none exists", %{user: user, lesson: lesson} do
      {:ok, progress} = ProgressTracker.update_lesson_attempt(user.id, lesson.id, "attempt code")

      assert progress.user_id == user.id
      assert progress.lesson_id == lesson.id
      assert progress.status == "in_progress"
      assert progress.last_code == "attempt code"
      assert progress.attempts == 1
    end

    test "updates existing progress record and increments attempts", %{user: user, lesson: lesson} do
      existing = Repo.insert!(%UserProgress{
        user_id: user.id, 
        lesson_id: lesson.id, 
        status: "not_started", 
        attempts: 2
      })

      {:ok, progress} = ProgressTracker.update_lesson_attempt(user.id, lesson.id, "new attempt")

      assert progress.id == existing.id
      assert progress.status == "in_progress"
      assert progress.last_code == "new attempt"
      assert progress.attempts == 3
    end
  end

  describe "calculate_progress_statistics/2" do
    setup do
      user = Repo.insert!(%User{email: "test@example.com", name: "Test User"})
      
      lesson1 = Repo.insert!(%Lesson{title: "Lesson 1", instructions: "Learn basics", order_index: 1})
      lesson2 = Repo.insert!(%Lesson{title: "Lesson 2", instructions: "Learn more", order_index: 2})
      lesson3 = Repo.insert!(%Lesson{title: "Lesson 3", instructions: "Advanced", order_index: 3})
      lesson4 = Repo.insert!(%Lesson{title: "Lesson 4", instructions: "Expert", order_index: 4})
      
      {:ok, user: user, lessons: [lesson1, lesson2, lesson3, lesson4]}
    end

    test "calculates statistics correctly with mixed progress", %{user: user, lessons: [lesson1, lesson2, lesson3, _lesson4]} do
      # Create progress records
      Repo.insert!(%UserProgress{user_id: user.id, lesson_id: lesson1.id, status: "completed", attempts: 3})
      Repo.insert!(%UserProgress{user_id: user.id, lesson_id: lesson2.id, status: "completed", attempts: 2})
      Repo.insert!(%UserProgress{user_id: user.id, lesson_id: lesson3.id, status: "in_progress", attempts: 1})

      stats = ProgressTracker.calculate_progress_statistics(user.id)

      assert stats.total_lessons == 4
      assert stats.completed_lessons == 2
      assert stats.in_progress_lessons == 1
      assert stats.not_started_lessons == 1
      assert stats.completion_percentage == 50.0
      assert stats.total_attempts == 6
      assert stats.average_attempts_per_lesson == 2.0
    end

    test "handles user with no progress", %{user: user} do
      stats = ProgressTracker.calculate_progress_statistics(user.id)

      assert stats.total_lessons == 4
      assert stats.completed_lessons == 0
      assert stats.in_progress_lessons == 0
      assert stats.not_started_lessons == 4
      assert stats.completion_percentage == 0.0
      assert stats.total_attempts == 0
      assert stats.average_attempts_per_lesson == 0.0
    end

    test "handles lessons with zero attempts", %{user: user, lessons: [lesson1, _lesson2, _lesson3, _lesson4]} do
      # Create progress with zero attempts
      Repo.insert!(%UserProgress{user_id: user.id, lesson_id: lesson1.id, status: "completed", attempts: 0})

      stats = ProgressTracker.calculate_progress_statistics(user.id)

      assert stats.total_attempts == 0
      assert stats.average_attempts_per_lesson == 0.0
    end

    test "calculates average attempts correctly excluding zero attempts", %{user: user, lessons: [lesson1, lesson2, _lesson3, _lesson4]} do
      # One lesson with attempts, one without
      Repo.insert!(%UserProgress{user_id: user.id, lesson_id: lesson1.id, status: "completed", attempts: 4})
      Repo.insert!(%UserProgress{user_id: user.id, lesson_id: lesson2.id, status: "completed", attempts: 0})

      stats = ProgressTracker.calculate_progress_statistics(user.id)

      assert stats.total_attempts == 4
      assert stats.average_attempts_per_lesson == 4.0  # Only counts lessons with attempts > 0
    end
  end

  describe "get_total_lesson_count/0" do
    test "returns correct count of lessons" do
      # Clear any existing lessons
      Repo.delete_all(Lesson)
      
      Repo.insert!(%Lesson{title: "Lesson 1", instructions: "Learn", order_index: 1})
      Repo.insert!(%Lesson{title: "Lesson 2", instructions: "Learn more", order_index: 2})

      assert ProgressTracker.get_total_lesson_count() == 2
    end

    test "returns zero when no lessons exist" do
      Repo.delete_all(Lesson)
      assert ProgressTracker.get_total_lesson_count() == 0
    end
  end

  describe "get_available_lessons/1" do
    setup do
      user = Repo.insert!(%User{email: "test@example.com", name: "Test User"})
      
      lesson1 = Repo.insert!(%Lesson{title: "Lesson 1", instructions: "Basics", order_index: 1})
      lesson2 = Repo.insert!(%Lesson{title: "Lesson 2", instructions: "Intermediate", order_index: 2})
      lesson3 = Repo.insert!(%Lesson{title: "Lesson 3", instructions: "Advanced", order_index: 3})
      
      {:ok, user: user, lessons: [lesson1, lesson2, lesson3]}
    end

    test "returns only first lesson when no progress", %{user: user, lessons: [lesson1, _lesson2, _lesson3]} do
      available = ProgressTracker.get_available_lessons(user.id)
      
      assert length(available) == 1
      assert hd(available).id == lesson1.id
    end

    test "returns lessons up to next available when some completed", %{user: user, lessons: [lesson1, lesson2, _lesson3]} do
      # Complete first lesson
      Repo.insert!(%UserProgress{user_id: user.id, lesson_id: lesson1.id, status: "completed"})

      available = ProgressTracker.get_available_lessons(user.id)
      
      assert length(available) == 2
      assert Enum.map(available, & &1.id) == [lesson1.id, lesson2.id]
    end

    test "returns all lessons when all but last are completed", %{user: user, lessons: [lesson1, lesson2, lesson3]} do
      # Complete first two lessons
      Repo.insert!(%UserProgress{user_id: user.id, lesson_id: lesson1.id, status: "completed"})
      Repo.insert!(%UserProgress{user_id: user.id, lesson_id: lesson2.id, status: "completed"})

      available = ProgressTracker.get_available_lessons(user.id)
      
      assert length(available) == 3
      assert Enum.map(available, & &1.id) == [lesson1.id, lesson2.id, lesson3.id]
    end

    test "in_progress lessons don't unlock next lesson", %{user: user, lessons: [lesson1, _lesson2, _lesson3]} do
      # Mark first lesson as in progress (not completed)
      Repo.insert!(%UserProgress{user_id: user.id, lesson_id: lesson1.id, status: "in_progress"})

      available = ProgressTracker.get_available_lessons(user.id)
      
      assert length(available) == 1
      assert hd(available).id == lesson1.id
    end
  end

  describe "lesson_available?/2" do
    setup do
      user = Repo.insert!(%User{email: "test@example.com", name: "Test User"})
      
      lesson1 = Repo.insert!(%Lesson{title: "Lesson 1", instructions: "Basics", order_index: 1})
      lesson2 = Repo.insert!(%Lesson{title: "Lesson 2", instructions: "Intermediate", order_index: 2})
      lesson3 = Repo.insert!(%Lesson{title: "Lesson 3", instructions: "Advanced", order_index: 3})
      
      {:ok, user: user, lessons: [lesson1, lesson2, lesson3]}
    end

    test "first lesson is always available", %{user: user, lessons: [lesson1, _lesson2, _lesson3]} do
      assert ProgressTracker.lesson_available?(user.id, lesson1.id) == true
    end

    test "second lesson not available when first not completed", %{user: user, lessons: [_lesson1, lesson2, _lesson3]} do
      assert ProgressTracker.lesson_available?(user.id, lesson2.id) == false
    end

    test "second lesson available when first completed", %{user: user, lessons: [lesson1, lesson2, _lesson3]} do
      Repo.insert!(%UserProgress{user_id: user.id, lesson_id: lesson1.id, status: "completed"})
      
      assert ProgressTracker.lesson_available?(user.id, lesson2.id) == true
    end

    test "lesson not available when previous is only in progress", %{user: user, lessons: [lesson1, lesson2, _lesson3]} do
      Repo.insert!(%UserProgress{user_id: user.id, lesson_id: lesson1.id, status: "in_progress"})
      
      assert ProgressTracker.lesson_available?(user.id, lesson2.id) == false
    end

    test "third lesson available when second completed", %{user: user, lessons: [lesson1, lesson2, lesson3]} do
      Repo.insert!(%UserProgress{user_id: user.id, lesson_id: lesson1.id, status: "completed"})
      Repo.insert!(%UserProgress{user_id: user.id, lesson_id: lesson2.id, status: "completed"})
      
      assert ProgressTracker.lesson_available?(user.id, lesson3.id) == true
    end
  end
end