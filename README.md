# claude-mods

Mods for [Claude Code](https://claude.com/claude-code), plus the status line they pair with.

## effort-router

Picks the reasoning effort for each turn from your prompt, so you don't pay high effort for "what time is it in Tokyo?".

- **low**: a short question (under 200 characters, ending in `?` or starting with *what*, *how*, *is*…)
- **high**: work words (*refactor*, *build*, *debug*, *fix*, *review*, *plan*…) or a prompt over 800 characters
- **medium**: everything else

Only the main conversation is routed. Subagents keep their own effort.

`/route` shows the current mode, `/route low|medium|high` pins an effort, and `/route auto` switches back to routing by prompt.

The effort chosen for each turn is written to `/tmp/claude-effort-router/<session id>`, so a status line script can display it.

## Install

At the prompt of a terminal session:

```
/plugin install effort-router --marketplace apiglue/claude-mods
```

Answer `y` to add the marketplace, then pick a scope.

From a shell:

```
claude plugin install effort-router --marketplace apiglue/claude-mods
```

In the desktop app, where `/plugin` does not run: click + next to the prompt box, then Plugins, Add marketplace with `apiglue/claude-mods`, then Add plugin.

## Status line

`statusline/statusline-command.sh` is a truecolor status line that shows:

- repo, branch with powerlevel10k-style git status in the same colours as `~/.p10k.zsh` (e.g. `rooster (main !1)`), and current folder
- the context window as a 20-block bar, plus its percentage
- the 5-hour (with its reset time) and 7-day plan limits, colored green → yellow → orange → red as they fill
- the model, with the turn's effort in parentheses, e.g. `Opus 5.5 (low)`. With effort-router installed, that is the effort the mod chose for the turn rather than the session's setting.
- the equivalent API cost, only while a Fable model is active

It needs `jq`. A status line is a setting, not something a plugin can install, so clone this repo and point `statusLine` in `~/.claude/settings.json` at the script:

```json
"statusLine": {
  "type": "command",
  "command": "bash /path/to/claude-mods/statusline/statusline-command.sh"
}
```

A `git pull` in the clone picks up changes, since the setting runs the file straight from it.
