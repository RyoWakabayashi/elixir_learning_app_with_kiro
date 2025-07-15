defmodule ElixirLearningApp.Execution do
  @moduledoc """
  The Execution context.
  """

  alias ElixirLearningApp.Execution.{CodeExecutor, ResultFormatter}

  defdelegate execute_code(code, opts \\ []), to: CodeExecutor, as: :execute
  defdelegate execute_and_format_code(code, opts \\ []), to: CodeExecutor, as: :execute_and_format
  defdelegate validate_safety(code), to: CodeExecutor
  defdelegate format_result(result), to: ResultFormatter
end