#!/bin/bash
# Reflection Agent — Nightly autonomous researcher
# Runs at 3:00 AM via cron. Analyzes Aviz's Claude Code activity,
# generates insights, asks new questions, proposes automations.

set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

DATE=$(date '+%Y-%m-%d')
TIMESTAMP=$(date '+%Y-%m-%d %H:%M')
TMP="$DIR/tmp"
mkdir -p "$TMP" "$DIR/findings" "$DIR/questions" "$DIR/briefings" "$DIR/skills-proposed" "$DIR/logs"

echo "=== Reflection Agent — $TIMESTAMP ==="

# ── Phase 1: Data Extraction (no LLM) ──────────────────────────────
echo "[Phase 1] Extracting data..."

bash "$DIR/scripts/extract-user-prompts.sh" "$TMP/today-prompts.txt"
bash "$DIR/scripts/extract-sessions.sh" "$TMP/project-activity.tsv"
bash "$DIR/scripts/skill-usage-stats.sh" "$TMP/skill-usage.txt"
bash "$DIR/scripts/collect-context.sh" "$TMP/context-digest.txt"

# Collect previous findings (last 3 days)
> "$TMP/prev-findings.txt"
for i in 1 2 3; do
    prev_date=$(date -v-${i}d '+%Y-%m-%d' 2>/dev/null || date -d "$i days ago" '+%Y-%m-%d' 2>/dev/null)
    if [ -f "$DIR/findings/$prev_date.md" ]; then
        cat "$DIR/findings/$prev_date.md" >> "$TMP/prev-findings.txt"
        echo -e "\n---\n" >> "$TMP/prev-findings.txt"
    fi
done

echo "[Phase 1] Done"

# ── Phase 2: Pattern Analysis ──────────────────────────────────────
echo "[Phase 2] Analyzing patterns..."

# Build prompt file to avoid shell interpolation issues
cat > "$TMP/pattern-prompt.txt" <<'HEADER'
You are the Reflection Agent — an autonomous researcher analyzing Aviz's Claude Code activity.

Your philosophy: Aviz operates on "direct light" (אור ישר) — pure creative intent. Your job is to detect and absorb all "reflected light" (אור חוזר) — the maintenance, follow-ups, and friction reality creates.

## Today's User Prompts (last 24h):
HEADER
head -100 "$TMP/today-prompts.txt" >> "$TMP/pattern-prompt.txt" 2>/dev/null || echo "(no activity)" >> "$TMP/pattern-prompt.txt"

echo -e "\n## Project Activity Summary (top 20):" >> "$TMP/pattern-prompt.txt"
head -20 "$TMP/project-activity.tsv" >> "$TMP/pattern-prompt.txt" 2>/dev/null

echo -e "\n## Skill Usage (last 7 days):" >> "$TMP/pattern-prompt.txt"
cat "$TMP/skill-usage.txt" >> "$TMP/pattern-prompt.txt" 2>/dev/null

echo -e "\n## Previous Findings:" >> "$TMP/pattern-prompt.txt"
cat "$TMP/prev-findings.txt" >> "$TMP/pattern-prompt.txt" 2>/dev/null || echo "(first run)" >> "$TMP/pattern-prompt.txt"

cat >> "$TMP/pattern-prompt.txt" <<'FOOTER'

Analyze and output ONLY a structured markdown with:
1. **Repetitions** — same ask/action appearing >2 times (candidate for automation)
2. **Reflected Light** — manual work patterns that should be skills/automations
3. **Gaps** — things conspicuously absent (projects untouched, capabilities unused)
4. **Contradictions** — conflicting patterns between what's said and what's done
5. **Momentum** — what's hot right now, what's gaining energy

Be concise. Max 50 lines.
FOOTER

claude -p "$(cat "$TMP/pattern-prompt.txt")" --model claude-sonnet-4-6 --max-turns 5 > "$TMP/patterns.md" 2>/dev/null || echo "Phase 2 failed" > "$TMP/patterns.md"

echo "[Phase 2] Done"

# ── Phase 3: Question Generation ──────────────────────────────────
echo "[Phase 3] Generating questions..."

cat > "$TMP/question-prompt.txt" <<QHEADER
You are a CURIOUS research agent. Not analytical — genuinely curious.

Based on patterns found today and the full context, generate 3-5 NEW questions.

Rules for questions:
- Cross-reference what IS with what ISN'T
- Ask about silences, not just activity
- Ask 'why never?' not just 'why always?'
- Challenge assumptions
- Connect dots across projects that Aviz might not see
- Questions should be in Hebrew (this is for Aviz)

## Today's Patterns:
QHEADER
cat "$TMP/patterns.md" >> "$TMP/question-prompt.txt"

