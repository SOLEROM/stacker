# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

`taskStack` is a shell-based task runner. Scripts **must be sourced** (not executed) so that task commands (`cd`, `export`, etc.) run in the caller's shell. It presents an `fzf` menu and `eval`s the selected task's command.

## Files

| File | Purpose |
|------|---------|
| `demo0.sh` | Original single-project launcher (legacy, keep for reference) |
| `demo1.sh` | Multi-project navigator — the active tool |
| `demo1.projects` | List of projects to load; edit this to add/remove projects |
| `.taskit` | Local dev tasks for this repo itself |
| `innerTest/.taskit` | Nested example used for drill-down testing |

## .taskit format

Pipe-delimited, three columns per line:

```
task_name | description | shell_command
```

Lines starting with `-` or a space are skipped (sub-items / comments).

## demo1.sh — how to run

```bash
source ./demo1.sh                    # uses demo1.projects next to the script
source ./demo1.sh /path/to/my.list   # explicit projects file
```

**demo1.projects format** — one project per line, `#` lines ignored:
```
/absolute/path/to/.taskit | Headline shown in fzf
```

### Keys

| Key | Action |
|-----|--------|
| `←` / `ctrl-h` | Previous project |
| `→` / `ctrl-l` | Next project |
| `ctrl-a` | Toggle **global search** (all projects at once) |
| `Enter` | Run selected task and exit |
| `Esc` | Quit |

### Global search mode

`ctrl-a` switches the fzf prompt to `globalFilter ❯` and feeds tasks from every project simultaneously, prefixed `[Label]  task : description`. The typed query is preserved when toggling. `ctrl-a` again returns to per-project mode. Pressing `←`/`→` while in global mode also returns to per-project mode.

### Auto-recurse

After a task runs, if the current directory contains a `.taskit` that isn't the one just used, demo1.sh sources itself for that file (preserves the "cd into project → see its menu" workflow from demo0).

## Shell compatibility

The scripts are sourced in **zsh** on this machine (user shell) despite the `#!/bin/bash` shebang, which is ignored on source. Key compat decisions in demo1.sh:

- **No `setopt KSH_ARRAYS`** — changing shell options in a sourced script persists and breaks the interactive prompt. Instead, `_D1_BASE` is set to `1` (zsh) or `0` (bash) at startup and all array index arithmetic uses it as an offset.
- `declare -a` works in both bash and zsh.
- `(( ))` arithmetic for loops works in both.

## Dependencies

- `fzf` ≥ 0.20.0 — interactive menu (`--expect`, `--print-query`, `--no-info`, `--border` all used)
- `awk`, `sed` — task file parsing and selection text processing
