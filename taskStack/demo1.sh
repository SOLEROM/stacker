#!/bin/bash
# demo1.sh — multi-project task navigator
# usage: source demo1.sh [projects_file]
#
# Keys: ← / → (or ctrl-h/ctrl-l)  navigate projects
#       ctrl-a                      toggle global search across all projects
#       Esc                         quit

(return 0 2>/dev/null) || {
  printf '\n  Usage: source %s [projects_file]\n\n' "$0"; exit 0
}

# bash=0-indexed arrays, zsh=1-indexed — detect base so we never touch setopts
[[ -n "$ZSH_VERSION" ]] && _D1_BASE=1 || _D1_BASE=0

SCRIPT_PATH="$(readlink -f "$0")"

# ── resolve projects file ─────────────────────────────────────────────────────

if [[ -n "$1" && "$1" != zle_* ]]; then
  _D1_PF="$1"
else
  _D1_PF="$(dirname "$SCRIPT_PATH")/demo1.projects"
fi

if [[ ! -f "$_D1_PF" ]]; then
  printf '\n  \033[1;31m✗\033[0m  not found: \033[33m%s\033[0m\n' "$_D1_PF"
  printf '     create a file with lines:\n'
  printf '       /path/to/.taskit | Project Name\n\n'
  unset _D1_PF _D1_BASE; return 1
fi

# ── load projects ─────────────────────────────────────────────────────────────

declare -a _D1_F _D1_L
while IFS='|' read -r _p _h; do
  _p="${_p#"${_p%%[![:space:]]*}"}"; _p="${_p%"${_p##*[![:space:]]}"}"
  _h="${_h#"${_h%%[![:space:]]*}"}"; _h="${_h%"${_h##*[![:space:]]}"}"
  [[ -z "$_p" || "$_p" == \#* ]] && continue
  _D1_F+=("$_p"); _D1_L+=("$_h")
done < "$_D1_PF"
unset _p _h _D1_PF

_D1_N=${#_D1_F[@]}
if [[ $_D1_N -eq 0 ]]; then
  printf '  \033[33m⚠\033[0m  no projects loaded\n'
  unset _D1_F _D1_L _D1_N _D1_BASE; return 1
fi

_D1_I=$_D1_BASE        # current project index (base-relative)
_D1_GLOBAL=0           # 0=per-project  1=global search
_D1_QUERY=""           # preserved across ctrl-a switches

_D1_COLOR='dark,fg:251,bg:235,hl:39,fg+:255,bg+:237,hl+:81,info:144,prompt:33,spinner:143'

# ── navigation loop ───────────────────────────────────────────────────────────

_D1_MISS=0
while true; do
  _D1_FILE="${_D1_F[$_D1_I]}"
  _D1_HL="${_D1_L[$_D1_I]}"

  if [[ $_D1_GLOBAL -eq 0 && ! -f "$_D1_FILE" ]]; then
    _D1_MISS=$(( _D1_MISS + 1 ))
    if [[ $_D1_MISS -ge $_D1_N ]]; then
      printf '  \033[1;31m✗\033[0m  no valid project files found\n'
      unset _D1_F _D1_L _D1_N _D1_I _D1_BASE _D1_COLOR _D1_FILE _D1_HL _D1_MISS _D1_GLOBAL _D1_QUERY
      return 1
    fi
    printf '  \033[33m⚠\033[0m  missing: %s — skipping\n' "$_D1_FILE"
    _D1_I=$(( ((_D1_I - _D1_BASE + 1) % _D1_N) + _D1_BASE ))
    continue
  fi
  _D1_MISS=0

  # nav bar: ← proj1 proj2 [CURRENT] proj4 →  (blue / bold-red selected)
  _D1_E=$'\033'
  if [[ $_D1_N -gt 1 ]]; then
    _D1_HDR="  ${_D1_E}[34m←${_D1_E}[0m"
    for (( _D1_J=_D1_BASE; _D1_J<_D1_N+_D1_BASE; _D1_J++ )); do
      if [[ $_D1_J -eq $_D1_I ]]; then
        _D1_HDR+=" ${_D1_E}[1;31m[${_D1_L[$_D1_J]}]${_D1_E}[0m"
      else
        _D1_HDR+=" ${_D1_E}[34m${_D1_L[$_D1_J]}${_D1_E}[0m"
      fi
    done
    _D1_HDR+="  ${_D1_E}[34m→${_D1_E}[0m"
  else
    _D1_HDR=""
  fi
  unset _D1_E _D1_J

  if [[ $_D1_GLOBAL -eq 1 ]]; then
    # ── global mode: all tasks from all projects ──────────────────────────────
    _D1_R=$(
      for (( _D1_J=_D1_BASE; _D1_J<_D1_N+_D1_BASE; _D1_J++ )); do
        [[ ! -f "${_D1_F[$_D1_J]}" ]] && continue
        awk -F '|' -v proj="${_D1_L[$_D1_J]}" '/^[^ -]/ {
          gsub(/^[ \t]+|[ \t]+$/, "", $1)
          gsub(/^[ \t]+|[ \t]+$/, "", $2)
          print "[" proj "]  " $1 " : " $2
        }' "${_D1_F[$_D1_J]}"
      done | \
      fzf --ansi \
          --height=55% \
          --layout=reverse \
          --border \
          --cycle \
          --no-info \
          --query="$_D1_QUERY" \
          --print-query \
          --prompt=" globalFilter ❯ " \
          --header="$_D1_HDR" \
          --color="$_D1_COLOR" \
          --expect="ctrl-a,left,right,ctrl-h,ctrl-l"
    )
  else
    # ── per-project mode ──────────────────────────────────────────────────────
    _D1_R=$(
      awk -F '|' '/^[^ -]/ {
          gsub(/^[ \t]+|[ \t]+$/, "", $1)
          gsub(/^[ \t]+|[ \t]+$/, "", $2)
          print $1 " : " $2
        }' "$_D1_FILE" | \
      fzf --ansi \
          --height=55% \
          --layout=reverse \
          --border \
          --cycle \
          --no-info \
          --query="$_D1_QUERY" \
          --print-query \
          --prompt=" ${_D1_HL} ❯ " \
          --header="$_D1_HDR" \
          --color="$_D1_COLOR" \
          --expect="ctrl-a,left,right,ctrl-h,ctrl-l"
    )
  fi

  _D1_ST=$?
  # --print-query output: line1=query  line2=key  line3=selection
  _D1_QUERY=$(printf '%s' "$_D1_R" | head -1)
  _D1_KEY=$(printf '%s' "$_D1_R" | sed -n '2p')
  _D1_SEL=$(printf '%s' "$_D1_R" | sed -n '3p')

  case "$_D1_KEY" in
    ctrl-a)
      _D1_GLOBAL=$(( 1 - _D1_GLOBAL ))
      continue ;;
    left|ctrl-h)
      _D1_GLOBAL=0
      _D1_I=$(( ((_D1_I - _D1_BASE - 1 + _D1_N) % _D1_N) + _D1_BASE ))
      continue ;;
    right|ctrl-l)
      _D1_GLOBAL=0
      _D1_I=$(( ((_D1_I - _D1_BASE + 1) % _D1_N) + _D1_BASE ))
      continue ;;
  esac

  # ESC or no selection → quit
  if [[ $_D1_ST -ne 0 || -z "$_D1_SEL" ]]; then
    printf '  \033[90mgoodbye.\033[0m\n'
    unset _D1_F _D1_L _D1_N _D1_I _D1_BASE _D1_COLOR _D1_FILE _D1_HL _D1_HDR _D1_MISS
    unset _D1_GLOBAL _D1_QUERY _D1_R _D1_ST _D1_KEY _D1_SEL
    return 0
  fi

  break
