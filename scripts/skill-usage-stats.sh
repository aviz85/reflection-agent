#!/bin/bash
# Count skill invocations from recent history
# Output: tmp/skill-usage.txt

OUTPUT="${1:-tmp/skill-usage.txt}"
PROJECTS_DIR="$HOME/.claude/projects"
SKILLS_DIR="$HOME/.claude/skills"

> "$OUTPUT"

echo "=== Skills Invoked (last 7 days) ===" >> "$OUTPUT"

# Get list of all skill names
skill_names=$(ls -1 "$SKILLS_DIR" 2>/dev/null | grep -v README.md | grep -v node_modules)

# Find JSONL files modified in last 7 days
recent_jsonls=$(find "$PROJECTS_DIR" -maxdepth 2 -name "*.jsonl" -mtime -7 2>/dev/null)

for skill in $skill_names; do
    count=$(echo "$recent_jsonls" | xargs grep -l "\"skill\":\"$skill\"\|/$skill\"\|\"name\":\"$skill\"" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$count" -gt 0 ]; then
        echo "$count\t$skill" >> "$OUTPUT"
    fi
done

# Sort by count descending
sort -rn "$OUTPUT" -o "${OUTPUT}.tmp"
echo "=== Skills Invoked (last 7 days) ===" > "$OUTPUT"
cat "${OUTPUT}.tmp" >> "$OUTPUT"
rm -f "${OUTPUT}.tmp"

echo "" >> "$OUTPUT"
echo "=== Installed Skills ($(echo "$skill_names" | wc -w | tr -d ' ')) ===" >> "$OUTPUT"
echo "$skill_names" | tr '\n' ', ' >> "$OUTPUT"
echo "" >> "$OUTPUT"

echo "" >> "$OUTPUT"
echo "=== Archived Skills ===" >> "$OUTPUT"
ls -1 "$HOME/.claude/skills-archive/" 2>/dev/null | wc -l | tr -d ' ' >> "$OUTPUT"

echo "Skill usage stats generated" >&2
