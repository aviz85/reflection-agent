#!/bin/bash
# Extract user prompts from JSONL files modified in the last 24 hours
# Output: tmp/today-prompts.txt (capped at 500 lines)

OUTPUT="${1:-tmp/today-prompts.txt}"
PROJECTS_DIR="$HOME/.claude/projects"
MAX_LINES=500

> "$OUTPUT"

# Find JSONL files modified in last 24h
find "$PROJECTS_DIR" -maxdepth 2 -name "*.jsonl" -mtime -1 2>/dev/null | while read -r jsonl; do
    project=$(basename "$(dirname "$jsonl")")
    session=$(basename "$jsonl" .jsonl)

    # Extract user messages with timestamps
    grep '"type":"user"' "$jsonl" 2>/dev/null | python3 -c "
import sys, json
for line in sys.stdin:
    try:
        msg = json.loads(line.strip())
        ts = msg.get('timestamp', '')[:19]
        content = msg.get('message', {}).get('content', '')
        if isinstance(content, list):
            texts = [b.get('text', '') for b in content if isinstance(b, dict) and b.get('type') == 'text']
            content = ' '.join(texts)
        if isinstance(content, str) and content.strip() and not msg.get('isMeta'):
            # Truncate to 200 chars
            c = content.strip().replace('\n', ' ')[:200]
            print(f'[$ts] [$project] {c}')
    except:
        pass
" project="$project" 2>/dev/null >> "$OUTPUT"
done

# Sort by timestamp, cap at MAX_LINES
sort -r "$OUTPUT" -o "$OUTPUT"
head -n $MAX_LINES "$OUTPUT" > "${OUTPUT}.tmp" && mv "${OUTPUT}.tmp" "$OUTPUT"

lines=$(wc -l < "$OUTPUT")
echo "Extracted $lines user prompts from last 24h" >&2