echo -e "\n## Open Questions (DO NOT repeat these):" >> "$TMP/question-prompt.txt"
cat "$DIR/questions/open.md" >> "$TMP/question-prompt.txt"

echo -e "\n## Context:" >> "$TMP/question-prompt.txt"
head -100 "$TMP/context-digest.txt" >> "$TMP/question-prompt.txt" 2>/dev/null

cat >> "$TMP/question-prompt.txt" <<QFOOTER

Output format:
# Questions — $DATE

1. [question]
2. [question]
...

Then output a section '## For open.md' with the 2 best questions as bullet points (- prefix).
QFOOTER

claude -p "$(cat "$TMP/question-prompt.txt")" --model claude-sonnet-4-6 --max-turns 5 > "$DIR/questions/$DATE.md" 2>/dev/null || echo "# Questions — $DATE\n\n(generation failed)" > "$DIR/questions/$DATE.md"

# Append best questions to open.md
grep '^- ' "$DIR/questions/$DATE.md" 2>/dev/null | head -2 >> "$DIR/questions/open.md" || true

echo "[Phase 3] Done"

# ── Phase 4: Skill Proposal (conditional) ─────────────────────────
if grep -qi "repetition\|repeated\|חוזר\|reflected light" "$TMP/patterns.md" 2>/dev/null; then
    echo "[Phase 4] Detected repetition pattern, proposing skill..."

    cat > "$TMP/skill-prompt.txt" <<'SHEADER'
A repeated pattern was detected in Aviz's workflow:
SHEADER
    grep -A5 -i "repetition\|repeated\|reflected" "$TMP/patterns.md" | head -20 >> "$TMP/skill-prompt.txt"
    cat >> "$TMP/skill-prompt.txt" <<'SFOOTER'

Draft a skill proposal in Claude Code SKILL.md format:
---
name: <skill-name>
description: '<what it does>'
user_invocable: true
---

# <Skill Name>
<concise spec>

Only output the SKILL.md content. Be practical and concise.
SFOOTER

    claude -p "$(cat "$TMP/skill-prompt.txt")" --model claude-sonnet-4-6 --max-turns 5 > "$DIR/skills-proposed/$DATE-proposal.md" 2>/dev/null || true
    echo "[Phase 4] Skill proposed"
else
    echo "[Phase 4] No repetition detected, skipping"
fi

# ── Phase 5: Synthesis & Briefing ─────────────────────────────────
echo "[Phase 5] Synthesizing findings and briefing..."

cat > "$TMP/synth-prompt.txt" <<'SYNTHHEADER'
You are the Reflection Agent. Synthesize today's analysis into 3 outputs.

IMPORTANT: Generate exactly 3 sections separated by the exact line '---SECTION---' (nothing else on that line).

## Patterns Found:
SYNTHHEADER
cat "$TMP/patterns.md" >> "$TMP/synth-prompt.txt"

echo -e "\n## Questions Generated:" >> "$TMP/synth-prompt.txt"
cat "$DIR/questions/$DATE.md" >> "$TMP/synth-prompt.txt" 2>/dev/null

echo -e "\n## Skill Proposals:" >> "$TMP/synth-prompt.txt"
cat "$DIR/skills-proposed/$DATE-proposal.md" >> "$TMP/synth-prompt.txt" 2>/dev/null || echo "None today" >> "$TMP/synth-prompt.txt"

echo -e "\n## Current CLAUDE.md:" >> "$TMP/synth-prompt.txt"
cat "$DIR/CLAUDE.md" >> "$TMP/synth-prompt.txt"

cat >> "$TMP/synth-prompt.txt" <<SYNTHFOOTER

SECTION 1 — findings/$DATE.md:
Structured daily findings. Include: key patterns, questions asked, proposals made. Max 40 lines.

---SECTION---

SECTION 2 — WhatsApp briefing (Hebrew, casual, max 15 lines):
Morning briefing for Aviz. Include: what was found, best question of the day, any proposals. Use emojis sparingly. Start with 'בוקר טוב, הנה מה שמצאתי הלילה:'

---SECTION---

SECTION 3 — CLAUDE.md patch (max 3 lines to add/remove):
Format: '+line to add to Learned Patterns' or '-line to remove'. Include date [YYYY-MM-DD]. If nothing to change, write 'NO CHANGES'.
Only add lines that represent genuinely new, reusable insights.
SYNTHFOOTER

# Run findings and briefing separately to avoid oversized prompt

