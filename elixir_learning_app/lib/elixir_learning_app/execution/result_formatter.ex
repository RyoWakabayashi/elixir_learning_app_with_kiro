defmodule ElixirLearningApp.Execution.ResultFormatter do
  @moduledoc """
  Formats code execution results for display in the user interface.
  
  This module provides functions to format execution results, errors, and output
  in a user-friendly way for display in the learning application.
  """

  @doc """
  Format execution result for display.
  
  Takes a raw execution result and formats it for user-friendly display.
  """
  def format_result(%{result: result, output: output, error: error, execution_time_ms: time}) do
    %{
      success: error == nil,
      result: format_value(result),
      output: format_output(output),
      error: format_error_message(error),
      execution_time: format_execution_time(time),
      raw_result: result
    }
  end

  @doc """
  Format a value for display, handling different Elixir data types appropriately.
  """
  def format_value(nil), do: "nil"
  def format_value(value) when is_binary(value), do: inspect(value)
  def format_value(value) when is_atom(value), do: inspect(value)
  def format_value(value) when is_number(value), do: inspect(value)
  def format_value(value) when is_list(value), do: format_list(value)
  def format_value(value) when is_map(value), do: format_map(value)
  def format_value(value) when is_tuple(value), do: format_tuple(value)
  def format_value(value), do: inspect(value, pretty: true, limit: 50)

  @doc """
  Format output text for display, handling newlines and empty output.
  """
  def format_output(""), do: nil
  def format_output(output) when is_binary(output) do
    output
    |> String.trim_trailing()
    |> case do
      "" -> nil
      formatted -> formatted
    end
  end

  @doc """
  Format error message for user-friendly display.
  """
  def format_error_message(nil), do: nil
  def format_error_message(error) when is_binary(error) do
    error
    |> String.replace(~r/\s+/, " ")
    |> String.trim()
  end

  @doc """
  Format execution time for display.
  """
  def format_execution_time(time_ms) when is_integer(time_ms) do
    cond do
      time_ms < 1 -> "< 1ms"
      time_ms < 1000 -> "#{time_ms}ms"
      time_ms < 60_000 -> "#{Float.round(time_ms / 1000, 2)}s"
      true -> "#{Float.round(time_ms / 60_000, 2)}min"
    end
  end

  @doc """
  Create a summary of the execution result.
  """
  def create_summary(%{success: true, result: result, output: output, execution_time: time}) do
    parts = []
    
    parts = if result && result != "nil", do: ["Result: #{result}" | parts], else: parts
    parts = if output, do: ["Output: #{String.slice(output, 0, 100)}" | parts], else: parts
    parts = ["Executed in #{time}" | parts]
    
    Enum.reverse(parts) |> Enum.join(" | ")
  end

  def create_summary(%{success: false, error: error, execution_time: time}) do
    "Error: #{String.slice(error, 0, 100)} | Failed in #{time}"
  end

  # Private helper functions

  defp format_list(list) when length(list) <= 10 do
    inspect(list, pretty: true)
  end

  defp format_list(list) do
    first_items = Enum.take(list, 5)
    "#{inspect(first_items, pretty: true) |> String.trim_trailing("]")} ... (#{length(list)} items)]"
  end

  defp format_map(map) when map_size(map) <= 5 do
    inspect(map, pretty: true)
  end

  defp format_map(map) do
    first_items = map |> Enum.take(3) |> Map.new()
    "#{inspect(first_items, pretty: true) |> String.trim_trailing("}")} ... (#{map_size(map)} keys)}"
  end

  defp format_tuple(tuple) when tuple_size(tuple) <= 5 do
    inspect(tuple, pretty: true)
  end

  defp format_tuple(tuple) do
    first_items = tuple |> Tuple.to_list() |> Enum.take(3) |> List.to_tuple()
    "#{inspect(first_items, pretty: true) |> String.trim_trailing("}")} ... (#{tuple_size(tuple)} elements)}"
  end
end