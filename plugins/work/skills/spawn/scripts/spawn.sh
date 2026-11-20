#!/usr/bin/env bash
# Start a Claude Code session in tmux and hand it a prompt file.
# Usage: spawn.sh [options] <prompt-file>
#   --replace           split this pane ($TMUX_PANE, or --pane); the caller closes it afterwards
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
#   SPAWN_SETTLE          seconds to wait for the session to show its prompt (default: 60)
#   SPAWN_TRUST_ACCEPT    0 stops at the folder-trust dialog instead of accepting it (default: 1)
# Prints: target=<tmux target> pane=<pane id> session=<name> launcher=<name>
#   and with --replace a second line, close: tmux kill-pane -t <replaced pane>, for the caller to run
#   as its very last step (the new session never touches the replaced pane)
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
  # The caller closes the replaced pane with the printed close command, after finishing its own
  # work, so the successor must leave that pane alone.
  kickoff="You replace the session in tmux pane $pane. The session that started you closes that pane; leave it alone. Read $prompt_file and follow it exactly."
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

# Watch the pane until the session shows its kickoff prompt, which means it got past start-up.
# On the way, answer the folder-trust dialog (default selection "No, exit") by moving to "Yes"
# and confirming only once that option is shown as selected. Claude Code itself records the
# trust, as when a user accepts by hand. Fail on an early exit, a dialog that stays, or a
# session that never shows its prompt.
pane_text() { tmux capture-pane -p -J -t "$new_pane" "$@" 2>/dev/null; } # visible screen; -S -N adds history
accept_trust() { # move the selection to "Yes, I trust this folder", then confirm it
  # The selection wraps, so send Down once and wait for the redraw; never press it again.
  local _
  tmux send-keys -t "$new_pane" Down
  for _ in 1 2 3 4 5 6 7 8 9 10; do
    sleep 0.2
    if pane_text | grep -E '❯ *Yes, I trust this folder' >/dev/null; then
      tmux send-keys -t "$new_pane" Enter
      return 0
    fi
  done
  return 1
}
started="❯ ${kickoff%% *}" deadline=$((SECONDS + ${SPAWN_SETTLE:-60})) accepted_at=""
while :; do
  sleep 0.5
  s=$(pane_text -S -100) || { echo "$target: session exited right after launch" >&2; exit 1; }
  if grep -qF "$started" <<<"$s"; then
    sleep 1
    tmux display -p -t "$new_pane" '#{pane_id}' >/dev/null 2>&1 || { echo "$target: session exited right after launch" >&2; exit 1; }
    break
  fi
  if pane_text | grep -F 'trust this folder' >/dev/null; then
    if [[ ${SPAWN_TRUST_ACCEPT:-1} == 0 ]]; then
      echo "$target: '$cwd' is not a trusted folder and SPAWN_TRUST_ACCEPT=0; have the user accept the dialog in $target" >&2
      [[ $replace -eq 1 ]] && echo "the replaced pane $pane stays open; close it by hand once the new session runs; do not run a close command" >&2
      exit 1
    fi
    if [[ -z $accepted_at ]]; then
      accept_trust || { echo "$target: 'Yes, I trust this folder' was not selected 2 s after one Down in the trust dialog; nothing was confirmed" >&2; exit 1; }
      accepted_at=$SECONDS
    elif [[ $((SECONDS - accepted_at)) -ge 5 ]]; then
      echo "$target: the folder-trust dialog is still shown 5 s after accepting it" >&2; exit 1
    fi
  fi
  [[ $SECONDS -lt $deadline ]] || { echo "$target: session did not show its prompt within ${SPAWN_SETTLE:-60} s; look at it with tmux capture-pane -p -t $new_pane" >&2; exit 1; }
done
[[ -n $accepted_at ]] && echo "accepted the folder-trust dialog for '$cwd' (SPAWN_TRUST_ACCEPT=0 turns this off)" >&2

echo "target=$target pane=$new_pane session=${name:-} launcher=$launcher"
if [[ $replace -eq 1 ]]; then echo "close: tmux kill-pane -t $pane"; fi
