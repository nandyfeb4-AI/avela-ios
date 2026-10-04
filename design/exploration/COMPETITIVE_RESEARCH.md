# Competitive UX research — Streaks, Habitify, Opal, Finch, Structured, Things 3

Accessed 2026-10-03. This is exploration material, not product scope;
`docs/MVP.md` stays the scope contract.

## Method and evidence rules

- **Sources.** Official sources come first: US App Store listing pages, the
  iTunes Lookup API, developer websites, official help centers and blogs,
  and Apple Design Award pages. Third-party press was not used for any
  claim below.
- **Screenshots.** The current iPhone screenshots on each App Store listing
  were downloaded to a temporary scratch folder outside the repository and
  viewed one by one. They are **not** committed, because they are
  third-party copyrighted material. Each one is described in
  "Annotated references" below so it can be re-checked against the live
  listing.
- **Labels.** **Observed** means seen in a current screenshot or stated in
  an official document (URL given). **Inference** means our
  interpretation. **Self-reported** means a number the company states about
  itself that we have not checked independently.
- **Popularity.** Popularity is shown only with App Store rating counts and
  averages, Editors' Choice badges, chart positions and Apple Design Award
  listings. No downloads, revenue or MAU figures are claimed.
- **Not covered.** Animations, haptics and completion transitions can't be
  seen in stills. Where official docs don't describe them, this document
  says "unverified".

## Popularity evidence (US App Store, 2026-10-03)

