defmodule ElixirLearningApp.Execution.CodeExecutor do
  @moduledoc """
  Safe code execution with sandboxing, timeout controls, and dangerous code detection.
  
  This module provides a secure way to execute user-submitted Elixir code by:
  - Running code in supervised temporary processes
  - Enforcing timeout limits
  - Detecting and blocking dangerous operations
  - Capturing output and errors safely
  """

  require Logger
  
  alias ElixirLearningApp.Execution.ResultFormatter

  @default_timeout 5_000
  @max_memory_mb 50
  
  # Dangerous patterns that should be blocked
  @dangerous_patterns [
    # File system operations
    ~r/File\./,
    ~r/Path\./,
    ~r/:file\./,
    ~r/System\./,
    
    # Network operations
    ~r/HTTPoison/,
    ~r/:httpc/,
    ~r/:gen_tcp/,
    ~r/:gen_udp/,
    ~r/Socket\./,
    
    # Process operations
    ~r/Process\.spawn/,
    ~r/spawn/,
    ~r/spawn_link/,
    ~r/spawn_monitor/,
    ~r/:os\./,
    
    # Code evaluation (prevent nested evaluation)
    ~r/Code\.eval/,
    ~r/Code\.compile/,
    ~r/Code\.load/,
    
    # Dangerous modules
    ~r/:ets/,
    ~r/:dets/,
    ~r/:mnesia/,
    ~r/Agent\./,
    ~r/GenServer\./,
    ~r/Task\./,
    
    # Shell commands
    ~r/System\.cmd/,
    ~r/Port\./,
    ~r/:erlang\.port/
  ]

  @doc """
  Execute Elixir code safely with timeout and resource limits.
  
  ## Options
  
    * `:timeout` - Maximum execution time in milliseconds (default: 5000)
    * `:memory_limit_mb` - Maximum memory usage in MB (default: 50)
    * `:capture_output` - Whether to capture IO output (default: true)
  
  ## Returns
  
    * `{:ok, result}` - Successful execution with result
    * `{:error, reason}` - Execution failed with reason
  
  ## Examples
  
      iex> CodeExecutor.execute("1 + 1")
      {:ok, %{result: 2, output: "", error: nil, execution_time_ms: 1}}
      
      iex> CodeExecutor.execute("IO.puts(\"Hello\")")
      {:ok, %{result: :ok, output: "Hello\\n", error: nil, execution_time_ms: 2}}
      
      iex> CodeExecutor.execute("File.read(\"/etc/passwd\")")
      {:error, :dangerous_code}
  """
  def execute(code, opts \\ []) when is_binary(code) do
    timeout = Keyword.get(opts, :timeout, @default_timeout)
    memory_limit_mb = Keyword.get(opts, :memory_limit_mb, @max_memory_mb)
    capture_output = Keyword.get(opts, :capture_output, true)

    with :ok <- validate_safety(code),
         {:ok, result} <- execute_in_sandbox(code, timeout, memory_limit_mb, capture_output) do
      {:ok, result}
    else
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Execute code and return formatted result for display.
  
  This is a convenience function that executes code and formats the result
  for user-friendly display in the learning application.
  """
  def execute_and_format(code, opts \\ []) when is_binary(code) do
    case execute(code, opts) do
      {:ok, result} ->
        {:ok, ResultFormatter.format_result(result)}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Validate that code doesn't contain dangerous operations.
  
  Returns `:ok` if code is safe, `{:error, :dangerous_code}` otherwise.
  """
  def validate_safety(code) when is_binary(code) do
    if contains_dangerous_code?(code) do
      Logger.warning("Dangerous code detected: #{inspect(code)}")
      {:error, :dangerous_code}
    else
      :ok
    end
  end

  # Private functions

  defp contains_dangerous_code?(code) do
    Enum.any?(@dangerous_patterns, fn pattern ->
      Regex.match?(pattern, code)
    end)
  end

  defp execute_in_sandbox(code, timeout, memory_limit_mb, capture_output) do
    start_time = System.monotonic_time(:millisecond)
    
    task = Task.async(fn ->
      try do
        # Set memory limit for the process
        Process.flag(:max_heap_size, div(memory_limit_mb * 1024 * 1024, 8)) # Convert MB to words
        
        if capture_output do
          execute_with_output_capture(code)
        else
          execute_without_output_capture(code)
        end
      rescue
        error ->
          {:error, format_error(error)}
      catch
        :exit, reason ->
          {:error, "Process exited: #{inspect(reason)}"}
        :throw, value ->
          {:error, "Uncaught throw: #{inspect(value)}"}
      end
    end)

    case Task.yield(task, timeout) || Task.shutdown(task) do
      {:ok, result} ->
        end_time = System.monotonic_time(:millisecond)
        execution_time = end_time - start_time
        
        case result do
          {:ok, execution_result} ->
            {:ok, Map.put(execution_result, :execution_time_ms, execution_time)}
          {:error, reason} ->
            {:error, reason}
        end
        
      nil ->
        Logger.warning("Code execution timed out after #{timeout}ms")
        {:error, :timeout}
    end
  end

  defp execute_with_output_capture(code) do
    # Capture IO output
    original_group_leader = Process.group_leader()
    {:ok, string_io} = StringIO.open("")
    Process.group_leader(self(), string_io)
    
    try do
      # Evaluate the code
      {result, _binding} = Code.eval_string(code, [], __ENV__)
      
      # Get captured output
      output = StringIO.flush(string_io)
      
      {:ok, %{
        result: result,
        output: output,
        error: nil
      }}
    rescue
      error ->
        output = StringIO.flush(string_io)
        {:ok, %{
          result: nil,
          output: output,
          error: format_error(error)
        }}
    after
      Process.group_leader(self(), original_group_leader)
      StringIO.close(string_io)
    end
  end

  defp execute_without_output_capture(code) do
    try do
      {result, _binding} = Code.eval_string(code, [], __ENV__)
      
      {:ok, %{
        result: result,
        output: "",
        error: nil
      }}
    rescue
      error ->
        {:ok, %{
          result: nil,
          output: "",
          error: format_error(error)
        }}
    end
  end

  defp format_error(%{__struct__: error_type} = error) do
    case error_type do
      CompileError ->
        "Compilation Error: #{error.description}"
      
      SyntaxError ->
        "Syntax Error: #{error.description}"
      
      ArithmeticError ->
        "Arithmetic Error: #{Exception.message(error)}"
      
      ArgumentError ->
        "Argument Error: #{Exception.message(error)}"
      
      FunctionClauseError ->
        "Function Clause Error: #{Exception.message(error)}"
      
      UndefinedFunctionError ->
        "Undefined Function Error: #{Exception.message(error)}"
      
      _ ->
        "Runtime Error: #{Exception.message(error)}"
    end
  end

  defp format_error(error) when is_binary(error), do: error
  defp format_error(error), do: "Unknown Error: #{inspect(error)}"
end