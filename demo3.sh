#!/bin/bash

# Define the task file in the current directory
TASK_FILE="./.taskit"

# Check if the file exists in the current directory
if [[ ! -f "$TASK_FILE" ]]; then
  echo "Task file not found in the current directory ($TASK_FILE)."
  exit 1
fi

# Function to select the top-level project
select_project() {
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
}

# Function to select subtasks
select_subtask() {
  # Filter subtasks related to the selected project
  subtasks=$(awk -F '|' -v proj="$project_name" '
    BEGIN {found=0} 
    /^[^ -]/ {if (found) exit} 
    $1 ~ proj {found=1} 
    found && $1 ~ /^- / {print $1}' "$TASK_FILE")

  # If subtasks exist, let the user select a subtask with ESC bound to return
  if [[ -n "$subtasks" ]]; then
    selected_subtask=$(echo "$subtasks" | \
      fzf --no-info --height 40% --layout=reverse --border --prompt="Select a subtask or press ESC to return to the main menu: " \
      --preview="grep ^{} $TASK_FILE | awk -F '|' '{print \"Description: \" \$2 \"\nCommand: \" \$3}'" \
      --bind "esc:abort")

    # If ESC was pressed (abort)
    if [[ -z "$selected_subtask" ]]; then
      return 1  # ESC key was pressed, return to main menu
    fi

    # If a subtask was selected, extract and run its command
    subtask_name=$(echo "$selected_subtask")
    subtask_command=$(grep "^$subtask_name" "$TASK_FILE" | awk -F '|' '{print $3}')
    
    echo "Running subtask: $subtask_name"
    eval "$subtask_command"
    exit 0
  fi
}

# Main loop to handle project and subtask selection
while true; do
  # Select the top-level project
  select_project

  # Select subtasks or return to the main project menu if ESC is pressed
  if ! select_subtask; then
    continue  # Restart the loop to return to project selection
  fi

  # If no subtasks exist, run the main task
  echo "Running main task: $project_name"
  eval "$main_command"
  exit 0
done

