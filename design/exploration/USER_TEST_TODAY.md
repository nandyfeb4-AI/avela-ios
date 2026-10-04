# Today side-by-side preference and comprehension test

This is a short moderated test. It checks whether people **understand** each
Today concept before asking which one they **prefer**. Preference without
comprehension is not a reason to pick a design, and neither are the design
team's own scores in TODAY_CONCEPTS.md.

## Setup

- **Format:** remote or in person, moderated, think-aloud. About 20 minutes
  per participant.
- **Stimuli:** single-screen PNGs in `mockups/png/`, shown on a real iPhone
  and opened full-screen from Photos, so text renders at true size. These
  versions have the "not built" outlines removed and use identical data
  (including the implemented "success logged" wording):

| Label | File | What it is |
|---|---|---|
| T | `today-test-T-tidewater.png` | Tidewater baseline |
| 1 | `today-test-1-action.png` | Action-first |
| 2 | `today-test-2-balance.png` | Balance |
| 3 | `today-test-3-companion.png` | Companion-led |

  For participants who use large text, add `today-test-2-balance-ax3.png`
  and `today-test-T-tidewater-ax3.png`.
- **Tell every participant** that it's a picture, nothing is tappable, and
  some parts (attention tracking, the character) are ideas not yet built.
  Say it the same way each time.
- **Participants:** 6–8 per round. Recruit from VISION.md's primary user:
  - iPhone user;
  - either uses or has tried a habit tracker, or says they feel pulled into
    social, news or video;
  - at least 2 participants who use larger text or bold text;
  - no designers or developers, no one who has seen Avela.
- **Order:** counterbalance the screen order with a Latin square (4 orders),
  so no concept is always seen first:

| Order | Sequence |
|---|---|
| a | T, 1, 2, 3 |
| b | 1, 3, T, 2 |
| c | 2, T, 3, 1 |
| d | 3, 2, 1, T |

## Script

### Part A · Each screen alone (repeat for all four, in the assigned order; about 3 minutes each)

1. **Five-second look, then hide the screen.** Ask: "What was that screen
   for? What do you remember?"
2. **Show it again.** Ask: "It's Saturday morning. What would you tap
   first?" Record the **first touch point**.
3. **Comprehension.** Use the same questions on every screen. The correct
   answers come from the shared fixture.

| # | Question | Correct answer |
|---|---|---|
| a | "How many habits are left today?" | 3 |
| b | "Is anything here 'not going well'? What?" | Journal is recovering, framed as progress. Listen for "failing", "behind", "broken". |
| c | "How is your social media time today?" | 18 of 30 min, on track. "Can't tell" is a valid observation for T and 3. |
| d | "Where would you add 10 more minutes of social media?" | Point and narrate. Count the steps they expect. |
| e | "You marked Morning walk done by mistake. Fix it." | Point and narrate. Probes the collapsed Done group in concepts 1 and 2. |
| f | **Concept 1 only:** "What happens if you tap 'Not now'?" | |
| f | **Concept 3 only:** "Who is saying this sentence? How does it make you feel?" | |

### Part B · Side by side (about 4 minutes)

Lay out all four screens in a random arrangement, not in the test order.

4. "Which one would you want to open every morning? Why?" Then ask for
   second place.
5. "Which one feels most like it's judging you, if any?"
6. "Which one makes it clearest *what to do next*? Which makes it clearest
   *how your day is going*?" These two questions are separate on purpose.

### Part C · Debrief (about 2 minutes)

7. "Was there anything you expected to be able to do but couldn't see how?"
8. **Concept 2 only:** "What does 'On track' refer to?" Watch for people
   who think it covers habits as well as attention.

## What to record

| Measure | How |
|---|---|
| Comprehension score | Questions 3a–3c correct, per screen (0–3) |
| First touch | Whether the first tap was a logging control (yes/no), and which one |
| Find-and-act | Steps the participant expects for 3d and 3e, compared with the actual tap counts in TODAY_CONCEPTS |
| Judgement words | Any of: failing, behind, broken, guilty, nagging, childish |
| Preference | First and second choice, and the participant's **reason**, verbatim |

## How to read results

These are decision rules, agreed before running the test.

**Adopt Tidewater Balance (concept 2) if all of the following hold:**

- Mean comprehension is ≥ 2.5/3, and not lower than Tidewater's.
- At least 6 of 8 participants find the attention logging spot without help
  (question 3d).
- No more than 1 participant misreads "On track" as covering habits
  (question 8).

**Reconsider the collapsed Done group** if 3 or more participants can't find
how to undo Morning walk (question 3e). The fallback is Tidewater's visible
Done card.

**Revisit concept 3's companion voice** (not its layout) if it is the most
preferred *and* comprehension is equal. Treat it as a reason to pull the
companion sentence forward, not to adopt the band.

**Revisit concept 1's next-up hero** only if participants consistently can't
say what to do first in concept 2 (question 6), *and* product approves a
next-up rule.

**Discard any concept that 2 or more participants call judgmental**
(question 5), whatever its preference rank.

## Limits

This test uses static frames. It **cannot** measure:

- the real tap effort;
- motion, haptics, or the undo-toast timing;
- VoiceOver behaviour.

Plan a clickable prototype or TestFlight pass for those after a direction
is chosen.

8 participants show patterns, not proportions. Report quotes alongside the
counts. Don't turn this into a percentage-preference headline.
