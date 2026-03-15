# Reflection Agent

> An autonomous nightly researcher that analyzes your Claude Code activity, accumulates insights, generates questions no one asked, and proposes automations — so you can stay in "direct light" while it handles all the "reflected light."

## Philosophy: Direct Light / Reflected Light

**Direct light (אור ישר)** — What you want to do. Pure creative impulse, vision, intent.

**Reflected light (אור חוזר)** — What reality forces you to do. Maintenance, follow-ups, cleanup, the friction of getting things done.

This agent absorbs all reflected light. It runs at 3 AM, reads everything you did, finds patterns you can't see, asks questions you didn't think to ask, and proposes automations that eliminate friction. You wake up to a briefing. Over time, the reflected light shrinks to zero.

## What It Does

Every night at 3:00 AM:

1. **Extracts** — Pulls user prompts, project activity, skill usage, context from all Claude Code conversations
2. **Analyzes** — Identifies repetitions, inefficiencies, gaps, contradictions, momentum
3. **Questions** — Generates 3-5 NEW questions by cross-referencing what IS with what ISN'T
4. **Proposes** — When it detects repeated manual work, drafts a skill to automate it
5. **Synthesizes** — Produces daily findings + WhatsApp morning briefing
6. **Evolves** — Updates its own CLAUDE.md with learned patterns (hard-capped at 200 lines)
7. **Compacts** — Rolls up findings older than 30 days into monthly summaries

## Structure

```
reflection-agent/
├── CLAUDE.md              # Self-evolving instructions (200-line cap)
├── run.sh                 # Main orchestrator (cron entry point)
├── scripts/
│   ├── extract-user-prompts.sh    # Recent user messages
│   ├── extract-sessions.sh        # Project activity summary
│   ├── skill-usage-stats.sh       # Skill invocation counts
│   ├── collect-context.sh         # CLAUDE.md, memories, notes
│   └── compact-findings.py        # Monthly rollup + question pruning
├── findings/              # Daily findings (kept 30 days)
│   └── compacted/         # Monthly rollups
├── questions/
│   ├── open.md            # Persistent open questions (max 30)
│   └── YYYY-MM-DD.md      # Daily questions
├── briefings/             # WhatsApp morning briefings
│   └── YYYY-MM-DD.md
└── skills-proposed/       # Skill proposals (not auto-installed)
    └── YYYY-MM-DD-proposal.md
```

## The Questions

The most important output. Not analytics — **curiosity**.

The agent asks things like:
- "You have 16,843 Facebook posts and 0 blog posts. Why is the platform you don't control full while the one you own is empty?"
- "Every skill you build is output (send, publish, create). None are input (listen, read, absorb). Missing a side?"
- "3 projects started at 1 AM this week. You returned to 0 of them. What if you slept on it first?"

## Self-Evolution

CLAUDE.md evolves nightly but stays bounded:
- Each learned pattern has a date
- Lines >60 days without reconfirmation get pruned
- Hard cap: 200 lines — agent must remove low-value lines before adding new ones
- Anti-patterns section tracks things NOT to do

## Setup

Already configured. Cron runs at 3:00 AM daily:

```
0 3 * * * cd ~/reflection-agent && ./run.sh >> logs/run-$(date +\%Y\%m\%d).log 2>&1
```

## Manual Run

```bash
cd ~/reflection-agent && ./run.sh
```

## Cost

Uses Claude Sonnet for all phases (~3 API calls per run). Estimated cost: ~$0.10-0.30/night.

---

Built by Aviz + Claude Code. The agent that watches the agent that watches you.
