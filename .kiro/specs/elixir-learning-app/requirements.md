# Requirements Document

## Introduction

ElixirとPhoenix LiveViewを学習するためのインタラクティブなWebアプリケーション。Livebookのようにコードを書いて実行でき、課題に対して正しい実装ができているかを自動判定してレッスンを進めるシステム。学習者が段階的にElixirとPhoenix LiveViewのスキルを身につけられるプラットフォームを提供する。

## Requirements

### Requirement 1

**User Story:** As a learner, I want to write and execute Elixir code in a web browser, so that I can practice programming without setting up a local development environment.

#### Acceptance Criteria

1. WHEN a learner opens a lesson THEN the system SHALL display a code editor interface
2. WHEN a learner writes Elixir code in the editor THEN the system SHALL provide syntax highlighting
3. WHEN a learner clicks the execute button THEN the system SHALL run the code and display the output
4. IF the code execution fails THEN the system SHALL display error messages clearly
5. WHEN code is executed THEN the system SHALL capture both stdout and return values

### Requirement 2

**User Story:** As a learner, I want to receive immediate feedback on my solutions, so that I can understand whether my implementation is correct.

#### Acceptance Criteria

1. WHEN a learner submits code for a lesson THEN the system SHALL compare the output with expected results
2. IF the output matches expectations THEN the system SHALL mark the lesson as passed
3. IF the output does not match THEN the system SHALL show what was expected vs what was received
4. WHEN a lesson is passed THEN the system SHALL unlock the next lesson
5. WHEN a lesson is failed THEN the system SHALL allow the learner to retry

### Requirement 3

**User Story:** As a learner, I want to progress through structured lessons, so that I can build my knowledge systematically.

#### Acceptance Criteria

1. WHEN a learner first accesses the app THEN the system SHALL display available lessons in order
2. WHEN a lesson is not yet unlocked THEN the system SHALL prevent access to that lesson
3. WHEN a learner completes a lesson THEN the system SHALL update their progress
4. WHEN a learner returns to the app THEN the system SHALL remember their progress
5. WHEN viewing lessons THEN the system SHALL show completion status for each lesson

### Requirement 4

**User Story:** As a learner, I want to see lesson instructions and examples, so that I understand what I need to implement.

#### Acceptance Criteria

1. WHEN a learner opens a lesson THEN the system SHALL display clear instructions
2. WHEN instructions are provided THEN the system SHALL include example inputs and expected outputs
3. WHEN a lesson has multiple parts THEN the system SHALL break down requirements clearly
4. IF a lesson builds on previous concepts THEN the system SHALL reference relevant prior lessons
5. WHEN examples are shown THEN the system SHALL format them clearly and readably

### Requirement 5

**User Story:** As a learner, I want the code execution to be safe and isolated, so that I can experiment without security concerns.

#### Acceptance Criteria

1. WHEN code is executed THEN the system SHALL run it in a sandboxed environment
2. WHEN code execution takes too long THEN the system SHALL timeout and stop execution
3. WHEN code attempts dangerous operations THEN the system SHALL prevent execution
4. WHEN multiple learners use the system THEN their code executions SHALL be isolated from each other
5. WHEN code is executed THEN the system SHALL limit resource usage (memory, CPU)

### Requirement 6

**User Story:** As a learner, I want to track my learning progress, so that I can see how much I've accomplished.

#### Acceptance Criteria

1. WHEN a learner logs in THEN the system SHALL display their overall progress
2. WHEN lessons are completed THEN the system SHALL update completion statistics
3. WHEN viewing progress THEN the system SHALL show which lessons are completed, in progress, or locked
4. WHEN a learner wants to review THEN the system SHALL allow access to previously completed lessons
5. WHEN progress is displayed THEN the system SHALL show percentage completion and time spent

### Requirement 7

**User Story:** As a learner, I want real-time updates and feedback, so that the learning experience feels responsive and engaging.

#### Acceptance Criteria

1. WHEN code is being executed THEN the system SHALL show execution status in real-time
2. WHEN other learners are active THEN the system SHALL update lesson completion counts live
3. WHEN a lesson is completed THEN the system SHALL immediately unlock the next lesson without page refresh
4. WHEN typing code THEN the system SHALL provide real-time syntax validation
5. WHEN execution completes THEN the system SHALL update the UI immediately with results