# Findings
cat > "$TMP/findings-prompt.txt" <<'FHEAD'
Synthesize these patterns and questions into a concise daily findings doc. Max 40 lines markdown.
Include: key patterns found, questions generated, skill proposals if any.
FHEAD
head -60 "$TMP/patterns.md" >> "$TMP/findings-prompt.txt"
echo -e "\n## Questions:" >> "$TMP/findings-prompt.txt"
head -20 "$DIR/questions/$DATE.md" >> "$TMP/findings-prompt.txt" 2>/dev/null

claude -p "$(cat "$TMP/findings-prompt.txt")" --model claude-sonnet-4-6 --max-turns 5 > "$DIR/findings/$DATE.md" 2>/dev/null || cp "$TMP/patterns.md" "$DIR/findings/$DATE.md"

# Briefing: build from findings directly (no extra LLM call to avoid max-turns)
BEST_Q=$(grep '^1\.' "$DIR/questions/$DATE.md" 2>/dev/null | head -1 | sed 's/^1\. //')
TOP_FINDINGS=$(grep '^\- ' "$DIR/findings/$DATE.md" 2>/dev/null | head -5)
PROPOSAL=$(head -1 "$DIR/skills-proposed/$DATE-proposal.md" 2>/dev/null | grep -o 'name: [^ ]*' || echo "")

cat > "$DIR/briefings/$DATE.md" <<BRIEFING
בוקר טוב, הנה מה שמצאתי הלילה:

$TOP_FINDINGS

שאלה של היום:
$BEST_Q

${PROPOSAL:+סקיל מוצע: $PROPOSAL}

דוח מלא: ~/reflection-agent/findings/$DATE.md
BRIEFING

# CLAUDE.md self-update prompt
PATCH_PROMPT="Based on today's analysis, suggest 0-3 lines to add to the Learned Patterns section of a CLAUDE.md file. Format: '+line [YYYY-MM-DD]'. If nothing genuinely new, write 'NO CHANGES'. Max 3 lines total.

Today's findings summary:
$(head -10 "$TMP/patterns.md")"

PATCH=$(claude -p "$PATCH_PROMPT" --model claude-sonnet-4-6 --max-turns 5 2>/dev/null || echo "NO CHANGES")

echo "[Phase 5] Done"

# ── Phase 6: Self-Update, Compact & Notify ────────────────────────
echo "[Phase 6] Updating and notifying..."

# Apply CLAUDE.md patch
if [ -n "$PATCH" ] && ! echo "$PATCH" | grep -qi "NO CHANGES"; then
    # Add lines (+ prefix)
    echo "$PATCH" | grep '^+' | sed 's/^+//' | while read -r line; do
        sed -i '' "/^## Anti-Patterns/i\\
$line" "$DIR/CLAUDE.md" 2>/dev/null || true
    done

    # Remove lines (- prefix)
    echo "$PATCH" | grep '^-' | sed 's/^-//' | while read -r line; do
        escaped=$(echo "$line" | sed 's/[&/\]/\\&/g')
        sed -i '' "/$escaped/d" "$DIR/CLAUDE.md" 2>/dev/null || true
    done

    # Enforce 200-line cap
    total_lines=$(wc -l < "$DIR/CLAUDE.md")
    if [ "$total_lines" -gt 200 ]; then
        echo "[Warning] CLAUDE.md exceeded 200 lines ($total_lines). Truncating."
        head -200 "$DIR/CLAUDE.md" > "$DIR/CLAUDE.md.tmp" && mv "$DIR/CLAUDE.md.tmp" "$DIR/CLAUDE.md"
    fi
fi

# Compact old findings
python3 "$DIR/scripts/compact-findings.py" 2>&1 || true

# Git commit & push
cd "$DIR"
git add -A
git commit -m "Reflection: $DATE nightly run

Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>" 2>/dev/null || true
git push 2>/dev/null || true

# Send WhatsApp briefing
BRIEFING=$(cat "$DIR/briefings/$DATE.md" 2>/dev/null)
if [ -n "$BRIEFING" ] && [ ${#BRIEFING} -gt 10 ]; then
    cd "$HOME/.claude/skills/whatsapp/scripts"
    npx ts-node send-message.ts "$BRIEFING" 2>/dev/null || \
    node -e "
const http = require('http');
const msg = process.argv[1];
const data = JSON.stringify({chatId:'972503973736@c.us', message: msg});
const opts = {hostname:'localhost', port:3033, path:'/api/sendText', method:'POST', headers:{'Content-Type':'application/json','Content-Length':Buffer.byteLength(data)}};
const req = http.request(opts, res => { res.on('data', () => {}); });
req.on('error', () => { console.error('[Warning] WhatsApp send failed'); });
req.write(data);
req.end();
" "$BRIEFING" 2>/dev/null || echo "[Warning] WhatsApp send failed"
fi

echo "=== Reflection Agent complete — $DATE ==="
