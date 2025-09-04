#!/bin/bash

(return 0 2>/dev/null) || {
  echo "❌ Please source this script: source ./demo_final.sh"
  exit 0
}

# Find task files
task_files=$(find . -maxdepth 1 -type f -name "tasks_*" | sed 's|^\./||')
[[ -z "$task_files" ]] && echo "❌ No task files found." && return 1

# Select a task file
selected_file=$(echo "$task_files" | fzf --height=40% --layout=reverse --prompt="Select a project: ")
[[ -z "$selected_file" ]] && return 1

# Build list of main tasks
task_list=$(awk -F '|' '/^[^#\t -]/ {print $1 " : " $2}' "$selected_file")
task_list="📝 Edit this project file"$'\n'"$task_list"

# Main fzf loop
while true; do
  selected=$(echo "$task_list" | \
    fzf \
      --height=60% \
      --layout=reverse \
      --border \
      --prompt="Main Tasks > " \
      --preview-window=right:50%:wrap \
      --expect=enter,tab \
      --preview="
        task=\$(echo {} | awk -F ' : ' '{print \$1}')
        if [[ \"\$task\" == \"📝 Edit this project file\" ]]; then
          echo 'Open the task file in vi'
        else
          awk -F '|' -v name=\"\$task\" '
            BEGIN {found=0}
            \$1 == name {found=1; next}
            found && \$0 ~ /^\t/ {
              sub(/^\t/, \"\");
              printf \"  → %s : %s\\n\", \$1, \$2
            }
            found && \$0 !~ /^\t/ {exit}
          ' \"$selected_file\"
        fi")

  key=$(head -n1 <<< "$selected")
  line=$(tail -n1 <<< "$selected")
  [[ -z "$line" ]] && return 1

  task_name=$(awk -F ' : ' '{print $1}' <<< "$line")

  # Edit file
  if [[ "$task_name" == "📝 Edit this project file" ]]; then
    vi "$selected_file"
    continue
  fi

  # Run main task
  if [[ "$key" == "enter" ]]; then
    command=$(awk -F '|' -v name="$task_name" '$1 == name && $0 !~ /^(\t|#)/ {print $3}' "$selected_file")
    echo "▶ Running main task: $task_name"
    eval "$command"
    return 0
  fi

  # Run subtask
  if [[ "$key" == "tab" ]]; then
    # Extract subtasks
    subtasks=$(awk -F '|' -v name="$task_name" '
      BEGIN {found=0}
      $1 == name {found=1; next}
      found && $0 ~ /^\t/ {
        sub(/^\t/, "");
        print $1 " : " $2
      }
      found && $0 !~ /^\t/ {exit}
    ' "$selected_file")

    [[ -z "$subtasks" ]] && echo "⚠️ No subtasks for $task_name" && continue

    selected_sub=$(echo "$subtasks" | \
      fzf \
        --height=40% \
        --layout=reverse \
        --border \
        --prompt="Subtasks for $task_name > " \
        --bind "esc:abort" \
        --no-info)

    [[ -z "$selected_sub" ]] && continue

    sub_name=$(awk -F ' : ' '{print $1}' <<< "$selected_sub")
    sub_command=$(awk -F '|' -v name="$sub_name" '$1 == name && $0 ~ /^\t/ {print $3}' "$selected_file")

    echo "▶ Running subtask: $sub_name"
    eval "$sub_command"
    return 0
  fi
done

