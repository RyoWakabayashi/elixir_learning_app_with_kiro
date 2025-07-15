# Script for populating the database. You can run it as:
#
#     mix run priv/repo/seeds.exs
#
# Inside the script, you can read and write to any of your
# repositories directly:
#
#     ElixirLearningApp.Repo.insert!(%ElixirLearningApp.SomeSchema{})
#
# We recommend using the bang functions (`insert!`, `update!`
# and so on) as they will fail if something goes wrong.

alias ElixirLearningApp.Repo
alias ElixirLearningApp.Content.Lesson
alias ElixirLearningApp.Accounts.User

# Clear existing data (for development)
Repo.delete_all(Lesson)
Repo.delete_all(User)

# Create sample user for testing
sample_user = %User{
  name: "Sample User",
  email: "sample@example.com"
}
|> Repo.insert!()

IO.puts("Created sample user: #{sample_user.email}")

# Lesson 1: Basic Arithmetic
lesson1 = %Lesson{
  title: "Basic Arithmetic",
  description: "Learn basic arithmetic operations in Elixir",
  instructions: """
  Welcome to your first Elixir lesson! Let's start with basic arithmetic.
  
  In Elixir, you can perform arithmetic operations just like in math:
  - Addition: `+`
  - Subtraction: `-`
  - Multiplication: `*`
  - Division: `/`
  
  **Your task:** Calculate the result of 15 + 27
  
  Type your answer in the code editor and click "Run Code" to see the result.
  """,
  template_code: "# Calculate 15 + 27\n",
  expected_output: "42",
  order_index: 1,
  difficulty: "beginner"
}
|> Repo.insert!()

# Lesson 2: Variables and Pattern Matching
lesson2 = %Lesson{
  title: "Variables and Assignment",
  description: "Learn how to work with variables in Elixir",
  instructions: """
  In Elixir, you can assign values to variables using the `=` operator.
  
  Example:
  ```elixir
  name = "Alice"
  age = 25
  ```
  
  **Your task:** Create a variable called `result` and assign it the value of 8 * 7.
  Then return the `result` variable.
  
  Hint: The last line of your code should be just `result` to return its value.
  """,
  template_code: "# Create a variable called 'result' and assign it 8 * 7\n# Then return the result\n",
  expected_output: "56",
  order_index: 2,
  difficulty: "beginner"
}
|> Repo.insert!()

# Lesson 3: Strings and String Interpolation
lesson3 = %Lesson{
  title: "Working with Strings",
  description: "Learn string operations and interpolation",
  instructions: """
  Strings in Elixir are enclosed in double quotes. You can combine strings using interpolation.
  
  String interpolation uses `#{}` inside double quotes:
  ```elixir
  name = "World"
  greeting = "Hello, \#{name}!"
  ```
  
  **Your task:** Create a variable `name` with the value "Elixir", then create a greeting
  that says "Hello, Elixir!" using string interpolation. Return the greeting.
  """,
  template_code: "# Create a name variable and a greeting using interpolation\n",
  expected_output: "\"Hello, Elixir!\"",
  order_index: 3,
  difficulty: "beginner"
}
|> Repo.insert!()

# Lesson 4: Lists and Basic Operations
lesson4 = %Lesson{
  title: "Introduction to Lists",
  description: "Learn how to work with lists in Elixir",
  instructions: """
  Lists in Elixir are collections of elements enclosed in square brackets.
  
  Examples:
  ```elixir
  numbers = [1, 2, 3, 4, 5]
  fruits = ["apple", "banana", "orange"]
  ```
  
  You can get the length of a list using `length/1`:
  ```elixir
  length([1, 2, 3])  # Returns 3
  ```
  
  **Your task:** Create a list with the numbers 10, 20, 30, 40, 50 and return its length.
  """,
  template_code: "# Create a list with numbers 10, 20, 30, 40, 50\n# Return the length of the list\n",
  expected_output: "5",
  order_index: 4,
  difficulty: "beginner"
}
|> Repo.insert!()

# Lesson 5: Functions and Pattern Matching
lesson5 = %Lesson{
  title: "Simple Functions",
  description: "Learn to create and use functions",
  instructions: """
  Functions in Elixir are defined using `def` inside modules, but you can also create
  anonymous functions using `fn`.
  
  Anonymous function example:
  ```elixir
  add = fn a, b -> a + b end
  add.(5, 3)  # Returns 8
  ```
  
  **Your task:** Create an anonymous function that multiplies two numbers together.
  Then use it to calculate 6 * 9.
  """,
  template_code: "# Create an anonymous function that multiplies two numbers\n# Use it to calculate 6 * 9\n",
  expected_output: "54",
  order_index: 5,
  difficulty: "intermediate"
}
|> Repo.insert!()

