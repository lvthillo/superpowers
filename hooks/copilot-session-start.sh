#!/usr/bin/env bash
# Copilot-aware session-start hook for VS Code agent mode and Copilot CLI.
#
# Unlike session-start.sh (which tells the agent to use the Claude Code "Skill"
# tool), this script resolves skill file paths at injection time so the agent
# can read them directly from disk — no "Skill" tool required.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PLUGIN_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SKILLS_DIR="${PLUGIN_ROOT}/skills"
AGENTS_DIR="${PLUGIN_ROOT}/agents"

# ---------------------------------------------------------------------------
# JSON escaping (same as session-start.sh)
# ---------------------------------------------------------------------------
escape_for_json() {
    local s="$1"
    s="${s//\\/\\\\}"
    s="${s//\"/\\\"}"
    s="${s//$'\n'/\\n}"
    s="${s//$'\r'/\\r}"
    s="${s//$'\t'/\\t}"
    printf '%s' "$s"
}

# ---------------------------------------------------------------------------
# Build skills registry: "name — description  →  path/to/SKILL.md"
# ---------------------------------------------------------------------------
build_skills_registry() {
    local registry=""
    for skill_dir in "${SKILLS_DIR}"/*/; do
        local skill_file="${skill_dir}SKILL.md"
        [ -f "$skill_file" ] || continue

        # Extract name and description from YAML frontmatter
        local name="" description="" in_fm=0
        while IFS= read -r line; do
            if [ "$line" = "---" ]; then
                [ $in_fm -eq 0 ] && in_fm=1 || break
                continue
            fi
            [ $in_fm -eq 0 ] && continue
            case "$line" in
                name:*) name="${line#name: }" ; name="${name#name:}" ; name="${name# }" ;;
                description:*) description="${line#description: }" ; description="${description#description:}" ; description="${description# }" ; description="${description%\"}" ; description="${description#\"}" ;;
            esac
        done < "$skill_file"

        [ -z "$name" ] && continue
        registry="${registry}"$'\n'"- **${name}**: ${description}"$'\n'"  Read from: \`${skill_file}\`"
    done
    printf '%s' "$registry"
}

# ---------------------------------------------------------------------------
# Build agents registry: name → path to agent file
# ---------------------------------------------------------------------------
build_agents_registry() {
    local registry=""
    [ -d "$AGENTS_DIR" ] || { printf '%s' "$registry"; return; }
    for agent_file in "${AGENTS_DIR}"/*.md; do
        [ -f "$agent_file" ] || continue

        local name="" in_fm=0
        while IFS= read -r line; do
            if [ "$line" = "---" ]; then
                [ $in_fm -eq 0 ] && in_fm=1 || break
                continue
            fi
            [ $in_fm -eq 0 ] && continue
            case "$line" in
                name:*) name="${line#name: }" ; name="${name#name:}" ; name="${name# }" ;;
            esac
        done < "$agent_file"

        [ -z "$name" ] && continue
        registry="${registry}"$'\n'"- **${name}**: \`${agent_file}\`"
    done
    printf '%s' "$registry"
}


using_superpowers_content=$(cat "${SKILLS_DIR}/using-superpowers/SKILL.md" 2>/dev/null || echo "Error reading using-superpowers skill")
skills_registry=$(build_skills_registry)
agents_registry=$(build_agents_registry)

using_superpowers_escaped=$(escape_for_json "$using_superpowers_content")
skills_registry_escaped=$(escape_for_json "$skills_registry")
agents_registry_escaped=$(escape_for_json "$agents_registry")

tool_mapping=$(cat <<'TOOLMAP'
## Tool Mapping for Copilot

Skills reference Claude Code-specific tools. Substitute as follows:

| Skill says | Do this in Copilot |
|---|---|
| `Skill` tool | Already handled — read the SKILL.md path listed above |
| `TodoWrite` / `TodoRead` | Create/update a `.copilot-tasks.md` checklist file in the workspace root |
| `Task("...")` (dispatch subagent) | **VS Code agent mode:** start a new Copilot agent conversation with the task context. **Copilot CLI:** execute the task sequentially in this session |
| `code-reviewer` subagent | Read the agent file path listed below and apply its instructions directly in this session |
TOOLMAP
)
tool_mapping_escaped=$(escape_for_json "$tool_mapping")

session_context="<EXTREMELY_IMPORTANT>\nYou have superpowers.\n\n**Below is the full content of your 'superpowers:using-superpowers' skill:**\n\n${using_superpowers_escaped}\n\n## How to Load Skills in This Environment\n\nYou do NOT have a 'Skill' tool. Instead, read the skill file directly using your file-reading capabilities:\n\n\`\`\`\nRead the file at the path shown below for whichever skill applies.\n\`\`\`\n\n## Available Skills\n${skills_registry_escaped}\n\n## Available Agents\n${agents_registry_escaped}\n\n${tool_mapping_escaped}\n</EXTREMELY_IMPORTANT>"

# ---------------------------------------------------------------------------
# Output — same dual-shape as session-start.sh for maximum compatibility
# ---------------------------------------------------------------------------
cat <<EOF
{
  "additional_context": "${session_context}",
  "hookSpecificOutput": {
    "hookEventName": "SessionStart",
    "additionalContext": "${session_context}"
  }
}
EOF

exit 0
