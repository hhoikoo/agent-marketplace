#!/usr/bin/env bash
# Rename the Claude Code session in this tmux pane by typing `/rename <name>` into it.
# Slash commands are not a tool, so the keys are typed into the pane after a delay; run this
# in the background and end the turn so the session is idle when they land.
# Usage: rename-self.sh <name>
# Env: TMUX_PANE (set by tmux), SPAWN_RENAME_DELAY seconds to wait first (default: 8)
set -euo pipefail
[[ $# -eq 1 && -n $1 ]] || { echo "usage: $0 <name>" >&2; exit 2; }
pane=${TMUX_PANE:?not inside tmux}
sleep "${SPAWN_RENAME_DELAY:-8}"
tmux send-keys -t "$pane" C-u
tmux send-keys -t "$pane" -l "/rename $1"
sleep 1
tmux send-keys -t "$pane" Enter
