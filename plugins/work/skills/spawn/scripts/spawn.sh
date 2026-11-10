#!/usr/bin/env bash
# Start a Claude Code session in tmux and hand it a prompt file.
# Usage: spawn.sh [options] <prompt-file>
#   --replace           split this pane ($TMUX_PANE, or --pane) and have the new session kill it
#   --pane <pane>       pane to split and replace (implies --replace; default $TMUX_PANE)
#   --session <s>       tmux session for a new window (default: the current one)
#   --window-name <w>   name of the new window (default: the session name, or "claude")
#   --name <n>          session name, passed as `-n <n>` (default: $SPAWN_NAME)
#   --model <m>         passed as `--model <m>` (default: $SPAWN_MODEL)
#   --launcher <l>      launcher from the launchers file (default: $SPAWN_LAUNCHER, else claude)
#   --cwd <dir>         start directory (default: the current pane's directory, else $PWD)
#   --env K=V           extra env for the new session; repeatable; overrides inherited values
# Inherited by default: ORCH_ROLE and HANDOVER_PERCENT when set. The new session gets
# SPAWN_NAME, SPAWN_MODEL and SPAWN_LAUNCHER, so its own successor inherits them.
# Env:
#   SPAWN_LAUNCHERS_FILE  launchers file (default: ${XDG_CONFIG_HOME:-$HOME/.config}/agent-marketplace/spawn/launchers.json)
#   SPAWN_SETTLE          seconds to watch for an early exit or the folder-trust dialog (default: 6)
# Prints: target=<tmux target> pane=<pane id> session=<name> launcher=<name>
set -euo pipefail

usage() { sed -n '3,15p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 2; }
need() { [[ $1 -ge 2 ]] || usage; }

replace=0 pane="" tsess="" wname=""
name=${SPAWN_NAME:-} model=${SPAWN_MODEL:-} launcher=${SPAWN_LAUNCHER:-claude} cwd=""
extra_env=()
while [[ $# -gt 0 ]]; do
  case $1 in
    --replace) replace=1; shift ;;
    --pane) need $#; pane=$2 replace=1; shift 2 ;;
    --session) need $#; tsess=$2; shift 2 ;;
    --window-name) need $#; wname=$2; shift 2 ;;
    --name) need $#; name=$2; shift 2 ;;
    --model) need $#; model=$2; shift 2 ;;
    --launcher) need $#; launcher=$2; shift 2 ;;
    --cwd) need $#; cwd=$2; shift 2 ;;
    --env) need $#; [[ $2 == *=* ]] || usage; extra_env+=("$2"); shift 2 ;;
    -h|--help) usage ;;
    -*) usage ;;
    *) break ;;
  esac
done
[[ $# -eq 1 ]] || usage
prompt_file=$1
[[ -f $prompt_file ]] || { echo "prompt file not found: $prompt_file" >&2; exit 1; }
prompt_file=$(cd "$(dirname "$prompt_file")" && pwd)/$(basename "$prompt_file")

if [[ $replace -eq 1 ]]; then
  pane=${pane:-${TMUX_PANE:-}}
  [[ -n $pane ]] || { echo "--replace needs a pane: run inside tmux or pass --pane" >&2; exit 1; }
  pane=$(tmux display -p -t "$pane" '#{pane_id}') || { echo "pane not found: $pane" >&2; exit 1; }
fi
if [[ -z $cwd ]]; then
  cwd=$(tmux display -p -t "${pane:-${TMUX_PANE:-}}" '#{pane_current_path}' 2>/dev/null || true)
  cwd=${cwd:-$PWD}
fi
[[ -d $cwd ]] || { echo "start dir not found: $cwd" >&2; exit 1; }

launchers_file=${SPAWN_LAUNCHERS_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/agent-marketplace/spawn/launchers.json}
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

# Inherited env first; --env entries come later on the command line, so they win.
envs=("SPAWN_LAUNCHER=$launcher")
[[ -n $name ]] && envs+=("SPAWN_NAME=$name")
[[ -n $model ]] && envs+=("SPAWN_MODEL=$model")
for v in ORCH_ROLE HANDOVER_PERCENT; do
  [[ -n ${!v:-} ]] && envs+=("$v=${!v}")
done
envs+=(${extra_env[@]+"${extra_env[@]}"})

cmd="env"
for e in "${envs[@]}"; do cmd+=" $(printf %q "$e")"; done
cmd+=" $(printf %q "$exe")"
[[ -n $name ]] && cmd+=" -n $(printf %q "$name")"
[[ -n $model ]] && cmd+=" --model $(printf %q "$model")"

kickoff="Read $prompt_file and follow it exactly."
if [[ $replace -eq 1 ]]; then
  kickoff="You replace the session in tmux pane $pane. First close it: tmux kill-pane -t $pane. Then read $prompt_file and follow it exactly."
fi
# The kickoff is the launcher's positional prompt: the session starts with it already
# submitted, so nothing is typed into the pane and there is no readiness race.
cmd+=" -- $(printf %q "$kickoff")"

# The launcher is the pane's command, so no interactive shell prompt can eat keystrokes.
if [[ $replace -eq 1 ]]; then
  new_pane=$(tmux split-window -d -t "$pane" -c "$cwd" -P -F '#{pane_id}' "$cmd")
  target=$new_pane
else
  if [[ -z $tsess ]]; then
    tsess=$(tmux display -p '#S' 2>/dev/null) || { echo "not inside tmux: pass --session" >&2; exit 1; }
  fi
  wname=${wname:-${name:-claude}}
  read -r target new_pane < <(tmux new-window -d -t "$tsess:" -n "$wname" -c "$cwd" -P -F '#{session_name}:#{window_index} #{pane_id}' "$cmd")
fi

# Fail fast on the two start-up stops that ListAgents cannot show: a launcher that exits at
# once (bad arguments), and the folder-trust dialog, which holds the session before it
# registers. Nothing is typed into the pane; never answer the dialog from here.
for _ in $(seq 1 "${SPAWN_SETTLE:-6}"); do
  sleep 1
  screen=$(tmux capture-pane -p -t "$new_pane" 2>/dev/null) || { echo "$target: session exited right after launch" >&2; exit 1; }
  if grep -qF 'trust this folder' <<<"$screen"; then
    echo "$target: '$cwd' is not a trusted folder; start in a trusted dir or have the user accept it in $target" >&2
    exit 1
  fi
done

echo "target=$target pane=$new_pane session=${name:-} launcher=$launcher"