| App | Rating | Badges on listing | Apple awards (verified) | Source |
|---|---|---|---|---|
| Finch | 4.9 · 758,981 ratings | Editors' Choice; #13 Health & Fitness | — | [listing](https://apps.apple.com/us/app/finch-self-care-pet/id1528595748) |
| Structured | 4.8 · 166,953 ratings | Editors' Choice | App Store Awards *Finalist* (badge in the developer's own screenshot); no Apple Design Award found | [listing](https://apps.apple.com/us/app/structured-daily-planner-todo/id1499198946) |
| Opal | 4.7 · 89,012 ratings | Editors' Choice; #88 Productivity | 2025 Apple Design Award **finalist**, Social Impact (the winner was Watch Duty) | [listing](https://apps.apple.com/us/app/opal-screen-time-control/id1497465230), [ADA 2025](https://developer.apple.com/design/awards/2025/) |
| Things 3 | 4.8 · 27,984 ratings | Editors' Choice | Apple Design Award 2009 and 2017 | [listing](https://apps.apple.com/us/app/things-3/id904237743), [2009](https://culturedcode.com/things/blog/2009/06/things-wins-apple-design-award-2009/), [2017](https://culturedcode.com/things/blog/2017/06/back-from-wwdc/) |
| Streaks | 4.8 · 27,349 ratings | Editors' Choice; #1 Health & Fitness chart badge | Listing says "Apple Design Award winner"; the year was **not** verified on an Apple page | [listing](https://apps.apple.com/us/app/streaks/id963034692) |
| Habitify | 4.6 · 7,138 ratings | none shown | — | [listing](https://apps.apple.com/us/app/habitify-habit-tracker/id1111447047) |

Self-reported figures, listed for completeness and **not** used in any
argument:

- **Structured:** "Trusted by 1.5 million active users".
- **Habitify:** "3M+ people".
- **Opal:** "4.9 / 150K+ ratings" and "500 million hours" in its own
  screenshot. Neither matches the US listing.
- **Finch:** "500k+ ratings, 5.0" on its website.

Opal's screenshot laurel reads like an award win; Apple's own page lists it
as a finalist.

## Comparison matrix

| Dimension | Streaks | Habitify | Opal | Finch | Structured | Things 3 |
|---|---|---|---|---|---|---|
| **Hierarchy** | *Obs:* No title; a 2×3 paged grid of task rings is the whole screen. | *Obs:* "TODAY" eyebrow, large title, filter chips, then rows; done items collapse into "Success". | *Obs:* One hero metric per screen (dial, timer or insight sentence), then a comparison, then one CTA. | *Obs:* Pet scene takes ≥50% of the screen, then a status pill, a count headline and goal rows. | *Obs:* Date header, a week strip with task-color dots, then a vertical timeline. | *Obs:* "★ Today" large title, an events card, to-dos, then a separate "This Evening" section. |
| **Typography** | *Obs:* Heavy ALL-CAPS condensed labels, big numerals. *Inf:* custom or condensed face. | *Inf:* System-like in app; heavy display face in marketing. | *Obs:* Big bold numerals, tracked small-caps labels, LCD timer face. | *Obs:* Heavy rounded sans. | *Inf:* SF Pro; bold titles, grey time ranges. | *Inf:* SF Pro, with standard large title, semibold and caption roles. |
| **Icons** | *Obs:* Solid white glyphs on color; "over 600 task icons". *Inf:* custom. | *Obs:* Pastel round badges. *Inf:* SF Symbols. | *Obs:* Monochrome line glyphs on dark glass. | *Obs:* Full-color emoji per goal. | *Official:* Many icons are SF Symbols, plus Icons8 app logos and custom icons ([blog](https://structured.app/blog/structured-2-3)). | *Obs:* Custom multi-color list glyphs; simple line marks inline. |
| **Spacing & density** | *Obs:* Very low; about 6 items per screen. | *Obs:* Medium-high; cards and chips. | *Obs:* Low; frosted cards. | *Obs:* Medium; large rounded cards. | *Obs:* Airy, with rainbow color coding. | *Obs:* Generous rows, hairline separators, sparse color. |
| **Interaction feedback** | *Official (sibling app Little Streaks):* tap-hold fills the ring; shake to undo ([guide](https://crunchybagel.com/getting-started-with-little-streaks/)). Control Center actions ([Streaks 10](https://crunchybagel.com/now-available-streaks-10/)). | *Obs:* Row actions adapt to habit type (Done / +1 / Log); Skip lives in "…". | *Official:* "Hold to Commit"; a "Waiting Room" adds friction before unblocking ([help](https://help.opalapp.com/article/how-to-choose-your-waiting-room)). | *Obs:* Confetti and cheering; you can pet the bird ([help](https://help.finchcare.com/hc/en-us/articles/37780000231309)). | *Official:* Drag to reschedule ([help](https://help.structured.app/en/articles/1990594)). | *Official:* "Everything… nicely animated", custom animation toolkit, haptic feedback, Magic Plus drag ([features](https://culturedcode.com/things/features/)). |
| **Progress** | *Obs:* Rings, current and best streak, all-time %, line charts, weekday and hour charts, dot calendar with × for a miss. | *Obs:* Heatmap; "Average Daily Score 72.3%"; Nothing / Partial / Perfect counts; flame plus number. | *Obs:* Weekly dial "1h 23m LESS THAN USUAL"; Focus Score; streaks; gems. | *Obs:* Energy ⚡ per goal; pet adventures; currency. | *Obs:* Timeline position; widget "in 15 min". | *Obs:* Small progress pie per project. |
| **Recovery language** | *Official:* "Don't break the chain, or your streak will reset to zero days" ([site](https://streaks.app)). Weekly-goal tasks show "missed" without breaking the streak ([Streaks 5](https://crunchybagel.com/streaks-5-now-available/)). | *Official:* Skip means "not doing this habit today, but… not failing it either"; Off Mode protects streaks ([help](https://intercom.help/habitify-app/en/articles/11597864-3-ways-to-pause-or-cut-off-your-habits)). Still uses a "Fail" state. | *Obs:* Block screen says "You set this rule yesterday. Past you was right." *Official:* An opt-in "Brutal Insults" pack exists ([help](https://help.opalapp.com/article/how-to-choose-your-block-screens)). | *Official:* Streak repair costs Rainbow Stones; streaks count app opens ([help](https://help.finchcare.com/hc/en-us/articles/37780736136205)); Pause Mode "paused and preserved". | *Official:* "Replan" lets you decide what to do with unfinished tasks (Reschedule / Inbox / Check off / Delete) ([blog](https://structured.app/blog/replan)). Tagline: "Never miss a task again!" | *Official:* Deadline tasks "hop over to Today" with a countdown ([support](https://culturedcode.com/things/support/articles/2803579/)). |
| **Companion** | None | None | No character; a selectable "Gem" identity | Central pet that speaks ("Let's remind them…"); *Inf:* childlike default and a dependency framing ("take care of your pet by taking care of yourself") | None | None |
| **System surfaces** | Widgets (6 styles), Live Activity for timers, Watch, Control Center, Shortcuts | Widgets, Watch, Mac; "Live Activity Reminders"; App Intents and Siri | Live Activity only after a user starts a timer or unblock ([help](https://help.opalapp.com/article/how-do-i-enable-live-activities-for-opal)); widgets | Home Screen widget "what your Finch is currently up to"; no Live Activity documented | Live Activity requires an active Focus timer ([help](https://help.structured.app/en/articles/330626)); Watch; Shortcuts | Widgets, Watch, Shortcuts; no Live Activity found |

## What this means for Avela

**Patterns to adopt.** Each is a reference pattern, not a copy.

1. **Treat recovery as a decision.** Structured's Replan and Habitify's Skip
   and Off Mode frame a miss as a choice, not a failure. Avela already has
   the domain for this: excused skips, a 3-success recovery threshold, and
   archive periods. The UI should show it with neutral states: an excused
   skip, a "rebuilding" streak, and a dashed "today is still open" day. Copy
   must never say "Fail".
2. **Count weekly goals per week.** Streaks 5 and Habitify's weekly streaks
   both keep a weekly goal alive through a missed day. Avela's "2 of 3 this
   week" pips (Direction A) follow the same principle, with more calm than
   rings.
3. **Lead with one hero number, compared to the user's own baseline.**
   Opal's "less than usual" compares you with yourself. Avela's Insights
   hero is "82% · 6 points vs. the prior week", which matches the existing
   percentage-point rule in `docs/DATA_MODEL.md`.
4. **Use one restrained accent on a calm canvas,** as Things does: color
   only for state and identity, generous rows, hairline separators.
5. **Start Live Activities only from a user-started, time-bound session**
   (Opal, Structured). This matches `docs/APPLE_COMPLIANCE.md`.
6. **Use a small per-item progress glyph** (Things' project pie). Avela's
   capsule pips and 14-day ledger are the equivalent: readable at a glance,
   without a dashboard.

**Patterns to avoid, with the reason from Avela's docs:**

- **Reset-to-zero framing** ("Don't break the chain… reset to zero"), the
  flame-and-number streak, and "Fail" labels. These conflict with UX.md's
  "Do not show" list.
- **Companion dependency mechanics:** streaks that count app opens, repairs
  bought with currency, "take care of your pet". These conflict with
  DESIGN_SYSTEM.md ("not a guilt mechanism", "not a dependency cue") and
  VISION.md ("not a rewards-heavy RPG").
- **Childlike visual language by default** (Finch). This conflicts with
  UX.md's companion tone: "never childish by default".
- **Opt-in harsh copy or uncancellable modes** (Opal's "Brutal Insults",
  Deep Focus). They are guilt-adjacent and conflict with the compliance
  rule against manipulative patterns.
- **Rainbow color coding per item** (Structured). It depends on color alone
  and makes the screen busy.
- **Dense chart dashboards** (Streaks' stats page, Habitify's Progress
  page). UX.md says to avoid "dashboards that look like analytics
  software".

**Gaps no competitor fills.** These are where Avela can differentiate:

- A companion that is **calm, adult in tone, and driven only by real
  state**. Finch is driven by effort and currency.
- An attention budget **inside** a habit tracker, logged manually in V1,
  with a near-limit state that is amber rather than red. Opal is block-first.
- A weekly review written as plain sentences, with explicit honesty rules
  (cohort-matched trend, tie naming, never a fabricated 0%).

## Annotated references

Each entry: listing → what the current screenshot shows (**Observed**) →
what to take (**Inference**). Screenshot order is the listing's order on
2026-10-03 and may change.

**Streaks** — https://apps.apple.com/us/app/streaks/id963034692

1. **Today.** *Observed:* 2-column grid of large circular rings on a
   blue-to-magenta gradient, ALL-CAPS labels, paging dots. *Take:* the
   restraint of very few items. *Avoid:* the gradient and the poster
   typography; too loud for Avela.
2. **All Time stats.** *Observed:* big numerals (best streak, %,
   completions), line chart, weekday and hour bar charts. *Take:* weekday
   patterns are valued. *Avoid:* chart density.
3. **Add Task (Health).** *Observed:* grouped rows with type tabs.
4. **Widgets.** *Observed:* six styles, including a dot calendar with × for
   a miss. *Take:* a widget family that shares one visual primitive.
   *Avoid:* "×" for a miss; Avela uses a hollow ring.
5. **Live Activity.** *Observed:* timed task "PRACTICE GUITAR 18:56" with a
   pause button. *Take:* a session-only Live Activity.

**Habitify** — https://apps.apple.com/us/app/habitify-habit-tracker/id1111447047

1. **Marketing collage.** *Observed:* heatmap card with "🔥 33" and widget
   cards ("35/150 mins this week"). *Take:* weekly quantity text. *Avoid:*
   the flame.
2. **Progress.** *Observed:* Build/Break tabs, 28-day calendar with
   palm-tree Off Mode days, "Average Daily Score 72.3%". *Take:* a
   distinct icon for rest days. *Avoid:* the score label.
3. **Today inside ChatGPT.** *Observed:* Done / +1 / Log actions; a
   collapsed "1 Success" group. *Take:* the completion action adapts to the
   habit type.
4. **Health integrations picker.** Context only.
5. **Mac, iPhone, Watch.** *Observed:* "TODAY / My Journal" eyebrow plus
   title. *Take:* the eyebrow pattern, which Direction A also uses.

**Opal** — https://apps.apple.com/us/app/opal-screen-time-control/id1497465230

1. **Weekly dial.** *Observed:* "1h 23m LESS THAN USUAL", "Usually 4h 04m
   a day / This week 2h 41m a day". *Take:* the self-baseline comparison.
2. **Block screen.** *Observed:* "You set this rule yesterday. Past you was
   right." *Take:* reminding people of their own earlier intent is
   respectful friction. *Avoid:* reading the laurel as a win.
3. **Apps and Rules.** *Observed:* locked app icons and photo-backed rule
   cards. *Avoid:* photo cards in the content layer.
4. **Home.** *Observed:* wordmark, streak flame "20", Insights sentence
   card. *Take:* one-sentence insights.
5. **Timer.** *Observed:* LCD "29:59", stepper, glass "Start Timer".
   *Take:* the session model for a future phone-free Live Activity.

**Finch** — https://apps.apple.com/us/app/finch-self-care-pet/id1528595748

1. **Two birds hugging, "Self-care is better together".** Context only.
2. **Forest scene, about 55% of the screen, with a goal checklist.**
   *Observed:* the scene dominates. *Avoid:* that share of the screen on
   Today (Direction C tests a smaller version of this).
3. **Valentine stickers.** *Observed:* first-person-plural pet speech.
   *Avoid:* "us" framing that implies a relationship.
4. **"Adventuring · back in 7:36", "3 goals left today!", "5⚡" per goal.**
   *Avoid:* currency per goal.
5. **"You & Sam are now Goal Buddies!"** Social; out of scope for V1.

**Structured** — https://apps.apple.com/us/app/structured-daily-planner-todo/id1499198946

1. **Award badges collage.** Popularity context only.
2. **Timeline.** *Observed:* week strip with dots, color capsules sized by
   duration, ring checkboxes on the right. *Take:* a trailing ring
   completion control (Direction A). *Avoid:* rainbow coding.
3. **AI prompt "Reschedule my unfinished tasks…".** Out of scope (VISION
   non-goal: "not an AI chatbot").
4. **Widget "in 15 min · Designing".** *Take:* a glanceable "next" widget.
5. **Routine grid and recurrence picker.** Context for the schedule form.

**Things 3** — https://apps.apple.com/us/app/things-3/id904237743

1. **Home lists.** *Observed:* custom multi-color list glyphs; progress pies
   under Areas.
2. **Today.** *Observed:* events card, project subtitle per to-do, a
   "today" deadline flag, a separate This Evening section. *Take:* grouping
   by time of day (a future Avela idea, not V1).
3. **Upcoming.** *Observed:* drag to reschedule.
4. **Quick entry card.** *Observed:* compact sheet with an inline Save.
   *Take:* supports UX_AUDIT F4 (use an inline sheet title).
5. **Project with pie and Magic Plus mid-drag.** *Take:* one signature
   interaction is enough.

## Limitations

- No screenshot shows motion, so all animation and haptic notes are either
  quoted from official docs or marked unverified.
- Streaks' interaction details come from Crunchy Bagel's docs for its
  sibling app, Little Streaks; Streaks' own help is in-app only.
- Finch's help center blocks normal fetching, so its articles were read
  through the help center's public JSON article API. The widely repeated
  claim that the pet "never dies" was not found in an official source and
  is not used.
- App Store figures are US-storefront values for a single day.
