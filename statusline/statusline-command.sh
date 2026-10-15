#!/bin/sh
# Claude Code status line: repo/branch, context bar, plan limits, model — truecolor.
#
# Reads the JSON payload Claude Code pipes in on stdin. Field names below were
# taken from an actual payload on 2.1.222 (dump it again with
# `printf '%s' "$input" > /tmp/claude-statusline.json` if a future build moves
# things); every read falls back to empty so a missing field drops its segment
# rather than printing an error into the status bar.
input=$(cat)

model=$(printf '%s' "$input" | jq -r '.model.display_name // empty')
model_id=$(printf '%s' "$input" | jq -r '.model.id // empty')
repo=$(printf '%s' "$input" | jq -r '.workspace.repo.name // empty')
cwd=$(printf '%s' "$input" | jq -r '.cwd // .workspace.current_dir // empty')
ctx=$(printf '%s' "$input" | jq -r '.context_window.used_percentage // empty')
five=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.used_percentage // empty')
five_at=$(printf '%s' "$input" | jq -r '.rate_limits.five_hour.resets_at // empty')
week=$(printf '%s' "$input" | jq -r '.rate_limits.seven_day.used_percentage // empty')
cost=$(printf '%s' "$input" | jq -r '.cost.total_cost_usd // empty')
session=$(printf '%s' "$input" | jq -r '.session_id // empty')
effort=$(printf '%s' "$input" | jq -r '.effort.level // empty')
# effort-router's per-turn choice wins over the session's setting: the payload
# carries only the setting, not what the mod sent for this turn.
[ -n "$session" ] && [ -n "$effort" ] && [ -r "/tmp/claude-effort-router/$session" ] &&
  effort=$(cat "/tmp/claude-effort-router/$session")

# Repo name falls back to the cwd's basename so the segment still shows
# something outside a git remote.
[ -z "$repo" ] && [ -n "$cwd" ] && repo=$(basename "$cwd")

# Fall back to the cwd basename above if repo.name was empty, but if cwd was
# empty too there's nothing to show for it — that's fine, the segment drops.

OFF='\033[0m'
BOLD='\033[1m'
YELLOW='\033[38;2;220;200;0m'
CYAN='\033[38;2;0;210;210m'
MAGENTA='\033[38;2;200;0;200m'
GREEN='\033[38;2;0;200;80m'
RED='\033[38;2;220;40;20m'
ORANGE='\033[38;2;220;120;20m'
GRAY='\033[38;2;90;90;90m'

PIPE="${GRAY} │ ${OFF}"

# Usage-level colour, reused for the percentage figure and the rate-limit
# figures so a "90" reads red everywhere it appears.
colour_for() {
  n=${1%%.*}
  if [ "$n" -ge 90 ] 2>/dev/null; then printf '%s' "$RED"
  elif [ "$n" -ge 70 ] 2>/dev/null; then printf '%s' "$ORANGE"
  elif [ "$n" -ge 20 ] 2>/dev/null; then printf '%s' "$YELLOW"
  else printf '%s' "$GREEN"
  fi
}

# The API hands back full float precision ("28.999999999999996"), which is
# noise in a status bar. Round to 2 dp, then drop trailing zeros so a clean
# figure still prints as "29" rather than "29.00".
fmt_pct() {
  awk -v v="$1" 'BEGIN {
    s = sprintf("%.2f", v);
    sub(/\.?0+$/, "", s);
    printf("%s", s);
  }'
}

# 20-block bar. Each filled block is coloured by its own position along the
# bar (not by the overall percentage), so the fill itself sweeps
# green(0,200,80) → yellow(220,200,0) → red(220,40,20); empty blocks stay a
# flat dark gray(60,60,60). Needs awk for the float interpolation — no bc
# dependency.
bar_for() {
  awk -v pct="$1" -v blocks=20 'BEGIN {
    filled = int(pct / 100 * blocks + 0.5);
    for (i = 0; i < blocks; i++) {
      if (i < filled) {
        frac = (i + 0.5) / blocks * 100;
        if (frac <= 50) {
          t = frac / 50;
          r = 0   + t * (220 - 0);
          g = 200 + t * (200 - 200);
          b = 80  + t * (0   - 80);
        } else {
          t = (frac - 50) / 50;
          r = 220 + t * (220 - 220);
          g = 200 + t * (40  - 200);
          b = 0   + t * (20  - 0);
        }
        printf("\033[38;2;%d;%d;%dm█", r, g, b);
      } else {
        printf("\033[38;2;60;60;60m█");
      }
    }
    printf("\033[0m");
  }'
}

# macOS ships BSD date (-r), GNU date wants -d @. Try both, print neither if
# the platform is a third thing.
clock() {
  date -r "$1" +%H:%M 2>/dev/null || date -d "@$1" +%H:%M 2>/dev/null
}

out=""
sep=""

# Octopus + repo name, bold yellow. Unicode has no git emoji, so 🐙
# (GitHub's Octocat) stands in for one; unlike a Nerd Font glyph it needs no special font.
[ -n "$repo" ] && {
  out="${out}${BOLD}${YELLOW}🐙 ${repo}${OFF}"
  sep="$PIPE"
}

