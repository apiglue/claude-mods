# claude-mods

Mods for [Claude Code](https://claude.com/claude-code).

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
