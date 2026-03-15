#!/bin/bash
# Collect CLAUDE.md and MEMORY.md files for analysis
# Output: tmp/context-digest.txt

OUTPUT="${1:-tmp/context-digest.txt}"

> "$OUTPUT"

echo "=== Global CLAUDE.md ===" >> "$OUTPUT"
head -100 "$HOME/.claude/CLAUDE.md" 2>/dev/null >> "$OUTPUT"
echo "" >> "$OUTPUT"

echo "=== Memory Files ===" >> "$OUTPUT"
find "$HOME/.claude/projects" -name "MEMORY.md" -maxdepth 3 2>/dev/null | while read -r memfile; do
    project=$(echo "$memfile" | sed "s|$HOME/.claude/projects/||" | cut -d/ -f1)
    echo "--- $project ---" >> "$OUTPUT"
    head -50 "$memfile" 2>/dev/null >> "$OUTPUT"
    echo "" >> "$OUTPUT"
done

echo "=== SB Recent Notes (last 7 days) ===" >> "$OUTPUT"
find "$HOME/sb/notes" -name "*.md" -mtime -7 2>/dev/null | while read -r note; do
    name=$(basename "$note")
    echo "- $name" >> "$OUTPUT"
done

echo "=== SB Daily Notes (last 3 days) ===" >> "$OUTPUT"
for i in 0 1 2; do
    day=$(date -v-${i}d '+%Y-%m-%d' 2>/dev/null || date -d "$i days ago" '+%Y-%m-%d' 2>/dev/null)
    dayfile="$HOME/sb/daily/$day.md"
    if [ -f "$dayfile" ]; then
        echo "--- $day ---" >> "$OUTPUT"
        head -30 "$dayfile" >> "$OUTPUT"
        echo "" >> "$OUTPUT"
    fi
done

echo "Context digest generated" >&2
