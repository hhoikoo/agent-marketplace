# Launchers

Workers start with `claude` unless the owner registers alternative launchers in a local file:

`${XDG_CONFIG_HOME:-$HOME/.config}/agent-marketplace/orchestrate/launchers.json`

The file is optional and stays on the owner's machine. Read it at launch with `cat`; if it is absent, use only `claude`. `ORCH_LAUNCHERS_FILE` overrides the path.

## Schema

```json
{
  "launchers": [
    {
      "name": "alt",
      "command": "claude-alt",
      "description": "Claude Code against another model provider; sonnet and haiku map to Model X, opus to Model Y.",
      "use_for": "Coding-heavy implementation units.",
      "avoid_for": "Decisions, judgement handlers, reviews."
    }
  ]
}
```

| field | meaning |
|---|---|
| `name` | what you pass to `spawn-worker.sh --launcher`; `claude` is reserved for plain `claude` |
| `command` | executable on `PATH`, or an absolute path, that takes the same arguments as `claude` (`-n`, `--model`) |
| `description` | which model or provider it runs, including how `--model` values map |
| `use_for` | the units the master may launch under it |
| `avoid_for` | the work the master must never launch under it |

Follow `use_for` and `avoid_for` strictly. Never print or read the launcher's own script; it may hold credentials.
