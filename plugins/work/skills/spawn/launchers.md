# Launchers

Sessions start with `claude` unless the user registers alternative launchers in a local file:

`${XDG_CONFIG_HOME:-$HOME/.config}/agent-marketplace/spawn/launchers.json`

The file is optional and stays on the user's machine. Read it with `cat` when you need to pick a launcher; if it is absent, use only `claude`. `SPAWN_LAUNCHERS_FILE` overrides the path.

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
| `name` | what you pass to `spawn.sh --launcher`; `claude` is reserved for plain `claude` |
| `command` | executable on `PATH`, or an absolute path, that takes the same arguments as `claude` (`-n`, `--model`, and the kickoff as a positional prompt after `--`) |
| `description` | which model or provider it runs, including how `--model` values map |
| `use_for` | the work that may run under it |
| `avoid_for` | the work that must never run under it |

Follow `use_for` and `avoid_for` strictly. Never print or read the launcher's own script; it may hold credentials.
