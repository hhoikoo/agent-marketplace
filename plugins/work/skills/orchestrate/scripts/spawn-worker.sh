#!/usr/bin/env bash
# Spawn one Claude worker in a new tmux window, named at launch, and hand it its prompt file.
# Usage: spawn-worker.sh [--launcher <name>] [--model <model>] <tmux-session> <window-name> <start-dir> <session-name> <prompt-file>
#        spawn-worker.sh [--launcher <name>] [--model <model>] --pane <tmux-pane> <start-dir> <session-name> <prompt-file>
#   --launcher  launcher name from the launchers file (default: claude, which needs no file)
#   --model     passed to the launcher as --model <model>
#   --pane      splits the given pane's window instead of creating a window (master handover)
# The session starts as `<command> -n <session-name>`; it sets ORCH_ROLE (worker, or master
# with --pane) and passes ORCH_HANDOVER_PERCENT through when it is set.
# Env:
#   ORCH_LAUNCHERS_FILE  launchers file (default: ${XDG_CONFIG_HOME:-$HOME/.config}/agent-marketplace/orchestrate/launchers.json)
#   ORCH_READY_MARKER    text that shows the session's input prompt is up (default: ❯)
#   ORCH_READY_TRIES     readiness checks, 2 s apart (default: 45, i.e. 90 s)
set -euo pipefail

usage() {
  echo "usage: $0 [--launcher <name>] [--model <model>] <tmux-session> <window-name> <start-dir> <session-name> <prompt-file>" >&2
  echo "       $0 [--launcher <name>] [--model <model>] --pane <tmux-pane> <start-dir> <session-name> <prompt-file>" >&2
  exit 2
}
launcher=claude
model=""
split_pane=""
role=worker
while [[ $# -gt 0 ]]; do
  case $1 in
    --launcher) [[ $# -ge 2 ]] || usage; launcher=$2; shift 2 ;;
    --model) [[ $# -ge 2 ]] || usage; model=$2; shift 2 ;;
    --pane) [[ $# -ge 2 ]] || usage; split_pane=$2 role=master; shift 2 ;;
    -*) usage ;;
    *) break ;;
  esac
done
if [[ -n $split_pane ]]; then
  [[ $# -eq 3 ]] || usage
  start_dir=$1 sname=$2 prompt_file=$3
else
  [[ $# -eq 5 ]] || usage
  sess=$1 wname=$2 start_dir=$3 sname=$4 prompt_file=$5
fi
launchers_file=${ORCH_LAUNCHERS_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/agent-marketplace/orchestrate/launchers.json}
marker=${ORCH_READY_MARKER:-❯}
tries=${ORCH_READY_TRIES:-45}

[[ -f $prompt_file ]] || { echo "prompt file not found: $prompt_file" >&2; exit 1; }
[[ -d $start_dir ]] || { echo "start dir not found: $start_dir" >&2; exit 1; }

if [[ $launcher == claude ]]; then
  exe=claude
else
  [[ -f $launchers_file ]] || { echo "launcher '$launcher' requested but $launchers_file does not exist" >&2; exit 1; }
  command -v jq >/dev/null || { echo "jq is required to read $launchers_file" >&2; exit 1; }
  exe=$(jq -er --arg n "$launcher" '[.launchers[]? | select(.name == $n) | .command] | first // empty' "$launchers_file") || {
    names=$(jq -r '[.launchers[]?.name] | join(", ")' "$launchers_file" 2>/dev/null || echo "unreadable file")
    echo "launcher '$launcher' not found in $launchers_file (available: claude${names:+, $names})" >&2
    exit 1
  }
fi
command -v "$exe" >/dev/null || { echo "launcher command not found: $exe" >&2; exit 1; }

cmd="env ORCH_ROLE=$role"
if [[ -n ${ORCH_HANDOVER_PERCENT:-} ]]; then cmd+=" ORCH_HANDOVER_PERCENT=$(printf %q "$ORCH_HANDOVER_PERCENT")"; fi
cmd+=" $(printf %q "$exe") -n $(printf %q "$sname")"
if [[ -n $model ]]; then cmd+=" --model $(printf %q "$model")"; fi

# The launcher is the window's command, so no interactive shell prompt can eat keystrokes.
if [[ -n $split_pane ]]; then
  target=$(tmux split-window -d -t "$split_pane" -c "$start_dir" -P -F '#{pane_id}' "$cmd")
else
  w=$(tmux new-window -d -t "$sess:" -n "$wname" -c "$start_dir" -P -F '#{window_index}' "$cmd")
  target="$sess:$w"
fi

# The folder-trust dialog also shows the marker; never answer it from here.
ready=0
for _ in $(seq 1 "$tries"); do
  pane=$(tmux capture-pane -p -t "$target" 2>/dev/null) || { echo "$target: pane exited before ready" >&2; exit 1; }
  if grep -qF 'trust this folder' <<<"$pane"; then
    echo "$target: '$start_dir' is not a trusted folder; start in a trusted dir or have the owner accept it" >&2
    exit 1
  fi
  if grep -qF -- "$marker" <<<"$pane"; then ready=1; break; fi
  sleep 2
done
if [[ $ready -ne 1 ]]; then
  echo "$target: ready marker '$marker' not seen; inspect with: tmux capture-pane -p -t $target" >&2
  exit 1
fi

tmux send-keys -t "$target" C-u
tmux send-keys -t "$target" -l "Read $prompt_file and follow it exactly. It names you, tells you who to report to, and points at your full brief."
tmux send-keys -t "$target" Enter

echo "target=$target session=$sname launcher=$launcher"
