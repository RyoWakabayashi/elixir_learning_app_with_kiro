# Design Document

## Overview

ElixirとPhoenix LiveViewを学習するためのインタラクティブWebアプリケーション。Phoenix LiveViewを使用してリアルタイムなユーザーインターフェースを提供し、Elixirの`Code.eval_string/2`を使用してコードを動的に実行する。学習者の進捗はEctoを使用してPostgreSQLデータベースに保存し、レッスンコンテンツはアプリケーション内で管理する。

## Architecture

### High-Level Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Web Browser   │◄──►│ Phoenix LiveView│◄──►│   Code Executor │
│                 │    │                 │    │                 │
│ - Code Editor   │    │ - Real-time UI  │    │ - Safe Sandbox  │
│ - Progress View │    │ - State Mgmt    │    │ - Result Capture│
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │   Database      │
                       │                 │
                       │ - User Progress │
                       │ - Lesson Data   │
                       └─────────────────┘
```

### Technology Stack

- **Frontend**: Phoenix LiveView with Alpine.js for enhanced interactivity
- **Backend**: Phoenix Framework with Elixir
- **Database**: PostgreSQL with Ecto
- **Code Editor**: Monaco Editor (VS Code editor) embedded in LiveView
- **Code Execution**: Supervised processes with timeouts and resource limits
- **Real-time**: Phoenix PubSub for live updates

## Components and Interfaces

### 1. LiveView Components

#### LessonLive
- **Purpose**: Main lesson interface with code editor and execution
- **State**: Current lesson, user code, execution results, progress
- **Events**: 
  - `execute_code` - Run user's code
  - `submit_solution` - Check solution against expected output
  - `reset_code` - Reset to lesson template
  - `next_lesson` - Navigate to next lesson

#### ProgressLive  
- **Purpose**: Display learning progress and lesson navigation
- **State**: User progress, available lessons, completion status
- **Events**:
  - `select_lesson` - Navigate to specific lesson
  - `refresh_progress` - Update progress display

#### CodeEditor Component
- **Purpose**: Reusable code editor with syntax highlighting
- **Props**: Initial code, language mode, read-only flag
- **Events**: Code change notifications

### 2. Core Modules

#### CodeExecutor
```elixir
defmodule LearningApp.CodeExecutor do
  @moduledoc "Safe code execution with sandboxing"
  
  def execute(code, timeout \\ 5000)
  def validate_safety(code)
  def capture_output(fun)
end
```

#### LessonManager
```elixir
defmodule LearningApp.LessonManager do
  @moduledoc "Lesson content and progression logic"
  
  def get_lesson(id)
  def get_available_lessons(user_id)
  def check_solution(lesson_id, code, output)
  def unlock_next_lesson(user_id, lesson_id)
end
```

#### ProgressTracker
```elixir
defmodule LearningApp.ProgressTracker do
  @moduledoc "User progress tracking"
  
  def get_user_progress(user_id)
  def mark_lesson_completed(user_id, lesson_id)
  def update_lesson_attempt(user_id, lesson_id, code, result)
end
```

### 3. Database Schema

#### Users Table
```sql
CREATE TABLE users (
  id SERIAL PRIMARY KEY,
  email VARCHAR(255) UNIQUE NOT NULL,
  name VARCHAR(255) NOT NULL,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW()
);
```

#### Lessons Table
```sql
CREATE TABLE lessons (
  id SERIAL PRIMARY KEY,
  title VARCHAR(255) NOT NULL,
  description TEXT,
  instructions TEXT NOT NULL,
  template_code TEXT,
  expected_output TEXT,
  test_cases JSONB,
  order_index INTEGER NOT NULL,
  difficulty VARCHAR(50),
  created_at TIMESTAMP DEFAULT NOW()
);
```

#### User Progress Table
```sql
CREATE TABLE user_progress (
  id SERIAL PRIMARY KEY,
  user_id INTEGER REFERENCES users(id),
  lesson_id INTEGER REFERENCES lessons(id),
  status VARCHAR(50) DEFAULT 'not_started', -- not_started, in_progress, completed
  attempts INTEGER DEFAULT 0,
  last_code TEXT,
  completed_at TIMESTAMP,
  created_at TIMESTAMP DEFAULT NOW(),
  updated_at TIMESTAMP DEFAULT NOW(),
  UNIQUE(user_id, lesson_id)
);
```

## Data Models

### Lesson Structure
```elixir
defmodule LearningApp.Content.Lesson do
  use Ecto.Schema
  
  schema "lessons" do
    field :title, :string
    field :description, :string
    field :instructions, :string
    field :template_code, :string
    field :expected_output, :string
    field :test_cases, :map
    field :order_index, :integer
    field :difficulty, :string
    
    has_many :user_progress, LearningApp.Accounts.UserProgress
    
    timestamps()
  end
end
```

### User Progress Model
```elixir
defmodule LearningApp.Accounts.UserProgress do
  use Ecto.Schema
  
  schema "user_progress" do
    field :status, :string, default: "not_started"
    field :attempts, :integer, default: 0
    field :last_code, :string
    field :completed_at, :naive_datetime
    
    belongs_to :user, LearningApp.Accounts.User
    belongs_to :lesson, LearningApp.Content.Lesson
    
    timestamps()
  end
end
```

## Error Handling

### Code Execution Safety
1. **Timeout Protection**: All code execution limited to 5 seconds
2. **Process Isolation**: Each execution runs in supervised temporary process
3. **Resource Limits**: Memory and CPU usage monitoring
4. **Dangerous Code Detection**: Block file system access, network calls, system commands
5. **Exception Handling**: Capture and display runtime errors safely

### User Experience
1. **Graceful Degradation**: Fallback UI when LiveView connection fails
2. **Error Messages**: Clear, educational error messages for common mistakes
3. **Progress Recovery**: Automatic progress saving and restoration
4. **Network Issues**: Retry mechanisms for failed requests

## Testing Strategy

### Unit Tests
- **CodeExecutor**: Test safe execution, timeout handling, output capture
- **LessonManager**: Test lesson retrieval, solution validation, progression logic
- **ProgressTracker**: Test progress updates, completion tracking

### Integration Tests
- **LiveView Tests**: Test user interactions, state management, real-time updates
- **Database Tests**: Test data persistence, user progress tracking
- **End-to-End Tests**: Test complete lesson flow from start to completion

### Security Tests
- **Code Injection**: Test prevention of malicious code execution
- **Resource Exhaustion**: Test timeout and resource limit enforcement
- **Data Validation**: Test input sanitization and validation

### Performance Tests
- **Concurrent Users**: Test system behavior with multiple simultaneous users
- **Code Execution Load**: Test performance with complex code execution
- **Database Performance**: Test query performance with large datasets

## Implementation Phases

### Phase 1: Core Infrastructure
- Phoenix application setup with LiveView
- Database schema and migrations
- Basic code execution engine with safety measures
- Simple lesson data structure

### Phase 2: User Interface
- Code editor integration with Monaco Editor
- Basic lesson display and navigation
- Progress tracking UI
- User authentication

### Phase 3: Advanced Features
- Real-time progress updates
- Enhanced error handling and user feedback
- Lesson content management
- Performance optimizations

### Phase 4: Content and Polish
- Comprehensive lesson content creation
- UI/UX improvements
- Advanced testing and validation
- Documentation and deployment