#!/bin/bash
# Extract project activity summary
# Output: tmp/project-activity.tsv

OUTPUT="${1:-tmp/project-activity.tsv}"
PROJECTS_DIR="$HOME/.claude/projects"

echo -e "project\tsessions\tlast_modified\tsize_kb" > "$OUTPUT"

for dir in "$PROJECTS_DIR"/*/; do
    project=$(basename "$dir")
    sessions=$(find "$dir" -maxdepth 1 -name "*.jsonl" 2>/dev/null | wc -l | tr -d ' ')

    # Find most recent JSONL modification
    last_mod=$(find "$dir" -maxdepth 1 -name "*.jsonl" -exec stat -f '%m' {} \; 2>/dev/null | sort -rn | head -1)
    if [ -n "$last_mod" ]; then
        last_date=$(date -r "$last_mod" '+%Y-%m-%d' 2>/dev/null || echo "unknown")
    else
        last_date="no-sessions"
    fi

    # Total size
    size=$(du -sk "$dir" 2>/dev/null | cut -f1)

    echo -e "$project\t$sessions\t$last_date\t${size}KB" >> "$OUTPUT"
done

# Sort by last modified date descending
header=$(head -1 "$OUTPUT")
tail -n +2 "$OUTPUT" | sort -t$'\t' -k3 -r > "${OUTPUT}.tmp"
echo "$header" > "$OUTPUT"
cat "${OUTPUT}.tmp" >> "$OUTPUT"
rm "${OUTPUT}.tmp"

projects=$(tail -n +2 "$OUTPUT" | wc -l | tr -d ' ')
echo "Found $projects projects" >&2
