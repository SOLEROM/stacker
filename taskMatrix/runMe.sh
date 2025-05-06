#!/bin/bash

function run_task_menu() {
  local search_dir="${1:-.}"
  task_entries=()

  while IFS= read -r file; do
    dir_name=$(basename "$(dirname "$file")")
    base_name=$(basename "$file" .task)
    first_line=$(grep -v '^#' "$file" | head -n1)

    if [[ "$first_line" == *"|"* ]]; then
      label="${dir_name}/${base_name}"
      task_entries+=("${file}|||${label}")
    fi
  done < <(find "$search_dir" -type f -name "*.task" | sort)

  [[ ${#task_entries[@]} -eq 0 ]] && echo "❌ No valid .task files found in: $search_dir" && return 1

  selected=$(for entry in "${task_entries[@]}"; do
    echo "${entry#*|||}"
  done | \
  fzf --height=60% --layout=reverse --border \
      --prompt="🕹  Enter=Run | Tab=Sub | ^E=Edit | Space=Less ▶ " \
      --expect=enter,tab,ctrl-e,ctrl-l,space \
      --header="========================================================" \
      --preview-window=right:50%:wrap \
      --preview='
        label=$(echo {} | sed "s/ :.*//")
        find '"$search_dir"' -type f -name "*.task" | while read f; do
          dir=$(basename "$(dirname "$f")")
          base=$(basename "$f" .task)
          if [ "$dir/$base" = "$label" ]; then
            echo "─ Notes:"
            grep -v "^#" "$f" | tail -n +2 | grep -v "^\\^"
            echo ""
            subtasks=$(grep "^\\^" "$f")
            if [ -n "$subtasks" ]; then
              echo "─ Subtasks:"
              echo "$subtasks" | while IFS="|" read -r tag desc _; do
                tag=${tag#^}
                printf "  └─ %-10s : %s\n" "$tag" "$desc"
              done
            else
              echo "─ Subtasks: None"
            fi
            exit
          fi
        done
      ')

  key=$(head -n1 <<< "$selected")
  line=$(tail -n1 <<< "$selected")
  [[ -z "$line" ]] && return 0

  label_key=$(echo "$line" | sed 's/ :.*//')
  task_file=""

  for entry in "${task_entries[@]}"; do
    path="${entry%%|||*}"
    label="${entry#*|||}"
    [[ "$label" == "$line" ]] && task_file="$path" && break
  done

  [[ -z "$task_file" ]] && echo "❌ Could not find task file." && return 1

  # ✏️ Edit mode
  if [[ "$key" == "ctrl-e" ]]; then
    echo "✏️ Opening editor for: $task_file"
    "${EDITOR:-vi}" "$task_file"
    echo "🔁 Relaunching task menu..."
    run_task_menu "$search_dir"
    return 0
  fi

  # 📄 View mode with less (Ctrl-L or Space)
  if [[ "$key" == "ctrl-l" || "$key" == "space" ]]; then
    echo "📄 Viewing task file: $task_file"
    less "$task_file"
    echo "🔁 Relaunching task menu..."
    run_task_menu "$search_dir"
    return 0
  fi

  # Main task execution
  main_line=$(grep -v '^#' "$task_file" | head -n1)
  IFS='|' read -r main_name _ main_cmd <<< "$main_line"

  if [[ "$key" == "tab" ]]; then
    subtasks=()
    while IFS= read -r l; do
      [[ "$l" =~ ^\^ ]] || continue
      l="${l#^}"
      IFS='|' read -r sname sdesc _ <<< "$l"
      subtasks+=("${sname} : ${sdesc}")
    done < "$task_file"

    if [[ ${#subtasks[@]} -eq 0 ]]; then
      echo "⚠️ No subtasks for $main_name"
      return 1
    fi

    selected_sub=$(printf "%s\n" "${subtasks[@]}" | \
      fzf --height=40% --layout=reverse --border \
          --prompt="Subtasks for $main_name > " \
          --bind "esc:abort" --no-info)

    [[ -z "$selected_sub" ]] && return 0

    sub_name="${selected_sub%% :*}"
    sub_cmd=$(grep "^\\^$sub_name|" "$task_file" | cut -d'|' -f3)

    echo "▶ Running subtask: $sub_name"
    eval "$sub_cmd"
    return 0
  fi

  if [[ "$key" == "enter" ]]; then
    echo "▶ Running task: $main_name"
    eval "$main_cmd"
    return 0
  fi

  return 0
}

# 🚀 Auto-run when sourced
run_task_menu "$1"