# Lesson 6: Atoms and Tuples
lesson6 = %Lesson{
  title: "Atoms and Tuples",
  description: "Learn about atoms and tuples in Elixir",
  instructions: """
  Atoms are constants whose name is their value. They start with a colon:
  ```elixir
  :ok
  :error
  :hello
  ```
  
  Tuples are collections of elements enclosed in curly braces:
  ```elixir
  {1, 2, 3}
  {:ok, "success"}
  {:error, "something went wrong"}
  ```
  
  **Your task:** Create a tuple with the atom `:success` and the string "Well done!".
  """,
  template_code: "# Create a tuple with :success and \"Well done!\"\n",
  expected_output: "{:success, \"Well done!\"}",
  order_index: 6,
  difficulty: "beginner"
}
|> Repo.insert!()

# Lesson 7: Maps and Key-Value Access
lesson7 = %Lesson{
  title: "Working with Maps",
  description: "Learn to create and access maps",
  instructions: """
  Maps are key-value data structures in Elixir:
  ```elixir
  person = %{name: "Alice", age: 30}
  person[:name]  # Returns "Alice"
  person.name    # Also returns "Alice" (for atom keys)
  ```
  
  **Your task:** Create a map representing a book with keys `:title` and `:author`.
  Set the title to "Elixir in Action" and author to "Saša Jurić".
  Then access and return the title.
  """,
  template_code: "# Create a book map and return the title\n",
  expected_output: "\"Elixir in Action\"",
  order_index: 7,
  difficulty: "intermediate"
}
|> Repo.insert!()

# Lesson 8: Conditional Logic with case
lesson8 = %Lesson{
  title: "Conditional Logic",
  description: "Learn to use case statements for conditional logic",
  instructions: """
  The `case` statement allows you to match against different patterns:
  ```elixir
  case value do
    1 -> "one"
    2 -> "two"
    _ -> "other"
  end
  ```
  
  **Your task:** Create a variable `number` with the value 3, then use a case statement
  to return "three" when the number is 3, and "other" for any other value.
  """,
  template_code: "# Create a number variable and use case to return the appropriate string\n",
  expected_output: "\"three\"",
  order_index: 8,
  difficulty: "intermediate"
}
|> Repo.insert!()

# Lesson 9: List Operations with Enum
lesson9 = %Lesson{
  title: "List Operations with Enum",
  description: "Learn to use Enum functions for list operations",
  instructions: """
  The Enum module provides many useful functions for working with lists:
  ```elixir
  Enum.sum([1, 2, 3, 4])     # Returns 10
  Enum.map([1, 2, 3], fn x -> x * 2 end)  # Returns [2, 4, 6]
  ```
  
  **Your task:** Use `Enum.sum/1` to calculate the sum of the list [5, 10, 15, 20].
  """,
  template_code: "# Use Enum.sum to calculate the sum of [5, 10, 15, 20]\n",
  expected_output: "50",
  order_index: 9,
  difficulty: "intermediate"
}
|> Repo.insert!()

# Lesson 10: Pipe Operator
lesson10 = %Lesson{
  title: "The Pipe Operator",
  description: "Learn to use the pipe operator for cleaner code",
  instructions: """
  The pipe operator `|>` passes the result of one function as the first argument to the next:
  ```elixir
  [1, 2, 3, 4]
  |> Enum.map(fn x -> x * 2 end)
  |> Enum.sum()
  # Same as: Enum.sum(Enum.map([1, 2, 3, 4], fn x -> x * 2 end))
  ```
  
  **Your task:** Use the pipe operator to:
  1. Start with the list [1, 2, 3, 4, 5]
  2. Double each number using `Enum.map`
  3. Calculate the sum using `Enum.sum`
  """,
  template_code: "# Use pipe operator to double numbers and sum them\n",
  expected_output: "30",
  order_index: 10,
  difficulty: "intermediate"
}
|> Repo.insert!()

IO.puts("Created #{Repo.aggregate(Lesson, :count, :id)} lessons:")
Repo.all(Lesson)
|> Enum.each(fn lesson ->
  IO.puts("  #{lesson.order_index}. #{lesson.title} (#{lesson.difficulty})")
end)

IO.puts("\nSeed data created successfully!")
IO.puts("Run 'mix run priv/repo/seeds.exs' to recreate this data.")
