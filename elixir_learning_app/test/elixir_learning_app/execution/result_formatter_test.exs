defmodule ElixirLearningApp.Execution.ResultFormatterTest do
  use ExUnit.Case, async: true
  
  alias ElixirLearningApp.Execution.ResultFormatter

  describe "format_result/1" do
    test "formats successful execution result" do
      raw_result = %{
        result: 42,
        output: "Hello World\n",
        error: nil,
        execution_time_ms: 150
      }
      
      formatted = ResultFormatter.format_result(raw_result)
      
      assert formatted.success == true
      assert formatted.result == "42"
      assert formatted.output == "Hello World"
      assert formatted.error == nil
      assert formatted.execution_time == "150ms"
      assert formatted.raw_result == 42
    end

    test "formats failed execution result" do
      raw_result = %{
        result: nil,
        output: "",
        error: "Syntax Error: unexpected token",
        execution_time_ms: 50
      }
      
      formatted = ResultFormatter.format_result(raw_result)
      
      assert formatted.success == false
      assert formatted.result == "nil"
      assert formatted.output == nil
      assert formatted.error == "Syntax Error: unexpected token"
      assert formatted.execution_time == "50ms"
      assert formatted.raw_result == nil
    end
  end

  describe "format_value/1" do
    test "formats nil" do
      assert ResultFormatter.format_value(nil) == "nil"
    end

    test "formats strings" do
      assert ResultFormatter.format_value("hello") == ~s("hello")
    end

    test "formats atoms" do
      assert ResultFormatter.format_value(:ok) == ":ok"
    end

    test "formats numbers" do
      assert ResultFormatter.format_value(42) == "42"
      assert ResultFormatter.format_value(3.14) == "3.14"
    end

    test "formats small lists" do
      result = ResultFormatter.format_value([1, 2, 3])
      assert result == "[1, 2, 3]"
    end

    test "formats large lists with truncation" do
      large_list = Enum.to_list(1..20)
      result = ResultFormatter.format_value(large_list)
      assert result =~ "... (20 items)]"
      assert result =~ "[1, 2, 3, 4, 5"
    end

    test "formats small maps" do
      result = ResultFormatter.format_value(%{a: 1, b: 2})
      assert result =~ "%{a: 1, b: 2}" or result =~ "%{b: 2, a: 1}"
    end

    test "formats large maps with truncation" do
      large_map = 1..10 |> Enum.map(&{:"key#{&1}", &1}) |> Map.new()
      result = ResultFormatter.format_value(large_map)
      assert result =~ "... (10 keys)}"
    end

    test "formats small tuples" do
      result = ResultFormatter.format_value({:ok, "success"})
      assert result == ~s({:ok, "success"})
    end

    test "formats large tuples with truncation" do
      large_tuple = 1..10 |> Enum.to_list() |> List.to_tuple()
      result = ResultFormatter.format_value(large_tuple)
      assert result =~ "... (10 elements)}"
      assert result =~ "{1, 2, 3"
    end
  end

  describe "format_output/1" do
    test "returns nil for empty string" do
      assert ResultFormatter.format_output("") == nil
    end

    test "trims trailing whitespace" do
      assert ResultFormatter.format_output("Hello World\n\n  ") == "Hello World"
    end

    test "returns nil for whitespace-only string" do
      assert ResultFormatter.format_output("   \n\t  ") == nil
    end

    test "preserves internal whitespace" do
      assert ResultFormatter.format_output("Line 1\nLine 2") == "Line 1\nLine 2"
    end
  end

  describe "format_error_message/1" do
    test "returns nil for nil error" do
      assert ResultFormatter.format_error_message(nil) == nil
    end

    test "normalizes whitespace in error messages" do
      error = "This is a   long\n\terror    message"
      result = ResultFormatter.format_error_message(error)
      assert result == "This is a long error message"
    end

    test "trims error messages" do
      error = "  Error message  "
      result = ResultFormatter.format_error_message(error)
      assert result == "Error message"
    end
  end

  describe "format_execution_time/1" do
    test "formats sub-millisecond times" do
      assert ResultFormatter.format_execution_time(0) == "< 1ms"
    end

    test "formats milliseconds" do
      assert ResultFormatter.format_execution_time(150) == "150ms"
      assert ResultFormatter.format_execution_time(999) == "999ms"
    end

    test "formats seconds" do
      assert ResultFormatter.format_execution_time(1500) == "1.5s"
      assert ResultFormatter.format_execution_time(30000) == "30.0s"
    end

    test "formats minutes" do
      assert ResultFormatter.format_execution_time(90000) == "1.5min"
      assert ResultFormatter.format_execution_time(120000) == "2.0min"
    end
  end

  describe "create_summary/1" do
    test "creates summary for successful execution with result and output" do
      formatted_result = %{
        success: true,
        result: "42",
        output: "Debug info",
        execution_time: "150ms"
      }
      
      summary = ResultFormatter.create_summary(formatted_result)
      assert summary == "Result: 42 | Output: Debug info | Executed in 150ms"
    end

    test "creates summary for successful execution with only result" do
      formatted_result = %{
        success: true,
        result: "42",
        output: nil,
        execution_time: "150ms"
      }
      
      summary = ResultFormatter.create_summary(formatted_result)
      assert summary == "Result: 42 | Executed in 150ms"
    end

    test "creates summary for successful execution with nil result" do
      formatted_result = %{
        success: true,
        result: "nil",
        output: "Some output",
        execution_time: "150ms"
      }
      
      summary = ResultFormatter.create_summary(formatted_result)
      assert summary == "Output: Some output | Executed in 150ms"
    end

    test "creates summary for failed execution" do
      formatted_result = %{
        success: false,
        error: "Syntax error in code",
        execution_time: "50ms"
      }
      
      summary = ResultFormatter.create_summary(formatted_result)
      assert summary == "Error: Syntax error in code | Failed in 50ms"
    end

    test "truncates long output in summary" do
      long_output = String.duplicate("A", 150)
      formatted_result = %{
        success: true,
        result: "42",
        output: long_output,
        execution_time: "150ms"
      }
      
      summary = ResultFormatter.create_summary(formatted_result)
      assert String.length(summary) < String.length(long_output) + 50
      assert summary =~ "Result: 42 | Output: #{String.slice(long_output, 0, 100)} | Executed in 150ms"
    end

    test "truncates long error in summary" do
      long_error = String.duplicate("Error message ", 20)
      formatted_result = %{
        success: false,
        error: long_error,
        execution_time: "50ms"
      }
      
      summary = ResultFormatter.create_summary(formatted_result)
      assert String.length(summary) < String.length(long_error) + 50
      assert summary =~ "Error: #{String.slice(long_error, 0, 100)} | Failed in 50ms"
    end
  end
end