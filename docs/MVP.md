# V1 / MVP Product Contract

This file defines the V1 release boundary.

Every feature must be classified as:
- MUST SHIP
- POST-MVP
- EXPLICITLY OUT OF V1

No new feature may delay V1 unless this file is intentionally updated.

---

# MUST SHIP

## 1. Habit creation and lifecycle

Users can:
- create a habit
- edit a habit
- archive a habit
- reactivate an archived habit
- choose a name
- choose an icon
- choose a category
- choose habit polarity:
  - positive habit
  - avoidance habit

### Acceptance criteria
- New habit appears immediately in Today view when applicable.
- Editing a habit does not corrupt historical completion records.
- Archived habits disappear from active views but retain history.
- Historical records retain the habit configuration that applied at the time where necessary for accurate interpretation.

---

## 2. Scheduling

Supported schedule types:

### Daily
Example:
- Read every day

### Specific weekdays
Example:
- Exercise Monday, Wednesday, Friday

### Flexible weekly frequency
Example:
- Read 3 times per week

### Acceptance criteria
- Flexible weekly habits do not require weekday selection.
- Dashboard can show `2 / 3 this week`.
- Third valid completion satisfies the weekly target.
- Additional completions remain visible.
- Missing an individual day does not break a weekly-frequency commitment.
- Week boundaries use the user's local calendar/time zone.

---

## 3. Completion and history

Users can:
- complete a habit
- undo a completion
- skip when allowed
- view completion history

### Acceptance criteria
- Logging is one tap from Today view.
- Undo is available immediately after accidental logging.
- Completion timestamps are stored.
- History remains available after habit edits.
- Skip is distinct from failure.

---

## 4. Streaks and recovery

Track:
- current streak
- best streak
- consistency percentage
- recovery streak or recovery state

Recovery is a first-class concept.

Example:
- 11 of last 14 successful days
- 79% consistency
- 3-day recovery run

### Product rule
One miss should not make the product feel like all progress is lost.

### Acceptance criteria
- Daily habits calculate streaks correctly across local date boundaries.
- Flexible weekly habits use weekly success rather than arbitrary daily streak logic.
- Recovery messaging is neutral and encouraging.
- No shaming language.

---

## 5. Reminders

Users can:
- enable reminders per habit
- select reminder time
- disable reminders

### Acceptance criteria
- App requests notification permission only when user enables a reminder or from a clear onboarding step.
- App remains usable if permission is denied.
- Denial does not trigger repeated nagging.

---

## 6. Attention habits

V1 supports manually tracked attention goals.

Supported examples:
- Instagram <= 30 minutes/day
- YouTube <= 45 minutes/day
- News only after 6 PM
- No social media before 9 AM
- Phone-free first 30 minutes after waking

Supported goal families:

### Maximum duration
Example:
- Social media <= 30 minutes/day

### Protected time window
Example:
- No news before 9 AM

### Phone-free session / window
Example:
- Stay phone-free until 9 AM

### Data source
V1 must support:
- `manual`

Architecture must support future:
- `screenTime`

### Acceptance criteria
- User can enter usage manually.
- Daily attention goal state updates immediately.
- Historical entries retain actual usage.
- Changing today's goal does not rewrite previous historical goals.
- UI can represent healthy / near-limit / exceeded.

---

## 7. Weekly review

V1 weekly review includes:
- consistency percentage
- strongest habit
- weakest habit or habit needing recovery
- attention-budget success rate
- basic trend versus prior week
- most consistent day / weakest day where enough data exists

### Acceptance criteria
- Insights are derived from real local data.
- Do not fabricate correlations from insufficient data.
- Use plain language.
- Do not present causal claims.

---

## 8. Spirit-animal companion

V1 supports a limited companion system.

States:
- calm
- focused
- nearLimit
- overloaded
- recovering
- celebrating

Surfaces:
- Today dashboard
- Home Screen widget
- Lock Screen widget where practical

### Behavior
The companion reflects app state. It is not purely decorative.

Examples:
- calm when habits and attention are on track
- nearLimit when attention budget is approaching threshold
- overloaded when budget is exceeded
- recovering after a recent miss followed by renewed progress
- celebrating for meaningful completion events

### Acceptance criteria
- Companion state derives deterministically from user data.
- Companion never uses manipulative guilt.
- Animations respect Reduce Motion.

---

## 9. Widgets

V1 includes at least:
- compact habit progress widget
- attention-budget status widget

Target interactions:
- glanceable progress
- one-tap habit completion where supported by platform APIs

### Acceptance criteria
- Widget state is consistent with app state.
- Widget does not expose sensitive details unnecessarily.
- Empty states are intentional.

---

## 10. Live Activity

V1 may include Live Activity only for a real active session:
- phone-free until a specified time
- focus / protected-attention session

### Current V1 implementation
The optional Live Activity is included for explicitly started phone-free sessions.
A second, explicit "Show Session Activity" action opts into system presentation.
It displays the selected companion and timer on supported Dynamic Island and
Lock Screen surfaces. It never monitors phone use or records a result from time
elapsed. Protected recurring windows do not automatically create activities.

### Acceptance criteria
- Live Activity is time-bound.
- It is not used as a permanent virtual-pet surface.
- Ending the session updates the main app.

---

## 11. Onboarding

Required sequence:
1. Explain core value
2. Create first habit
3. Create first attention goal
4. Select companion
5. Offer reminder setup
6. Enter main dashboard

### Acceptance criteria
- User can complete onboarding without creating an account.
- User can skip nonessential steps.
- App becomes useful within a few minutes.

---

## 12. Monetization

V1 includes:
- free tier
- monthly subscription
- annual subscription
- StoreKit 2
- restore purchases
- premium entitlement checks

### Premium value candidates
Premium may unlock:
- unlimited habits
- advanced weekly insights
- expanded companion themes / states
- multiple attention budgets
- advanced widgets

Exact paywall packaging may evolve, but V1 must clearly explain what is free and what is paid.

### Acceptance criteria
- Purchase state is correctly restored.
- Core app does not become unusable if StoreKit is temporarily unavailable.
- No dark patterns.

---

## 13. Local-first persistence

Core functionality must work without network connectivity.

Persist:
- habits
- schedules
- completions
- skips
- attention budgets
- manual usage entries
- companion selection
- local preferences
- weekly derived metrics or data needed to recompute them

---

# POST-MVP

- automatic Screen Time metering
- iCloud / CloudKit sync
- Supabase backend
- cross-platform sync
- HealthKit
- richer behavioral correlations
- optional AI-generated coaching
- social / community features
- shared habits
- Android
- web app
- large companion environments
- advanced gamification
- remote feature flags if truly needed

---

# EXPLICITLY OUT OF V1

- medical advice
- mental-health diagnosis
- therapy claims
- parental surveillance
- hidden app blocking
- background data collection unrelated to product function
- ad network integration
- mandatory user accounts
