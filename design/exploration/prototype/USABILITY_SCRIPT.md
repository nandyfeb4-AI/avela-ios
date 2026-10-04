# Usability script — Tidewater Balance Today prototype (about 15 minutes)

This complements [`../USER_TEST_TODAY.md`](../USER_TEST_TODAY.md). That test
compares static concepts for comprehension. This one checks whether the
**interactions** work: completion, undo, grouping, detail, and the five
interaction risks.

## Setup

- **Device:** an iPhone, using mobile Safari with the local-network server
  from README.md. A laptop with a mouse is acceptable only for a pilot run.
- **Starting link:** `index.html?state=populated&regroup=deferred`. Leave
  `deferred` hidden, so participants see only built behaviour.
- **Screen:** keep the reviewer panel out of view. On a phone it sits below
  the device frame; on a laptop, cover it or zoom in.
- **Introduce it like this:** "This is a clickable sketch. Only the Today list
  and habit details work. Everything you see is example data. Please think
  out loud."
- **Participants:** 5–6, recruited with the screener from
  USER_TEST_TODAY.md. Include at least 1 person who uses larger text, and
  run their session at `text=xl` or `text=ax3`.
- **Recording:** the moderator records outcomes. The prototype's event log
  is a useful second record; screenshot it at the end of each session.

## Tasks

Say each task aloud. Don't point at controls.

1. **Complete one.** "You just drank a glass of water. Record that."
   - *Observe:* do they find the trailing circle? Do they tap the row name
     (which opens detail) instead?
2. **Quick succession.** "You've also journaled and read today. Record both,
   as fast as you'd normally do it."
   - *Observe:* does anything move while they tap? Does the second tap land
     on the intended habit? Do they notice the "moving to Done" text?
3. **Undo after the moment has passed.** Wait about 10 seconds so the toast
   expires, then say: "Actually, you didn't read today. Fix that."
   - *Observe:* do they find the Done group and expand it? Do they tap the
     filled control? Count the taps and the hesitation.
4. **Undo right away.** "Record Drink water again, and then change your mind
   immediately."
   - *Observe:* do they use the toast, or the control?
5. **Detail and back.** "Journal says 'Rebuilding'. Find out what that
   means, then come back."
   - *Observe:* do they understand "2 good days since your miss"? Do they
     return to the same place in the list?
6. **Many habits** (switch the link to `state=many`). "Here's a busier day.
   Record Floss."
   - *Observe:* scrolling, and whether the toast covers anything they need.
7. **Comprehension.** Point at "Done · 3": "What's in here? How would you
   see it?"

## Optional variant: risky baseline

Run task 2 again with `regroup=immediate&guard=off`. Ask: "Did that feel any
different?" Don't explain the difference beforehand.

## Debrief questions

- "Was there a moment where something moved or changed that you didn't
  expect?"
- "If you tapped something by mistake, how confident were you that you
  could fix it?"
- "Did anything here feel like it was judging you?"

## What counts as a problem

These thresholds were agreed before testing.

| Signal | Threshold | Likely change |
|---|---|---|
| Wrong habit logged in task 2 (deferred mode) | Any occurrence | Lengthen the settle period, or keep done rows in place until leaving Today |
| Can't undo in task 3 without help | 2 or more of 6 | Show Done expanded by default when it has 3 or fewer rows, or add an "Undo last" item |
| Opens detail when trying to complete (task 1) | 2 or more of 6 | Make the control larger or more visible; review hit areas |
| Loses their place after Back (task 5) | Any occurrence | Check the scroll restoration as well as focus |
| Says the toast blocked something (task 6) | Any occurrence | Revisit toast placement |

## Out of scope for this script

These need a native build: VoiceOver on iOS, real Dynamic Type, haptics,
SwiftUI animation timing, and the Liquid Glass tab bar. Don't draw
conclusions about them from this session.
