defmodule ElixirLearningAppWeb.LessonLiveTest do
  use ElixirLearningAppWeb.ConnCase

  import Phoenix.LiveViewTest
  import ElixirLearningApp.AccountsFixtures
  import ElixirLearningApp.ContentFixtures

  @create_attrs %{
    title: "Test Lesson",
    description: "A test lesson",
    instructions: "Write a function that returns 42",
    template_code: "def answer do\n  # Your code here\nend",
    expected_output: "42",
    order_index: 1,
    difficulty: "beginner"
  }

  describe "LessonLive" do
    setup %{conn: conn} do
      user = user_fixture()
      lesson = lesson_fixture(@create_attrs)
      
      %{conn: log_in_user(conn, user), user: user, lesson: lesson}
    end

    test "displays lesson content", %{conn: conn, lesson: lesson} do
      {:ok, _show_live, html} = live(conn, ~p"/lessons/#{lesson.id}")

      assert html =~ lesson.title
      assert html =~ lesson.description
      assert html =~ lesson.instructions
    end

    test "displays code editor with template code", %{conn: conn, lesson: lesson} do
      {:ok, _show_live, html} = live(conn, ~p"/lessons/#{lesson.id}")

      assert html =~ "Code Editor"
      assert html =~ lesson.template_code
    end

    test "handles code execution", %{conn: conn, lesson: lesson} do
      {:ok, show_live, _html} = live(conn, ~p"/lessons/#{lesson.id}")

      # Simulate Monaco Editor sending update_code event
      show_live |> render_hook("update_code", %{"code" => "1 + 1"})

      # Execute code
      show_live |> element("button", "Run Code") |> render_click()

      # Should show execution result
      assert render(show_live) =~ "Execution Result"
    end

    test "handles solution submission", %{conn: conn, lesson: lesson} do
      {:ok, show_live, _html} = live(conn, ~p"/lessons/#{lesson.id}")

      # Simulate Monaco Editor sending update_code event with correct solution
      show_live |> render_hook("update_code", %{"code" => "def answer do\n  42\nend"})

      # Submit solution
      show_live |> element("button", "Submit Solution") |> render_click()

      # Should show submission result
      assert render(show_live) =~ "Correct!" || render(show_live) =~ "Not Quite Right"
    end

    test "handles code reset", %{conn: conn, lesson: lesson} do
      {:ok, show_live, _html} = live(conn, ~p"/lessons/#{lesson.id}")

      # Simulate Monaco Editor sending update_code event with modified code
      show_live |> render_hook("update_code", %{"code" => "some modified code"})

      # Reset code
      show_live |> element("button", "Reset to Template") |> render_click()

      # Should show template code again
      assert render(show_live) =~ lesson.template_code
    end

    test "redirects when lesson not found", %{conn: conn} do
      assert {:error, {:redirect, %{to: "/lessons"}}} = 
        live(conn, ~p"/lessons/999")
    end

    test "shows access denied for inaccessible lesson", %{conn: conn} do
      # Create a lesson with high order index that shouldn't be accessible
      lesson = lesson_fixture(%{@create_attrs | order_index: 10})
      
      assert {:error, {:redirect, %{to: "/lessons"}}} = 
        live(conn, ~p"/lessons/#{lesson.id}")
    end
  end

  describe "LessonLive without authentication" do
    test "redirects to login when not authenticated", %{conn: conn} do
      lesson = lesson_fixture(@create_attrs)
      
      assert {:error, {:redirect, %{to: "/users/log_in"}}} = 
        live(conn, ~p"/lessons/#{lesson.id}")
    end
  end
end