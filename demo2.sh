#!/bin/bash

# Define the task file in the current directory
TASK_FILE="./.taskit"

# Check if the file exists in the current directory
if [[ ! -f "$TASK_FILE" ]]; then
  echo "Task file not found in the current directory ($TASK_FILE)."
  exit 1
fi

# First fzf: Select the top-level project (without subtasks)
selected_project=$(awk -F '|' '/^[^ -]/ {print $1}' "$TASK_FILE" | \
  fzf --no-info --height 40% --layout=reverse --border --prompt="Select a project: " \
  --preview="grep ^{} $TASK_FILE | awk -F '|' '{print \"Description: \" \$2 \"\nCommand: \" \$3}'")

# Exit if no selection was made
if [[ -z "$selected_project" ]]; then
  echo "No project selected."
  exit 0
fi

# Extract the project name
project_name=$(echo "$selected_project")

# Get the command for the main project task
main_command=$(grep "^$project_name" "$TASK_FILE" | awk -F '|' '{print $3}')

# Second fzf: Check for and list **only** subtasks related to the selected project
# Filter subtasks that appear after the project, but stop at the next project line
subtasks=$(awk -F '|' -v proj="$project_name" '
  BEGIN {found=0} 
  /^[^ -]/ {if (found) exit} 
  $1 ~ proj {found=1} 
  found && $1 ~ /^- / {print $1}' "$TASK_FILE")

# If subtasks exist, let the user select a subtask with a preview
if [[ -n "$subtasks" ]]; then
  selected_subtask=$(echo "$subtasks" | \
    fzf --no-info --height 40% --layout=reverse --border --prompt="Select a subtask or press ESC to run the main task: " \
    --preview="grep ^{} $TASK_FILE | awk -F '|' '{print \"Description: \" \$2 \"\nCommand: \" \$3}'")

  # If a subtask is selected, extract and run its command
  if [[ -n "$selected_subtask" ]]; then
    subtask_name=$(echo "$selected_subtask")
    subtask_command=$(grep "^$subtask_name" "$TASK_FILE" | awk -F '|' '{print $3}')
    
    echo "Running subtask: $subtask_name"
    eval "$subtask_command"
    exit 0
  fi
fi

# If no subtask was selected or no subtasks exist, run the main task
echo "Running main task: $project_name"
eval "$main_command"

