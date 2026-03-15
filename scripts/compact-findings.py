#!/usr/bin/env python3
"""Compact old findings into monthly summaries. Keep last 30 days as daily, older → monthly rollup."""

import os
import glob
from datetime import datetime, timedelta
from pathlib import Path
from collections import defaultdict

FINDINGS_DIR = Path.home() / "reflection-agent" / "findings"
COMPACTED_DIR = FINDINGS_DIR / "compacted"
QUESTIONS_FILE = Path.home() / "reflection-agent" / "questions" / "open.md"
MAX_OPEN_QUESTIONS = 30
KEEP_DAYS = 30

def compact_findings():
    cutoff = datetime.now() - timedelta(days=KEEP_DAYS)
    monthly = defaultdict(list)

    for f in sorted(FINDINGS_DIR.glob("????-??-??.md")):
        try:
            date = datetime.strptime(f.stem, "%Y-%m-%d")
        except ValueError:
            continue

        if date < cutoff:
            month_key = date.strftime("%Y-%m")
            monthly[month_key].append(f)

    for month, files in monthly.items():
        compacted_file = COMPACTED_DIR / f"{month}.md"
        content = f"# Findings — {month} (compacted)\n\n"
        for f in sorted(files):
            content += f"## {f.stem}\n\n"
            content += f.read_text()
            content += "\n\n---\n\n"

        compacted_file.write_text(content)
        print(f"Compacted {len(files)} files → {compacted_file}")

        for f in files:
            f.unlink()
            print(f"  Removed {f.name}")

def prune_open_questions():
    if not QUESTIONS_FILE.exists():
        return

    lines = QUESTIONS_FILE.read_text().strip().split("\n")
    # Keep header + last MAX_OPEN_QUESTIONS question lines
    header_lines = []
    question_lines = []

    for line in lines:
        if line.startswith("#") or line.startswith("---") or not line.strip():
            header_lines.append(line)
        else:
            question_lines.append(line)

    if len(question_lines) > MAX_OPEN_QUESTIONS:
        pruned = len(question_lines) - MAX_OPEN_QUESTIONS
        question_lines = question_lines[-MAX_OPEN_QUESTIONS:]
        print(f"Pruned {pruned} old questions from open.md")

    QUESTIONS_FILE.write_text("\n".join(header_lines + question_lines) + "\n")

if __name__ == "__main__":
    os.makedirs(COMPACTED_DIR, exist_ok=True)
    compact_findings()
    prune_open_questions()
    print("Compaction complete")
