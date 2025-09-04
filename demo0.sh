#!/bin/bash

# Add this near the top of your script
(return 0 2>/dev/null) || {
  echo "Please run that script by ...source this script..."
  exit 1
}

# Allow user to pass task file as an argument
TASK_FILE="${1:-./.taskit}"


# Check if the file exists
if [[ ! -f "$TASK_FILE" ]]; then
  echo "Task file not found in the current directory ($TASK_FILE)."
  exit 1
fi

# Display only main tasks (lines that do NOT start with dash or space)
# Show: <task name> : <description>
selected=$(awk -F '|' '/^[^ -]/ {print $1 " : " $2}' "$TASK_FILE" | \
  fzf --height 40% --layout=reverse --prompt="Select a task: ")

# Exit if no selection
if [[ -z "$selected" ]]; then
  echo "No task selected."
  return 0
fi

# Extract task name from selection (before ' : ')
task_name=$(echo "$selected" | awk -F ' : ' '{print $1}')

# Lookup and extract the command (column 3) from the task file
command=$(awk -F '|' -v name="$task_name" '$1 == name {print $3}' "$TASK_FILE")

# Run the command
#echo "Running task: $task_name"
eval "$command"


# After running, if we’re now in a different directory that has a .taskit, re-run the selector
if [[ -f ".taskit" ]]; then
  echo "📂 Found new .taskit in $(pwd), relaunching task selector..."
  source "$BASH_SOURCE" $(pwd)/.taskit
fi

