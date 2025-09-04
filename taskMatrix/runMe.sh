#!/bin/bash
# task-menu.sh – flat version, must be sourced

(return 0 2>/dev/null) || {
  echo "⛔  Please run with:  source $0 [<dir>] [-v]"
  exit 0
}

# Parameters
search_dir="."
verbose=0
for arg in "$@"; do
  case "$arg" in
    -v) verbose=1 ;;
    *)  [[ -d "$arg" ]] && search_dir="$arg" ;;
  esac
done

# Collect tasks
task_entries=()
while IFS= read -r file; do
  rel_path=$(realpath --relative-to="$search_dir" "$file")
  rel_path=${rel_path%.task}
  [[ "$rel_path" == "." ]] && rel_path=$(basename "$file" .task)

  first_line=$(grep -v '^#' "$file" | head -n1 2>/dev/null)
  if [[ -n "$first_line" && "$first_line" == *"|"* ]]; then
    IFS='|' read -r name desc _ <<< "$first_line"
    label=$(printf '%s\t%s : %s' "$rel_path" "$name" "$desc")
  else
    label=$rel_path
  fi
  task_entries+=("${file}|||${label}")
done < <(find "$search_dir" -type f -name '*.task' | sort)

[[ ${#task_entries[@]} -eq 0 ]] && return 1

# Select task
selected=$(for e in "${task_entries[@]}"; do printf '%s\n' "${e#*|||}"; done | \
  fzf --height=60% --layout=reverse --border \
      --prompt='🕹  Enter=Run | Tab=Sub | ^E=Edit | space=Less | ^A=ls ▶ ' \
      --expect=enter,tab,ctrl-e,ctrl-l,space,ctrl-a \
      --header='========================================================' \
      --preview-window='right:50%:wrap' \
      --preview='
        label=$(echo {} | cut -f1)
        find "'"$search_dir"'" -type f -name "*.task" | while read f; do
          rel=$(realpath --relative-to="'"$search_dir"'" "$f")
          rel=${rel%.task}
          [[ "$rel" == "." ]] && rel=$(basename "$f" .task)
          [[ "$rel" == "$label" ]] || continue
          echo "─ Notes:"
          grep -v "^#" "$f" | tail -n +2 | grep -v "^\^"
          echo
          subs=$(grep "^\^" "$f")
          if [[ -n $subs ]]; then
            echo "─ Subtasks:"
            echo "$subs" | while IFS="|" read -r tag desc _; do
              printf "  └─ %-10s : %s\n" "${tag#^}" "$desc"
            done
          else
            echo "─ Subtasks: None"
          fi
          exit
        done
      ')

key=$(head -n1 <<< "$selected")
line=$(tail -n1 <<< "$selected")
[[ -z $line ]] && return 0

# Find the selected file
task_file=""
for e in "${task_entries[@]}"; do
  [[ ${e#*|||} == "$line" ]] && { task_file=${e%%|||*}; break; }
done
[[ -z $task_file ]] && return 1

# Handle input
case $key in
  ctrl-e) "${EDITOR:-vi}" "$task_file"; source "$0" "$@" ;;
  ctrl-l|space) less "$task_file"; source "$0" "$@" ;;
  ctrl-a) cd "$(dirname "$task_file")" && clear && ls ;;
  tab)
    subtasks=()
    while IFS= read -r l; do
      [[ $l == \^* ]] || continue
      IFS='|' read -r tag desc _ <<< "${l#^}"
      subtasks+=( "${tag} : ${desc}" )
    done < "$task_file"
    [[ ${#subtasks[@]} -eq 0 ]] && return 1
    chosen_sub=$(printf '%s\n' "${subtasks[@]}" | fzf --height=40% --layout=reverse --border --prompt='Subtasks > ' --bind 'esc:abort' --no-info)
    [[ -z $chosen_sub ]] && return 0
    sub_name=${chosen_sub%% :*}
    sub_cmd=$(grep "^\^${sub_name}|" "$task_file" | cut -d'|' -f3)
    eval "$sub_cmd"
    ;;
  enter)
    main_line=$(grep -v '^#' "$task_file" | head -n1)
    if [[ $main_line != *"|"* ]]; then
      "${EDITOR:-vi}" "$task_file"
      source "$0" "$@"
      return
    fi
    IFS='|' read -r main_name _ main_cmd <<< "$main_line"
    eval "$main_cmd"
    ;;
esac