done

# ── resolve file/headline when selected in global mode ────────────────────────
# global items look like "[Label]  task : description"

if [[ $_D1_GLOBAL -eq 1 ]]; then
  _D1_PROJ_LABEL=$(printf '%s' "$_D1_SEL" | sed 's/^\[\([^]]*\)\].*/\1/')
  _D1_SEL=$(printf '%s' "$_D1_SEL" | sed 's/^\[[^]]*\]  *//')
  _D1_FILE=""; _D1_HL="$_D1_PROJ_LABEL"
  for (( _D1_J=_D1_BASE; _D1_J<_D1_N+_D1_BASE; _D1_J++ )); do
    if [[ "${_D1_L[$_D1_J]}" == "$_D1_PROJ_LABEL" ]]; then
      _D1_FILE="${_D1_F[$_D1_J]}"; _D1_HL="${_D1_L[$_D1_J]}"; break
    fi
  done
  unset _D1_PROJ_LABEL _D1_J
  if [[ -z "$_D1_FILE" ]]; then
    printf '  \033[1;31m✗\033[0m  could not resolve project for selection\n'
    unset _D1_F _D1_L _D1_N _D1_I _D1_BASE _D1_COLOR _D1_FILE _D1_HL _D1_HDR _D1_MISS
    unset _D1_GLOBAL _D1_QUERY _D1_R _D1_ST _D1_KEY _D1_SEL; return 1
  fi
fi

# ── run selected task ─────────────────────────────────────────────────────────

_D1_TN=$(printf '%s' "$_D1_SEL" | awk -F ' : ' '{print $1}')
_D1_CMD=$(awk -F '|' -v n="$_D1_TN" '
  { f=$1; gsub(/^[ \t]+|[ \t]+$/, "", f)
    if (f == n) { gsub(/^[ \t]+|[ \t]+$/, "", $3); print $3; exit } }
' "$_D1_FILE")

_D1_SF="$_D1_FILE"

# cleanup all nav state before eval — leaves shell options untouched
unset _D1_F _D1_L _D1_N _D1_I _D1_BASE _D1_COLOR _D1_FILE _D1_HDR _D1_MISS
unset _D1_GLOBAL _D1_QUERY _D1_R _D1_ST _D1_KEY _D1_SEL _D1_TN

if [[ -z "$_D1_CMD" ]]; then
  printf '  \033[1;31m✗\033[0m  no command found for that task\n'
  unset _D1_CMD _D1_SF _D1_HL; return 1
fi

printf '  \033[1;32m▶\033[0m  \033[1m[%s]\033[0m\n' "$_D1_HL"
unset _D1_HL

eval "$_D1_CMD"
unset _D1_CMD

# ── auto-recurse: if task changed to a dir that has a new .taskit ─────────────

if [[ -f ".taskit" ]]; then
  _D1_NT="$(pwd)/.taskit"
  if [[ "$_D1_NT" != "$_D1_SF" ]]; then
    printf '\033[90m  📂 .taskit found in %s — loading…\033[0m\n' "$(pwd)"
    _D1_TMP=$(mktemp /tmp/demo1.XXXXXX)
    printf '%s | %s\n' "$_D1_NT" "$(basename "$(pwd)")" > "$_D1_TMP"
    unset _D1_SF _D1_NT
    source "$SCRIPT_PATH" "$_D1_TMP"
    _D1_RET=$?
    rm -f "$_D1_TMP"
    return $_D1_RET
  fi
fi

unset _D1_SF _D1_NT _D1_TMP
