# Superpowers for GitHub Copilot

Guide for using Superpowers with **GitHub Copilot agent mode** in VS Code and the **GitHub Copilot CLI**.

Both tools use the same setup: per-skill symlinks in `~/.copilot/skills/` (scanned by default by both tools) and a shared `~/.claude/settings.json` for the `SessionStart` hook.

---

## Installation

### 1. Clone Superpowers

```bash
git clone https://github.com/lvthillo/superpowers.git ~/.copilot/superpowers
chmod +x ~/.copilot/superpowers/hooks/copilot-session-start.sh
```

### 2. Symlink skills

Both VS Code and Copilot CLI scan `~/.copilot/skills/` for skills as direct children. Symlink each skill there:

```bash
mkdir -p ~/.copilot/skills
for skill_dir in ~/.copilot/superpowers/skills/*/; do
  ln -sf "$skill_dir" ~/.copilot/skills/
done
```

Verify:

```bash
ls ~/.copilot/skills/
# Should list: brainstorming  dispatching-parallel-agents  executing-plans ...
```

### 3. Register the session-start hook

Both Claude Code and GitHub Copilot read hooks from `~/.claude/settings.json`. This command sets the `SessionStart` hook, preserving all other settings (requires `jq`):

```bash
HOOK_PATH="$HOME/.copilot/superpowers/hooks/copilot-session-start.sh"
if [ -f ~/.claude/settings.json ]; then
  jq --arg hook "$HOOK_PATH" \
    '.hooks.SessionStart = [{"matcher": "", "hooks": [{"type": "command", "command": $hook}]}]' \
    ~/.claude/settings.json > /tmp/claude-settings.json \
    && mv /tmp/claude-settings.json ~/.claude/settings.json
else
  mkdir -p ~/.claude
  jq -n --arg hook "$HOOK_PATH" \
    '{hooks: {SessionStart: [{matcher: "", hooks: [{type: "command", command: $hook}]}]}}' \
    > ~/.claude/settings.json
fi
```

Verify the path expanded correctly:

```bash
jq '.hooks.SessionStart[0].hooks[0].command' ~/.claude/settings.json
```

### 4. VS Code only: enable hooks

In VS Code settings (`Cmd+,` / `Ctrl+,`), search for `chat.useHooks` and set it to `true`.

### 5. Restart

Restart VS Code or the CLI — skills are discovered at startup.

---

## Windows

```powershell
git clone https://github.com/lvthillo/superpowers.git "$env:USERPROFILE\.copilot\superpowers"

# Symlink each skill (requires Developer Mode or run as Admin)
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.copilot\skills"
Get-ChildItem "$env:USERPROFILE\.copilot\superpowers\skills" -Directory | ForEach-Object {
  cmd /c mklink /J "$env:USERPROFILE\.copilot\skills\$($_.Name)" $_.FullName
}
```

For `%USERPROFILE%\.claude\settings.json`, use the full path in `command`:

```json
{
  "hooks": {
    "SessionStart": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "C:\\Users\\<YourName>\\.copilot\\superpowers\\hooks\\copilot-session-start.sh"
          }
        ]
      }
    ]
  }
}
```

---

## How It Works

Both tools use the same two mechanisms:

- **Skills** — discovered natively from `~/.copilot/skills/`. Each skill's `description` field acts as its trigger condition; the agent loads it when relevant.
- **`SessionStart` hook** — injects the full `using-superpowers` skill and a skills registry (name + description + absolute path for each skill) into context at session start, so the agent knows where to read skill files from disk.

Skills activate on-demand — `brainstorming` before writing code, `test-driven-development` during implementation, `systematic-debugging` when hitting errors, etc.


## Updating

```bash
cd ~/.copilot/superpowers && git pull
# Re-run the symlink loop if new skills were added
for skill_dir in ~/.copilot/superpowers/skills/*/; do
  ln -sf "$skill_dir" ~/.copilot/skills/
done
```

## Uninstalling

```bash
for skill_dir in ~/.copilot/superpowers/skills/*/; do
  rm -f ~/.copilot/skills/$(basename "$skill_dir")
done
# Remove the SessionStart block from ~/.claude/settings.json
# Optionally: rm -rf ~/.copilot/superpowers
```

## Troubleshooting

### Diagnostic commands

```bash
# 1. Check the hook path is a real absolute path (not ${HOME}/...)
jq '.hooks.SessionStart[0].hooks[0].command' ~/.claude/settings.json

# 2. Confirm the script exists and is executable
ls -la "$(jq -r '.hooks.SessionStart[0].hooks[0].command' ~/.claude/settings.json)"

# 3. Test the hook script produces valid JSON
bash ~/.copilot/superpowers/hooks/copilot-session-start.sh | python3 -m json.tool > /dev/null && echo "✓ Script OK"

# 4. Preview the injected skills registry
bash ~/.copilot/superpowers/hooks/copilot-session-start.sh \
  | python3 -c "import json,sys; d=json.load(sys.stdin); ctx=d['hookSpecificOutput']['additionalContext']; print(ctx[ctx.rfind('## Available Skills'):])"

# 5. Check skills are symlinked correctly
ls -la ~/.copilot/skills/
```

### Hook not running (VS Code)

1. Confirm `chat.useHooks: true` in VS Code settings
2. Run diagnostic 1 — if it shows `${HOME}/...`, the `$HOME` didn't expand; rerun step 3
3. Right-click in the Chat view → **Diagnostics** to see loaded hooks and errors

### Skills not loading

1. Run diagnostic 5 — each skill should appear as a direct entry (not nested under a `superpowers/` folder)
2. VS Code: run **Chat: Configure Skills** to see what's loaded; try `/brainstorming` in chat
3. CLI: restart after adding symlinks

## Getting Help

- Report issues: https://github.com/obra/superpowers/issues
- Main documentation: https://github.com/obra/superpowers



