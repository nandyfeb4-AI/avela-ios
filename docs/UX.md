# UX Specification

## Navigation

Recommended primary structure:

- Today
- Insights
- History
- Settings

Habit creation can be presented modally.

## Today screen

Must show:
- companion
- today's habit list
- flexible weekly progress
- attention goal status
- fast logging actions

Priority order:
1. What should I do now?
2. How am I doing today?
3. What needs recovery?
4. What is my attention state?

## Information hierarchy

Avoid dashboards that look like analytics software.

Prefer:
- one primary state
- one next action
- one or two supporting metrics

## Habit card behavior

Each card should support:
- name
- icon
- current progress
- completion affordance
- schedule context where useful

Examples:
- `Read — 2/3 this week`
- `Walk — 4-day streak`
- `Instagram — 18/30 min`

## Attention states

Suggested thresholds for maximum-duration goals:
- healthy: < 70%
- near limit: 70% to < 100%
- exceeded: >= 100%

Thresholds should be centralized and configurable.

## Recovery UX

Do not show:
- "You failed"
- "Streak ruined"
- "Back to zero"

Prefer:
- "You’re rebuilding momentum"
- "3 good days since your miss"
- "11 of the last 14 days"

## Weekly review

Should read like a useful summary, not a spreadsheet.

Structure:
1. overall week
2. what went well
3. what needs recovery
4. attention-budget result
5. one practical observation

## Companion UX

Tone:
- calm
- warm
- intelligent
- never childish by default
- never sarcastic
- never guilt-based

Companion may offer brief prompts such as:
- "You’re close to today’s limit."
- "Three of four habits are done."
- "Sunday has been your hardest day lately."

Avoid fake human dependency cues.

## Accessibility

Must support:
- Dynamic Type
- VoiceOver labels
- sufficient touch targets
- Reduce Motion
- high contrast compatibility
- dark mode

## Empty states

Every empty state should explain:
- what this section is
- why it helps
- one clear next action

## Error states

Do not expose raw technical errors.

Store internal diagnostics separately from user-facing messaging.
