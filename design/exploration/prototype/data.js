// SAMPLE DATA — not real user data, not read from the app.
// Fixture matches design/exploration/TODAY_CONCEPTS.md: Saturday, October 3, 9:41 AM.
//
// Each habit carries a 13-character "past" ledger for Sun Sep 20 → Fri Oct 2,
// so the 14-day ledger (Sun Sep 20 → Sat Oct 3) is past + today.
//   d = done, m = missed, s = skipped (excused), . = no check-in (weekly habits; not a miss)
// Derived values (streaks, recovery, weekly counts) are computed by app.js with
// simplified versions of the documented rules in docs/DATA_MODEL.md. They are a
// prototype approximation of HabitProgressCalculator, not a port of it.

window.AvelaPrototype = window.AvelaPrototype || {};

window.AvelaPrototype.SAMPLE = {
  label: "Sample data · Saturday, October 3 · 9:41 AM",
  eyebrow: "Saturday, October 3",
  rangeLabel: "Sep 20 – Oct 3",
  weekStartIndex: 7, // index of Sun Sep 27 in the 14-day ledger

  base: [
    { id: "water", name: "Drink water", symbol: "drop.fill", category: "Health", polarity: "positive",
      schedule: { kind: "daily" }, doneToday: false, past: "ddmdddddmdddd", bestStreak: 9 },
    { id: "read", name: "Read", symbol: "book.fill", category: "Learning", polarity: "positive",
      schedule: { kind: "timesPerWeek", target: 3 }, doneToday: false, past: ".d.d.d..d..d.", weekStreakBefore: 4, bestWeeks: 6 },
    { id: "journal", name: "Journal", symbol: "pencil.line", category: "Mindfulness", polarity: "positive",
      schedule: { kind: "daily" }, doneToday: false, past: "dddmddsdddmdd", bestStreak: 12 },
    { id: "walk", name: "Morning walk", symbol: "figure.walk", category: "Fitness", polarity: "positive",
      schedule: { kind: "daily" }, doneToday: true, past: "dddddddmddddd", bestStreak: 7 },
    { id: "nophone", name: "No phone in bed", symbol: "iphone.slash", category: "Health", polarity: "avoidance",
      schedule: { kind: "daily" }, doneToday: true, past: "dmddmdddmdddd", bestStreak: 6 },
  ],

  // Added on top of `base` for the many-habit state (11 habits, 3 done).
  extra: [
    { id: "vitamins", name: "Vitamins", symbol: "pills.fill", category: "Health", polarity: "positive",
      schedule: { kind: "daily" }, doneToday: false, past: "dddmddddddddd", bestStreak: 14 },
    { id: "spanish", name: "Practice Spanish", symbol: "bubble.left.fill", category: "Learning", polarity: "positive",
      schedule: { kind: "timesPerWeek", target: 3 }, doneToday: false, past: "d.d.....d....", weekStreakBefore: 0, bestWeeks: 3 },
    { id: "call", name: "Call a friend", symbol: "phone.fill", category: "Social", polarity: "positive",
      schedule: { kind: "timesPerWeek", target: 1 }, doneToday: false, past: "...d.........", weekStreakBefore: 5, bestWeeks: 8 },
    { id: "floss", name: "Floss", symbol: "sparkles", category: "Health", polarity: "positive",
      schedule: { kind: "daily" }, doneToday: false, past: "ddmdddsddmddd", bestStreak: 10 },
    { id: "sugar", name: "No sugar after 8 PM", symbol: "nosign", category: "Health", polarity: "avoidance",
      schedule: { kind: "daily" }, doneToday: false, past: "dddmddddddddd", bestStreak: 11 },
    { id: "stretch", name: "Stretch", symbol: "figure.cooldown", category: "Fitness", polarity: "positive",
      schedule: { kind: "daily" }, doneToday: true, past: "mmddddddddddd", bestStreak: 12 },
  ],
};
