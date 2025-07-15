defmodule ElixirLearningAppWeb.LessonLive do
  use ElixirLearningAppWeb, :live_view

  alias ElixirLearningApp.Content.LessonManager
  alias ElixirLearningApp.Execution.CodeExecutor
  alias ElixirLearningApp.Accounts.ProgressBroadcaster

  @impl true
  def mount(%{"id" => lesson_id}, _session, socket) do
    lesson_id = String.to_integer(lesson_id)
    user = socket.assigns.current_user

    case LessonManager.get_lesson(lesson_id) do
      {:ok, lesson} ->
        if user && LessonManager.can_access_lesson?(user.id, lesson_id) do
          # Get user's previous code if any
          user_progress = ElixirLearningApp.Accounts.get_user_progress(user.id, lesson_id)
          initial_code = get_initial_code(lesson, user_progress)

          # Get navigation info
          available_lessons = LessonManager.get_available_lessons(user.id)
          {prev_lesson, next_lesson} = get_navigation_lessons(lesson, available_lessons)

          # Subscribe to progress updates for this user
          ProgressBroadcaster.subscribe_user_progress(user.id)
          # Subscribe to global progress statistics
          ProgressBroadcaster.subscribe_progress_stats()
          
          # Get initial progress statistics
          user_stats = ElixirLearningApp.Accounts.ProgressStats.get_user_stats(user.id)
          lesson_stats = ElixirLearningApp.Accounts.ProgressStats.get_lesson_stats(lesson_id)
          
          socket =
            socket
            |> assign(:lesson, lesson)
            |> assign(:user_code, initial_code)
            |> assign(:execution_result, nil)
            |> assign(:execution_loading, false)
            |> assign(:execution_status, nil)
            |> assign(:submission_result, nil)
            |> assign(:submission_loading, false)
            |> assign(:submission_status, nil)
            |> assign(:user_progress, user_progress)
            |> assign(:available_lessons, available_lessons)
            |> assign(:prev_lesson, prev_lesson)
            |> assign(:next_lesson, next_lesson)
            |> assign(:user_stats, user_stats)
            |> assign(:lesson_stats, lesson_stats)
            |> assign(:page_title, lesson.title)

          {:ok, socket}
        else
          {:ok, 
           socket
           |> put_flash(:error, "You don't have access to this lesson yet.")
           |> redirect(to: ~p"/lessons")}
        end

      {:error, :lesson_not_found} ->
        {:ok,
         socket
         |> put_flash(:error, "Lesson not found.")
         |> redirect(to: ~p"/lessons")}
    end
  end

  def mount(_params, _session, socket) do
    # Redirect to lessons index if no lesson ID provided
    {:ok, redirect(socket, to: ~p"/lessons")}
  end

  @impl true
  def handle_event("update_code", %{"code" => code}, socket) do
    {:noreply, assign(socket, :user_code, code)}
  end

  @impl true
  def handle_event("execute_code", _params, socket) do
    socket = 
      socket
      |> assign(:execution_loading, true)
      |> assign(:execution_status, "Preparing to execute code...")
      |> assign(:execution_result, nil)
    
    # Execute code asynchronously to avoid blocking the LiveView process
    send(self(), {:execute_code, socket.assigns.user_code})
    
    {:noreply, socket}
  end

  @impl true
  def handle_event("submit_solution", _params, socket) do
    user = socket.assigns.current_user
    lesson = socket.assigns.lesson
    code = socket.assigns.user_code

    socket = 
      socket
      |> assign(:submission_loading, true)
      |> assign(:submission_status, "Validating your solution...")
      |> assign(:submission_result, nil)
    
    # Submit solution asynchronously
    send(self(), {:submit_solution, user.id, lesson.id, code})
    
    {:noreply, socket}
  end

  @impl true
  def handle_event("reset_code", _params, socket) do
    lesson = socket.assigns.lesson
    initial_code = lesson.template_code || ""
    
    socket =
      socket
      |> assign(:user_code, initial_code)
      |> assign(:execution_result, nil)
      |> assign(:submission_result, nil)
      |> put_flash(:info, "Code reset to template.")

    {:noreply, socket}
  end

  @impl true
  def handle_event("next_lesson", _params, socket) do
    user = socket.assigns.current_user

    case LessonManager.get_next_lesson(user.id) do
      {:ok, nil} ->
        {:noreply, put_flash(socket, :info, "Congratulations! You've completed all available lessons.")}
      
      {:ok, next_lesson} ->
        {:noreply, redirect(socket, to: ~p"/lessons/#{next_lesson.id}")}
    end
  end

  @impl true
  def handle_info({:execute_code, code}, socket) do
    # Update status to show we're executing
    socket = assign(socket, :execution_status, "Executing code...")
    
    case CodeExecutor.execute_and_format(code) do
      {:ok, result} ->
        socket =
          socket
          |> assign(:execution_result, result)
          |> assign(:execution_loading, false)
          |> assign(:execution_status, "Execution completed successfully!")

        # Clear status after a short delay
        Process.send_after(self(), :clear_execution_status, 2000)
        
        {:noreply, socket}

      {:error, :dangerous_code} ->
        socket =
          socket
          |> assign(:execution_result, %{
            error: "Dangerous code detected. Please avoid file system, network, or system operations.",
            result: nil,
            output: "",
            formatted_output: "Code execution blocked for security reasons."
          })
          |> assign(:execution_loading, false)
          |> assign(:execution_status, "Execution blocked for security reasons")

        Process.send_after(self(), :clear_execution_status, 3000)
        
        {:noreply, socket}

      {:error, :timeout} ->
        socket =
          socket
          |> assign(:execution_result, %{
            error: "Code execution timed out. Please check for infinite loops or long-running operations.",
            result: nil,
            output: "",
            formatted_output: "Execution timed out after 5 seconds."
          })
          |> assign(:execution_loading, false)
          |> assign(:execution_status, "Execution timed out")

        Process.send_after(self(), :clear_execution_status, 3000)
        
        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> assign(:execution_result, %{
            error: "Execution failed: #{inspect(reason)}",
            result: nil,
            output: "",
            formatted_output: "An error occurred during execution."
          })
          |> assign(:execution_loading, false)
          |> assign(:execution_status, "Execution failed")

        Process.send_after(self(), :clear_execution_status, 3000)
        
        {:noreply, socket}
    end
  end

  @impl true
  def handle_info(:clear_execution_status, socket) do
    {:noreply, assign(socket, :execution_status, nil)}
  end

  @impl true
  def handle_info(:clear_submission_status, socket) do
    {:noreply, assign(socket, :submission_status, nil)}
  end

  # Handle progress broadcast messages
  @impl true
  def handle_info({:lesson_completed, %{lesson_id: _lesson_id, lesson_title: lesson_title}}, socket) do
    user = socket.assigns.current_user
    
    # Update available lessons to reflect new progress
    updated_available_lessons = LessonManager.get_available_lessons(user.id)
    
    # Update navigation lessons
    {prev_lesson, next_lesson} = get_navigation_lessons(socket.assigns.lesson, updated_available_lessons)
    
    socket =
      socket
      |> assign(:available_lessons, updated_available_lessons)
      |> assign(:prev_lesson, prev_lesson)
      |> assign(:next_lesson, next_lesson)
      |> put_flash(:info, "🎉 Lesson \"#{lesson_title}\" completed!")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:lesson_unlocked, %{lesson_id: _lesson_id, lesson_title: lesson_title}}, socket) do
    user = socket.assigns.current_user
    
    # Update available lessons to reflect newly unlocked lesson
    updated_available_lessons = LessonManager.get_available_lessons(user.id)
    
    # Update navigation lessons
    {prev_lesson, next_lesson} = get_navigation_lessons(socket.assigns.lesson, updated_available_lessons)
    
    socket =
      socket
      |> assign(:available_lessons, updated_available_lessons)
      |> assign(:prev_lesson, prev_lesson)
      |> assign(:next_lesson, next_lesson)
      |> put_flash(:info, "🔓 New lesson unlocked: \"#{lesson_title}\"!")

    {:noreply, socket}
  end

  @impl true
  def handle_info({:lesson_started, %{lesson_id: lesson_id, lesson_title: lesson_title}}, socket) do
    # For now, we don't need to do anything special when a lesson is started
    # This could be used for analytics or other features in the future
    {:noreply, socket}
  end

  # Handle statistics broadcast messages
  @impl true
  def handle_info({:stats_updated, stats}, socket) do
    user = socket.assigns.current_user
    
    # Update user stats if they're included in the broadcast
    updated_socket = if Map.has_key?(stats, :lesson_stats) do
      # Update lesson-specific stats
      lesson_stats = stats.lesson_stats
      if lesson_stats.lesson_id == socket.assigns.lesson.id do
        assign(socket, :lesson_stats, lesson_stats)
      else
        socket
      end
    else
      # Update user stats from global stats
      user_stats = ElixirLearningApp.Accounts.ProgressStats.get_user_stats(user.id)
      assign(socket, :user_stats, user_stats)
    end

    {:noreply, updated_socket}
  end

  @impl true
  def handle_info({:submit_solution, user_id, lesson_id, code}, socket) do
    # Update status to show we're validating
    socket = assign(socket, :submission_status, "Checking your solution...")
    
    case LessonManager.submit_solution(user_id, lesson_id, code) do
      {:ok, result} ->
        # Update user progress in socket
        updated_progress = ElixirLearningApp.Accounts.get_user_progress(user_id, lesson_id)
        
        status_message = if result.passed do
          if result.lesson_completed do
            "Solution correct! Lesson completed!"
          else
            "Solution validated successfully!"
          end
        else
          "Solution needs improvement"
        end
        
        socket =
          socket
          |> assign(:submission_result, result)
          |> assign(:submission_loading, false)
          |> assign(:submission_status, status_message)
          |> assign(:user_progress, updated_progress)

        # Show success message if lesson completed
        socket = if result.lesson_completed do
          put_flash(socket, :info, "Lesson completed! Great work!")
        else
          socket
        end

        # Clear status after a delay
        Process.send_after(self(), :clear_submission_status, 3000)

        {:noreply, socket}

      {:error, :lesson_not_accessible} ->
        socket =
          socket
          |> assign(:submission_loading, false)
          |> assign(:submission_status, "Access denied to this lesson")
          |> put_flash(:error, "You don't have access to this lesson.")

        Process.send_after(self(), :clear_submission_status, 3000)
        
        {:noreply, socket}

      {:error, reason} ->
        socket =
          socket
          |> assign(:submission_loading, false)
          |> assign(:submission_status, "Submission failed")
          |> put_flash(:error, "Failed to submit solution: #{inspect(reason)}")

        Process.send_after(self(), :clear_submission_status, 3000)
        
        {:noreply, socket}
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8 py-8">
      <!-- Lesson Navigation and Progress -->
      <div class="mb-8">
        <!-- Lesson Progress Indicator -->
        <div class="bg-white shadow rounded-lg p-4 mb-4">
          <div class="flex items-center justify-between">
            <div class="flex items-center space-x-4">
              <h2 class="text-sm font-medium text-gray-900">Lesson Progress</h2>
              <div class="flex items-center space-x-2">
                <%= for {lesson_info, index} <- Enum.with_index(@available_lessons) do %>
                  <div class={[
                    "w-8 h-8 rounded-full flex items-center justify-center text-xs font-medium",
                    lesson_progress_class(lesson_info, @lesson.id)
                  ]}>
                    <%= index + 1 %>
                  </div>
                  <%= if index < length(@available_lessons) - 1 do %>
                    <div class="w-4 h-0.5 bg-gray-300"></div>
                  <% end %>
                <% end %>
              </div>
            </div>
            <div class="text-sm text-gray-600">
              Lesson <%= @lesson.order_index %> of <%= length(@available_lessons) %>
            </div>
          </div>
        </div>

        <!-- Navigation Controls -->
        <div class="flex justify-between items-center">
          <div>
            <%= if @prev_lesson do %>
              <.link
                navigate={~p"/lessons/#{@prev_lesson.id}"}
                class="inline-flex items-center px-4 py-2 border border-gray-300 rounded-md shadow-sm text-sm font-medium text-gray-700 bg-white hover:bg-gray-50 transition-colors"
              >
                ← Previous: <%= @prev_lesson.title %>
              </.link>
            <% else %>
              <div class="text-sm text-gray-400">← No previous lesson</div>
            <% end %>
          </div>
          
          <div>
            <%= if @next_lesson do %>
              <.link
                navigate={~p"/lessons/#{@next_lesson.id}"}
                class="inline-flex items-center px-4 py-2 border border-transparent rounded-md shadow-sm text-sm font-medium text-white bg-blue-600 hover:bg-blue-700 transition-colors"
              >
                Next: <%= @next_lesson.title %> →
              </.link>
            <% else %>
              <div class="text-sm text-gray-400">No next lesson →</div>
            <% end %>
          </div>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-8">
        <!-- Lesson Content Panel -->
        <div class="space-y-6">
          <!-- Lesson Header -->
          <div class="bg-white shadow rounded-lg p-6">
            <div class="flex items-center justify-between mb-4">
              <h1 class="text-2xl font-bold text-gray-900"><%= @lesson.title %></h1>
              <div class="flex items-center space-x-2">
                <%= if @lesson.difficulty do %>
                  <span class={[
                    "px-2 py-1 text-xs font-medium rounded-full",
                    difficulty_badge_class(@lesson.difficulty)
                  ]}>
                    <%= String.capitalize(@lesson.difficulty) %>
                  </span>
                <% end %>
                <%= if @user_progress && @user_progress.status == "completed" do %>
                  <span class="px-2 py-1 text-xs font-medium bg-green-100 text-green-800 rounded-full">
                    ✓ Completed
                  </span>
                <% end %>
              </div>
            </div>
            
            <%= if @lesson.description do %>
              <p class="text-gray-600 mb-4"><%= @lesson.description %></p>
            <% end %>
          </div>

          <!-- Lesson Instructions -->
          <div class="bg-white shadow rounded-lg p-6">
            <h2 class="text-lg font-semibold text-gray-900 mb-4">Instructions</h2>
            <div class="prose prose-sm max-w-none">
              <%= raw(format_instructions(@lesson.instructions)) %>
            </div>
          </div>

          <!-- Expected Output -->
          <%= if @lesson.expected_output do %>
            <div class="bg-blue-50 border border-blue-200 rounded-lg p-4">
              <h3 class="text-sm font-medium text-blue-900 mb-2">Expected Output:</h3>
              <pre class="text-sm text-blue-800 bg-blue-100 p-2 rounded"><%= @lesson.expected_output %></pre>
            </div>
          <% end %>

          <!-- Execution Result -->
          <%= if @execution_result do %>
            <div class="bg-white shadow rounded-lg p-6">
              <h3 class="text-lg font-semibold text-gray-900 mb-4">Execution Result</h3>
              
              <%= if @execution_result.error do %>
                <div class="bg-red-50 border border-red-200 rounded-lg p-4 mb-4">
                  <h4 class="text-sm font-medium text-red-900 mb-2">Error:</h4>
                  <pre class="text-sm text-red-800 whitespace-pre-wrap"><%= @execution_result.error %></pre>
                </div>
              <% else %>
                <%= if @execution_result.output && @execution_result.output != "" do %>
                  <div class="bg-gray-50 border border-gray-200 rounded-lg p-4 mb-4">
                    <h4 class="text-sm font-medium text-gray-900 mb-2">Output:</h4>
                    <pre class="text-sm text-gray-800 whitespace-pre-wrap"><%= @execution_result.output %></pre>
                  </div>
                <% end %>
                
                <%= if @execution_result.result do %>
                  <div class="bg-green-50 border border-green-200 rounded-lg p-4">
                    <h4 class="text-sm font-medium text-green-900 mb-2">Result:</h4>
                    <pre class="text-sm text-green-800"><%= inspect(@execution_result.result) %></pre>
                  </div>
                <% end %>
              <% end %>
            </div>
          <% end %>

          <!-- Submission Result -->
          <%= if @submission_result do %>
            <div class={[
              "border rounded-lg p-6",
              if(@submission_result.passed, do: "bg-green-50 border-green-200", else: "bg-red-50 border-red-200")
            ]}>
              <h3 class={[
                "text-lg font-semibold mb-4",
                if(@submission_result.passed, do: "text-green-900", else: "text-red-900")
              ]}>
                <%= if @submission_result.passed, do: "✓ Correct!", else: "✗ Not Quite Right" %>
              </h3>
              
              <div class={[
                "text-sm mb-4",
                if(@submission_result.passed, do: "text-green-800", else: "text-red-800")
              ]}>
                <%= @submission_result.feedback %>
              </div>

              <%= if not @submission_result.passed and Map.has_key?(@submission_result, :actual_output) do %>
                <div class="space-y-2">
                  <div class="bg-white border rounded p-3">
                    <h4 class="text-xs font-medium text-gray-600 mb-1">Expected:</h4>
                    <pre class="text-sm text-gray-800"><%= @submission_result.expected_output %></pre>
                  </div>
                  <div class="bg-white border rounded p-3">
                    <h4 class="text-xs font-medium text-gray-600 mb-1">Your Output:</h4>
                    <pre class="text-sm text-gray-800"><%= @submission_result.actual_output %></pre>
                  </div>
                </div>
              <% end %>

              <%= if @submission_result.lesson_completed and @submission_result.next_lesson_unlocked do %>
                <div class="mt-4">
                  <button
                    phx-click="next_lesson"
                    class="bg-green-600 hover:bg-green-700 text-white font-medium py-2 px-4 rounded-md transition-colors"
                  >
                    Next Lesson →
                  </button>
                </div>
              <% end %>
            </div>
          <% end %>
        </div>

        <!-- Code Editor Panel -->
        <div class="space-y-6">
          <!-- Code Editor -->
          <div class="bg-white shadow rounded-lg p-6">
            <div class="flex items-center justify-between mb-4">
              <h2 class="text-lg font-semibold text-gray-900">Code Editor</h2>
              <button
                phx-click="reset_code"
                class="text-sm text-gray-600 hover:text-gray-800 transition-colors"
              >
                Reset to Template
              </button>
            </div>
            
            <!-- Monaco Editor -->
            <div class="space-y-4">
              <div
                id="monaco-editor"
                phx-hook="MonacoEditor"
                data-initial-value={@user_code}
                data-language="elixir"
                data-read-only="false"
                class="w-full border border-gray-300 rounded-md"
                style="height: 400px;"
              ></div>
              
              <!-- Real-time Execution Status -->
              <%= if @execution_status do %>
                <div class="mb-4 p-3 bg-blue-50 border border-blue-200 rounded-md">
                  <div class="flex items-center">
                    <%= if @execution_loading do %>
                      <svg class="animate-spin -ml-1 mr-3 h-4 w-4 text-blue-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                      </svg>
                    <% else %>
                      <svg class="h-4 w-4 text-blue-600 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                      </svg>
                    <% end %>
                    <span class="text-sm font-medium text-blue-800"><%= @execution_status %></span>
                  </div>
                </div>
              <% end %>

              <!-- Real-time Submission Status -->
              <%= if @submission_status do %>
                <div class="mb-4 p-3 bg-green-50 border border-green-200 rounded-md">
                  <div class="flex items-center">
                    <%= if @submission_loading do %>
                      <svg class="animate-spin -ml-1 mr-3 h-4 w-4 text-green-600" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                      </svg>
                    <% else %>
                      <svg class="h-4 w-4 text-green-600 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path>
                      </svg>
                    <% end %>
                    <span class="text-sm font-medium text-green-800"><%= @submission_status %></span>
                  </div>
                </div>
              <% end %>

              <div class="flex space-x-3">
                <button
                  phx-click="execute_code"
                  disabled={@execution_loading}
                  class="flex-1 bg-blue-600 hover:bg-blue-700 disabled:bg-blue-400 text-white font-medium py-2 px-4 rounded-md transition-colors"
                >
                  <%= if @execution_loading do %>
                    <span class="flex items-center justify-center">
                      <svg class="animate-spin -ml-1 mr-3 h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                      </svg>
                      Running...
                    </span>
                  <% else %>
                    Run Code
                  <% end %>
                </button>
                
                <button
                  phx-click="submit_solution"
                  disabled={@submission_loading}
                  class="flex-1 bg-green-600 hover:bg-green-700 disabled:bg-green-400 text-white font-medium py-2 px-4 rounded-md transition-colors"
                >
                  <%= if @submission_loading do %>
                    <span class="flex items-center justify-center">
                      <svg class="animate-spin -ml-1 mr-3 h-4 w-4 text-white" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
                        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
                        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
                      </svg>
                      Submitting...
                    </span>
                  <% else %>
                    Submit Solution
                  <% end %>
                </button>
              </div>
            </div>
          </div>

          <!-- Progress Info -->
          <%= if @user_progress do %>
            <div class="bg-white shadow rounded-lg p-6">
              <h3 class="text-lg font-semibold text-gray-900 mb-4">Your Progress</h3>
              <div class="space-y-2">
                <div class="flex justify-between text-sm">
                  <span class="text-gray-600">Status:</span>
                  <span class={[
                    "font-medium",
                    progress_status_class(@user_progress.status)
                  ]}>
                    <%= format_status(@user_progress.status) %>
                  </span>
                </div>
                <div class="flex justify-between text-sm">
                  <span class="text-gray-600">Attempts:</span>
                  <span class="font-medium text-gray-900"><%= @user_progress.attempts || 0 %></span>
                </div>
                <%= if @user_progress.completed_at do %>
                  <div class="flex justify-between text-sm">
                    <span class="text-gray-600">Completed:</span>
                    <span class="font-medium text-gray-900">
                      <%= Calendar.strftime(@user_progress.completed_at, "%B %d, %Y") %>
                    </span>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>

          <!-- Live Statistics -->
          <%= if @user_stats do %>
            <div class="bg-white shadow rounded-lg p-6">
              <h3 class="text-lg font-semibold text-gray-900 mb-4">📊 Your Statistics</h3>
              <div class="space-y-3">
                <div class="flex justify-between text-sm">
                  <span class="text-gray-600">Overall Progress:</span>
                  <span class="font-medium text-blue-600"><%= @user_stats.completion_percentage %>%</span>
                </div>
                <div class="w-full bg-gray-200 rounded-full h-2">
                  <div class="bg-blue-600 h-2 rounded-full transition-all duration-500" style={"width: #{@user_stats.completion_percentage}%"}></div>
                </div>
                <div class="grid grid-cols-2 gap-4 text-sm">
                  <div class="text-center">
                    <div class="font-medium text-green-600"><%= @user_stats.completed_lessons %></div>
                    <div class="text-gray-500">Completed</div>
                  </div>
                  <div class="text-center">
                    <div class="font-medium text-yellow-600"><%= @user_stats.in_progress_lessons %></div>
                    <div class="text-gray-500">In Progress</div>
                  </div>
                </div>
              </div>
            </div>
          <% end %>

          <!-- Live Lesson Statistics -->
          <%= if @lesson_stats do %>
            <div class="bg-white shadow rounded-lg p-6">
              <h3 class="text-lg font-semibold text-gray-900 mb-4">🎯 Lesson Statistics</h3>
              <div class="space-y-3">
                <div class="flex justify-between text-sm">
                  <span class="text-gray-600">Completion Rate:</span>
                  <span class="font-medium text-purple-600"><%= @lesson_stats.completion_rate %>%</span>
                </div>
                <div class="w-full bg-gray-200 rounded-full h-2">
                  <div class="bg-purple-600 h-2 rounded-full transition-all duration-500" style={"width: #{@lesson_stats.completion_rate}%"}></div>
                </div>
                <div class="grid grid-cols-2 gap-4 text-sm">
                  <div class="text-center">
                    <div class="font-medium text-green-600"><%= @lesson_stats.completed_count %></div>
                    <div class="text-gray-500">Completed</div>
                  </div>
                  <div class="text-center">
                    <div class="font-medium text-yellow-600"><%= @lesson_stats.in_progress_count %></div>
                    <div class="text-gray-500">Working On</div>
                  </div>
                </div>
                <%= if @lesson_stats.average_attempts > 0 do %>
                  <div class="text-center text-sm pt-2 border-t">
                    <div class="font-medium text-gray-700"><%= @lesson_stats.average_attempts %></div>
                    <div class="text-gray-500">Avg. Attempts</div>
                  </div>
                <% end %>
              </div>
            </div>
          <% end %>
        </div>
      </div>
    </div>
    """
  end

  # Helper functions

  defp get_initial_code(lesson, user_progress) do
    cond do
      user_progress && user_progress.last_code ->
        user_progress.last_code
      lesson.template_code ->
        lesson.template_code
      true ->
        ""
    end
  end

  defp format_instructions(instructions) do
    instructions
    # Handle code blocks first (```code```)
    |> String.replace(~r/```([^`]+)```/s, "<pre class=\"bg-gray-100 p-3 rounded text-sm font-mono overflow-x-auto mb-4\"><code>\\1</code></pre>")
    # Handle paragraphs
    |> String.replace("\n\n", "</p><p class=\"mb-4\">")
    |> String.replace("\n", "<br>")
    # Handle inline code
    |> String.replace(~r/`([^`]+)`/, "<code class=\"bg-gray-100 px-1 py-0.5 rounded text-sm font-mono\">\\1</code>")
    # Handle bold text
    |> String.replace(~r/\*\*([^*]+)\*\*/, "<strong>\\1</strong>")
    # Handle italic text
    |> String.replace(~r/\*([^*]+)\*/, "<em>\\1</em>")
    # Handle numbered lists
    |> String.replace(~r/^\d+\.\s+(.+)$/m, "<li class=\"mb-2\">\\1</li>")
    # Handle bullet points
    |> String.replace(~r/^[-*]\s+(.+)$/m, "<li class=\"mb-2\">\\1</li>")
    # Wrap in paragraph tags
    |> then(&("<p class=\"mb-4\">#{&1}</p>"))
    # Clean up any list items that got wrapped in paragraphs
    |> String.replace("<p class=\"mb-4\"><li", "<ul class=\"list-disc list-inside mb-4\"><li")
    |> String.replace("</li></p>", "</li></ul>")
  end

  defp difficulty_badge_class("beginner"), do: "bg-green-100 text-green-800"
  defp difficulty_badge_class("intermediate"), do: "bg-yellow-100 text-yellow-800"
  defp difficulty_badge_class("advanced"), do: "bg-red-100 text-red-800"
  defp difficulty_badge_class(_), do: "bg-gray-100 text-gray-800"

  defp progress_status_class("completed"), do: "text-green-600"
  defp progress_status_class("in_progress"), do: "text-yellow-600"
  defp progress_status_class(_), do: "text-gray-600"

  defp lesson_progress_class(lesson_info, current_lesson_id) do
    cond do
      lesson_info.lesson.id == current_lesson_id ->
        "bg-blue-600 text-white"
      lesson_info.status == :completed ->
        "bg-green-600 text-white"
      lesson_info.status == :available ->
        "bg-gray-200 text-gray-700"
      true ->
        "bg-gray-100 text-gray-400"
    end
  end

  defp format_status("not_started"), do: "Not Started"
  defp format_status("in_progress"), do: "In Progress"
  defp format_status("completed"), do: "Completed"
  defp format_status(status), do: String.capitalize(status)

  defp get_navigation_lessons(current_lesson, available_lessons) do
    # Find current lesson in the available lessons list
    current_index = Enum.find_index(available_lessons, fn lesson_info ->
      lesson_info.lesson.id == current_lesson.id
    end)

    case current_index do
      nil -> {nil, nil}
      index ->
        prev_lesson = if index > 0 do
          Enum.at(available_lessons, index - 1).lesson
        else
          nil
        end

        next_lesson = if index < length(available_lessons) - 1 do
          next_lesson_info = Enum.at(available_lessons, index + 1)
          if next_lesson_info.status in [:available, :completed] do
            next_lesson_info.lesson
          else
            nil
          end
        else
          nil
        end

        {prev_lesson, next_lesson}
    end
  end
end