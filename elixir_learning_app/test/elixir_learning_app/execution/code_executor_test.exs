defmodule ElixirLearningApp.Execution.CodeExecutorTest do
  use ExUnit.Case, async: true
  
  alias ElixirLearningApp.Execution.CodeExecutor

  describe "execute/2" do
    test "executes simple arithmetic successfully" do
      assert {:ok, result} = CodeExecutor.execute("1 + 1")
      assert result.result == 2
      assert result.output == ""
      assert result.error == nil
      assert is_integer(result.execution_time_ms)
    end

    test "executes string operations successfully" do
      code = ~s("Hello " <> "World")
      assert {:ok, result} = CodeExecutor.execute(code)
      assert result.result == "Hello World"
      assert result.output == ""
      assert result.error == nil
    end

    test "executes list operations successfully" do
      code = "[1, 2, 3] |> Enum.map(&(&1 * 2))"
      assert {:ok, result} = CodeExecutor.execute(code)
      assert result.result == [2, 4, 6]
      assert result.output == ""
      assert result.error == nil
    end

    test "captures IO output" do
      code = ~s[IO.puts("Hello World")]
      assert {:ok, result} = CodeExecutor.execute(code)
      assert result.result == :ok
      assert result.output == "Hello World\n"
      assert result.error == nil
    end

    test "captures multiple IO outputs" do
      code = """
      IO.puts("Line 1")
      IO.puts("Line 2")
      "result"
      """
      assert {:ok, result} = CodeExecutor.execute(code)
      assert result.result == "result"
      assert result.output == "Line 1\nLine 2\n"
      assert result.error == nil
    end

    test "handles syntax errors gracefully" do
      code = "1 + * 2"  # This will cause a syntax error
      assert {:ok, result} = CodeExecutor.execute(code)
      assert result.result == nil
      assert result.output == ""
      assert result.error =~ "Syntax Error"
    end

    test "handles runtime errors gracefully" do
      code = "1 / 0"
      assert {:ok, result} = CodeExecutor.execute(code)
      assert result.result == nil
      assert result.output == ""
      assert result.error =~ "Arithmetic Error"
    end

    test "handles undefined function errors" do
      code = "non_existent_function()"
      assert {:ok, result} = CodeExecutor.execute(code)
      assert result.result == nil
      assert result.output == ""
      assert result.error =~ "Undefined Function Error"
    end

    test "handles function clause errors" do
      code = """
      defmodule TestMod do
        def test_func(:ok), do: "success"
      end
      TestMod.test_func(:error)
      """
      assert {:ok, result} = CodeExecutor.execute(code)
      assert result.result == nil
      assert result.output == ""
      assert result.error =~ "Function Clause Error"
    end

    test "respects timeout limits" do
      # Code that would run indefinitely
      code = """
      Stream.iterate(0, &(&1 + 1))
      |> Enum.take(1_000_000)
      |> Enum.sum()
      """
      
      assert {:error, :timeout} = CodeExecutor.execute(code, timeout: 100)
    end

    test "allows custom timeout" do
      code = ":timer.sleep(50); :ok"
      assert {:ok, result} = CodeExecutor.execute(code, timeout: 200)
      assert result.result == :ok
    end

    test "can disable output capture" do
      code = ~s[IO.puts("Hello World"); "result"]
      assert {:ok, result} = CodeExecutor.execute(code, capture_output: false)
      assert result.result == "result"
      assert result.output == ""
      assert result.error == nil
    end
  end

  describe "validate_safety/1" do
    test "allows safe code" do
      safe_codes = [
        "1 + 1",
        "Enum.map([1, 2, 3], &(&1 * 2))",
        ~s[IO.puts("Hello")],
        "String.upcase(\"hello\")",
        "Regex.match?(~r/test/, \"testing\")"
      ]

      for code <- safe_codes do
        assert :ok = CodeExecutor.validate_safety(code), 
               "Expected #{inspect(code)} to be safe"
      end
    end

    test "blocks file system operations" do
      dangerous_codes = [
        "File.read(\"/etc/passwd\")",
        "File.write(\"test.txt\", \"content\")",
        "Path.join([\"/tmp\", \"file\"])",
        ":file.read(\"/etc/passwd\")"
      ]

      for code <- dangerous_codes do
        assert {:error, :dangerous_code} = CodeExecutor.validate_safety(code),
               "Expected #{inspect(code)} to be blocked"
      end
    end

    test "blocks network operations" do
      dangerous_codes = [
        "HTTPoison.get(\"http://example.com\")",
        ":httpc.request(\"http://example.com\")",
        ":gen_tcp.connect('localhost', 80, [])",
        "Socket.TCP.connect(\"localhost\", 80)"
      ]

      for code <- dangerous_codes do
        assert {:error, :dangerous_code} = CodeExecutor.validate_safety(code),
               "Expected #{inspect(code)} to be blocked"
      end
    end

    test "blocks process operations" do
      dangerous_codes = [
        "Process.spawn(fn -> :ok end)",
        "spawn(fn -> :ok end)",
        "spawn_link(fn -> :ok end)",
        ":os.cmd('ls')"
      ]

      for code <- dangerous_codes do
        assert {:error, :dangerous_code} = CodeExecutor.validate_safety(code),
               "Expected #{inspect(code)} to be blocked"
      end
    end

    test "blocks code evaluation" do
      dangerous_codes = [
        "Code.eval_string(\"1 + 1\")",
        "Code.compile_string(\"defmodule Test, do: nil\")",
        "Code.load_file(\"test.ex\")"
      ]

      for code <- dangerous_codes do
        assert {:error, :dangerous_code} = CodeExecutor.validate_safety(code),
               "Expected #{inspect(code)} to be blocked"
      end
    end

    test "blocks dangerous modules" do
      dangerous_codes = [
        ":ets.new(:test, [])",
        "Agent.start_link(fn -> 0 end)",
        "GenServer.start_link(__MODULE__, [])",
        "Task.start(fn -> :ok end)"
      ]

      for code <- dangerous_codes do
        assert {:error, :dangerous_code} = CodeExecutor.validate_safety(code),
               "Expected #{inspect(code)} to be blocked"
      end
    end

    test "blocks system commands" do
      dangerous_codes = [
        "System.cmd(\"ls\", [])",
        "Port.open({:spawn, \"ls\"}, [])",
        ":erlang.port_open({:spawn, \"ls\"}, [])"
      ]

      for code <- dangerous_codes do
        assert {:error, :dangerous_code} = CodeExecutor.validate_safety(code),
               "Expected #{inspect(code)} to be blocked"
      end
    end
  end

  describe "execute_and_format/2" do
    test "returns formatted result for successful execution" do
      assert {:ok, result} = CodeExecutor.execute_and_format("1 + 1")
      assert result.success == true
      assert result.result == "2"
      assert result.output == nil
      assert result.error == nil
      assert is_binary(result.execution_time)
    end

    test "returns formatted result for failed execution" do
      assert {:ok, result} = CodeExecutor.execute_and_format("1 / 0")
      assert result.success == false
      assert result.result == "nil"
      assert result.output == nil
      assert is_binary(result.error)
      assert result.error =~ "Arithmetic Error"
    end

    test "returns error for dangerous code" do
      assert {:error, :dangerous_code} = CodeExecutor.execute_and_format("File.read(\"/etc/passwd\")")
    end
  end

  describe "edge cases and comprehensive error handling" do
    test "handles very large numbers" do
      code = "1_000_000_000_000_000_000_000"
      assert {:ok, result} = CodeExecutor.execute(code)
      assert is_integer(result.result)
      assert result.error == nil
    end

    test "handles very long strings" do
      code = ~s("#{String.duplicate("A", 10000)}")
      assert {:ok, result} = CodeExecutor.execute(code)
      assert is_binary(result.result)
      assert String.length(result.result) == 10000
      assert result.error == nil
    end

    test "handles deeply nested data structures" do
      code = """
      nested = %{
        level1: %{
          level2: %{
            level3: [1, 2, 3, %{level4: "deep"}]
          }
        }
      }
      nested.level1.level2.level3
      """
      assert {:ok, result} = CodeExecutor.execute(code)
      assert result.result == [1, 2, 3, %{level4: "deep"}]
      assert result.error == nil
    end

    test "handles multiple IO operations" do
      code = """
      IO.puts("First line")
      IO.write("Second ")
      IO.write("line")
      IO.puts("")
      IO.puts("Third line")
      :done
      """
      assert {:ok, result} = CodeExecutor.execute(code)
      assert result.result == :done
      assert result.output == "First line\nSecond line\nThird line\n"
      assert result.error == nil
    end

    test "handles code with comments" do
      code = """
      # This is a comment
      x = 5 # Another comment
      # Final comment
      x * 2
      """
      assert {:ok, result} = CodeExecutor.execute(code)
      assert result.result == 10
      assert result.error == nil
    end

    test "handles empty code" do
      assert {:ok, result} = CodeExecutor.execute("")
      assert result.result == nil
      assert result.output == ""
      assert result.error == nil
    end

    test "handles whitespace-only code" do
      assert {:ok, result} = CodeExecutor.execute("   \n\t  ")
      assert result.result == nil
      assert result.output == ""
      assert result.error == nil
    end

    test "handles code with only comments" do
      code = """
      # This is just a comment
      # Another comment
      """
      assert {:ok, result} = CodeExecutor.execute(code)
      assert result.result == nil
      assert result.output == ""
      assert result.error == nil
    end

    test "handles invalid UTF-8 in strings" do
      # This should still work as Elixir handles binary data
      code = ~s(<<0xFF, 0xFE>>)
      assert {:ok, result} = CodeExecutor.execute(code)
      assert result.result == <<0xFF, 0xFE>>
      assert result.error == nil
    end

    test "handles circular references in data structures" do
      # Elixir doesn't have mutable references like some languages,
      # but we can test self-referencing atoms
      code = """
      defmodule SelfRef do
        def create_cycle do
          # This creates a structure that references itself conceptually
          %{type: :cycle, ref: :self}
        end
      end
      SelfRef.create_cycle()
      """
      assert {:ok, result} = CodeExecutor.execute(code)
      assert result.result == %{type: :cycle, ref: :self}
      assert result.error == nil
    end

    test "handles exceptions in custom modules" do
      code = """
      defmodule ErrorTest do
        def raise_error do
          raise ArgumentError, "Custom error message"
        end
      end
      ErrorTest.raise_error()
      """
      assert {:ok, result} = CodeExecutor.execute(code)
      assert result.result == nil
      assert result.error =~ "Argument Error"
      assert result.error =~ "Custom error message"
    end

    test "handles try-catch-rescue blocks" do
      code = """
      try do
        1 / 0
      rescue
        ArithmeticError -> :caught_arithmetic_error
      catch
        :throw, value -> {:caught_throw, value}
      end
      """
      assert {:ok, result} = CodeExecutor.execute(code)
      assert result.result == :caught_arithmetic_error
      assert result.error == nil
    end

    test "handles process-related functions safely" do
      code = """
      # Test process-related functions that are safe
      current_pid = self()
      Process.alive?(current_pid)
      """
      assert {:ok, result} = CodeExecutor.execute(code)
      assert result.result == true
      assert result.error == nil
    end

    test "handles large list operations" do
      code = """
      1..1000
      |> Enum.to_list()
      |> Enum.map(&(&1 * 2))
      |> Enum.filter(&(rem(&1, 4) == 0))
      |> Enum.take(5)
      """
      assert {:ok, result} = CodeExecutor.execute(code)
      assert result.result == [4, 8, 12, 16, 20]
      assert result.error == nil
    end

    test "handles string interpolation with complex expressions" do
      code = """
      name = "World"
      count = 5
      "Hello " <> String.upcase(name) <> "! Count: " <> Integer.to_string(count * 2)
      """
      assert {:ok, result} = CodeExecutor.execute(code)
      assert result.result == "Hello WORLD! Count: 10"
      assert result.error == nil
    end

    test "handles anonymous functions and closures" do
      code = """
      multiplier = 3
      func = fn x -> x * multiplier end
      [1, 2, 3, 4, 5] |> Enum.map(func)
      """
      assert {:ok, result} = CodeExecutor.execute(code)
      assert result.result == [3, 6, 9, 12, 15]
      assert result.error == nil
    end

    test "handles pattern matching with complex structures" do
      code = """
      data = {:ok, %{users: [%{name: "Alice", age: 30}, %{name: "Bob", age: 25}]}}
      
      case data do
        {:ok, %{users: [%{name: first_name} | _rest]}} -> 
          "First user: " <> first_name
        {:error, reason} -> 
          "Error: " <> to_string(reason)
        _ -> 
          "Unknown format"
      end
      """
      assert {:ok, result} = CodeExecutor.execute(code)
      assert result.result == "First user: Alice"
      assert result.error == nil
    end
  end

  describe "integration tests" do
    test "executes complex safe code successfully" do
      code = """
      defmodule Calculator do
        def add(a, b), do: a + b
        def multiply(a, b), do: a * b
      end
      
      result = Calculator.add(5, 3)
      IO.puts("5 + 3 = " <> Integer.to_string(result))
      Calculator.multiply(result, 2)
      """
      
      assert {:ok, execution_result} = CodeExecutor.execute(code)
      assert execution_result.result == 16
      assert execution_result.output == "5 + 3 = 8\n"
      assert execution_result.error == nil
    end

    test "handles pattern matching and guards" do
      code = """
      defmodule PatternTest do
        def check(x) when is_integer(x) and x > 0, do: :positive
        def check(x) when is_integer(x) and x < 0, do: :negative
        def check(0), do: :zero
        def check(_), do: :not_integer
      end
      
      [
        PatternTest.check(5),
        PatternTest.check(-3),
        PatternTest.check(0),
        PatternTest.check("hello")
      ]
      """
      
      assert {:ok, result} = CodeExecutor.execute(code)
      assert result.result == [:positive, :negative, :zero, :not_integer]
      assert result.error == nil
    end

    test "handles Enum operations" do
      code = """
      [1, 2, 3, 4, 5]
      |> Enum.filter(&(&1 > 2))
      |> Enum.map(&(&1 * 2))
      |> Enum.reduce(0, &+/2)
      """
      
      assert {:ok, result} = CodeExecutor.execute(code)
      assert result.result == 24  # (3*2) + (4*2) + (5*2) = 6 + 8 + 10 = 24
      assert result.error == nil
    end
  end
end