# Leaf + branch + powerlevel10k-style status, bold cyan, parenthesised:
#   ⇣N ⇡N  behind/ahead of upstream     *N  stashes
#   ~N     conflicted                    +N  staged
#   !N     unstaged                      ?N  untracked
# A detached HEAD shows as @<short sha>, as in p10k. Colours are the 256-colour
# indices from my_git_formatter in ~/.p10k.zsh, so the two read alike: branch,
# ahead/behind and stashes green (76), staged/unstaged yellow (178), untracked
# blue (39), conflicts red (196), the @ grey (248). One porcelain-v2 call
# covers everything but stashes. Skips optional locks so this never contends
# with a concurrent git operation.
if [ -n "$cwd" ]; then
  gst=$(git -C "$cwd" --no-optional-locks status --porcelain=v2 --branch 2>/dev/null)
  [ -n "$gst" ] && {
    stashes=$(git -C "$cwd" --no-optional-locks rev-list --walk-reflogs --count refs/stash 2>/dev/null)
    git_seg=$(printf '%s\n' "$gst" | awk -v stashes="${stashes:-0}" '
      BEGIN {
        meta = "\033[38;5;248m"; clean = "\033[38;5;76m"; modified = "\033[38;5;178m"
        untracked_c = "\033[38;5;39m"; conflicted_c = "\033[38;5;196m"
      }
      /^# branch\.oid / { oid = substr($3, 1, 7) }
      /^# branch\.head / { head = $3 }
      /^# branch\.ab /   { ahead = substr($3, 2) + 0; behind = substr($4, 2) + 0 }
      /^[12] / {
        x = substr($2, 1, 1); y = substr($2, 2, 1)
        if (x != ".") staged++
        if (y != ".") unstaged++
      }
      /^u / { conflicted++ }
      /^\? / { untracked++ }
      END {
        s = (head == "(detached)") ? meta "@" clean oid : clean head
        if (behind)     s = s " " clean "⇣" behind
        if (ahead)      s = s (behind ? "" : " ") clean "⇡" ahead
        if (stashes)    s = s " " clean "*" stashes
        if (conflicted) s = s " " conflicted_c "~" conflicted
        if (staged)     s = s " " modified "+" staged
        if (unstaged)   s = s " " modified "!" unstaged
        if (untracked)  s = s " " untracked_c "?" untracked
        printf("%s", s)
      }')
    # Just a space after the repo name, so repo and branch read as one segment.
    [ -n "$repo" ] && sep=" "
    out="${out}${sep}${BOLD}${CYAN}🌿 (${OFF}${git_seg}${BOLD}${CYAN})${OFF}"
    sep="$PIPE"
  }
fi

# Current folder, with $HOME shortened to ~ so the full path stays readable.
[ -n "$cwd" ] && {
  case "$cwd" in
    "$HOME"|"$HOME"/*) dir="~${cwd#"$HOME"}" ;;
    *) dir="$cwd" ;;
  esac
  out="${out}${sep}${GREEN}📁 ${dir}${OFF}"
  sep="$PIPE"
}

# Context bar + coloured percentage.
[ -n "$ctx" ] && {
  out="${out}${sep}$(bar_for "$ctx") $(colour_for "$ctx")$(fmt_pct "$ctx")%${OFF}"
  sep="$PIPE"
}

# The number that decides whether to keep going or wrap up, so it carries its
# reset time — "95%" alone does not say whether relief is in two minutes or
# two hours.
[ -n "$five" ] && {
  at=""
  [ -n "$five_at" ] && at=" ↻$(clock "$five_at")"
  out="${out}${sep}5h: $(colour_for "$five")$(fmt_pct "$five")%${at}${OFF}"
  sep="$PIPE"
}

[ -n "$week" ] && {
  out="${out}${sep}7d: $(colour_for "$week")$(fmt_pct "$week")%${OFF}"
  sep="$PIPE"
}

# Fable only, by request.
#
# On a Pro subscription the dollar figure is not a bill — it is the equivalent
# API cost of the tokens, and the two percentages above are what actually
# constrain a session. Shown here because it is the number worth watching
# while Fable is the active model, and hidden otherwise so it does not read
# as a charge during ordinary work.
#
# Matched on the id rather than the display name: ids are stable, display
# names are marketing copy. Substring rather than equality, so a dated or
# versioned id (claude-fable-5, claude-fable-5-20261101) still matches.
case "$model_id" in
  *fable*)
    [ -n "$cost" ] && {
      out="${out}${sep}${YELLOW}≈\$$(printf '%.2f' "$cost")${OFF}"
      sep="$PIPE"
    }
    ;;
esac

# Model, magenta, with the turn's effort in parentheses when the model takes one.
[ -n "$model" ] && {
  out="${out}${sep}${MAGENTA}🤖 ${model}${OFF}"
  [ -n "$effort" ] && out="${out}${MAGENTA} (${effort})${OFF}"
  sep="$PIPE"
}

printf "%b" "$out"
