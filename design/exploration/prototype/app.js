// Avela · Tidewater Balance — browser prototype (design artifact, not production code).
// No dependencies. Classic script so it runs from file:// without a server.
(function () {
  "use strict";

  const P = window.AvelaPrototype;
  const icon = P.icon;
  const $ = (sel, root) => (root || document).querySelector(sel);

  // ---------------------------------------------------------------------------
  // Settings: URL parameters → reviewer panel. Defaults follow system preferences.
  // ---------------------------------------------------------------------------
  const q = new URLSearchParams(location.search);
  const mqDark = matchMedia("(prefers-color-scheme: dark)");
  const mqReduce = matchMedia("(prefers-reduced-motion: reduce)");
  const settings = {
    state: pick(q.get("state"), ["empty", "populated", "many"], "populated"),
    theme: pick(q.get("theme"), ["light", "dark"], mqDark.matches ? "dark" : "light"),
    text: pick(q.get("text"), ["default", "xl", "ax3"], "default"),
    motion: pick(q.get("motion"), ["system", "reduce", "full"], "system"),
    regroup: pick(q.get("regroup"), ["deferred", "immediate"], "deferred"),
    guard: q.get("guard") !== "off",
    deferred: q.get("deferred") === "show",
    symbols: q.get("symbols") === "show",
  };
  function pick(v, allowed, fallback) { return allowed.includes(v) ? v : fallback; }

  const TIMING = {
    settleMs: 1800,       // deferred regroup: quiet period after the last interaction in the list
    leaveMs: 400,         // …or this long after a mouse pointer leaves the list
    guardMs: 600,         // repeat-tap guard window on the same control
    toastMs: 5000,        // undo toast lifetime (paused while hovered/focused)
    noteMs: 2600,
  };

  // ---------------------------------------------------------------------------
  // Model
  // ---------------------------------------------------------------------------
  let habits = [];
  let doneExpanded = false;
  let regroupTimer = null, leaveTimer = null;
  let regroupPending = false, pointerInList = false, waitingForLeave = false;
  let toastTimer = null, toastRemaining = 0, toastStartedAt = 0, toastHabitId = null, toastPaused = false;
  let detailOrigin = null;

  function loadData() {
    const S = P.SAMPLE;
    const src = settings.state === "empty" ? [] : settings.state === "many" ? S.base.concat(S.extra) : S.base;
    habits = src.map((h, i) => Object.assign({}, h, { done: h.doneToday, group: h.doneToday ? "done" : "todo", order: i, lastToggle: -Infinity }));
    doneExpanded = false;
    clearRegroup();
  }

  const reduceMotion = () => settings.motion === "reduce" || (settings.motion === "system" && mqReduce.matches);

  // Simplified progress rules (see data.js header). Ledger = 13 past days + today.
  function cells(h) { return h.past.split("").concat([h.done ? "d" : "t"]); }

  function dailyStats(h) {
    const c = cells(h);
    let streak = 0;
    for (let i = h.done ? 13 : 12; i >= 0; i--) { if (c[i] === "d") streak++; else if (c[i] === "s") continue; else break; }
    let run = 0, best = 0;
    c.forEach((x) => { if (x === "d") { run++; best = Math.max(best, run); } else if (x === "m") run = 0; });
    const lastMiss = c.lastIndexOf("m");
    const since = lastMiss < 0 ? 0 : c.slice(lastMiss + 1).filter((x) => x === "d").length;
    const resolved = c.filter((x) => x === "d" || x === "m").length;
    const ok = c.filter((x) => x === "d").length;
    return { streak, best: Math.max(best, h.bestStreak || 0), recovering: lastMiss >= 0 && since < 3, since, ok, resolved,
             skips: c.filter((x) => x === "s").length, lastMiss };
  }

  function weeklyStats(h) {
    const c = cells(h), t = h.schedule.target, w = P.SAMPLE.weekStartIndex;
    const got = c.slice(w).filter((x) => x === "d").length;
    const prevMet = c.slice(0, w).filter((x) => x === "d").length >= t;
    const met = got >= t;
    return { got, target: t, met, streak: (h.weekStreakBefore || 0) + (met ? 1 : 0), best: Math.max(h.bestWeeks || 0, (h.weekStreakBefore || 0) + (met ? 1 : 0)),
             resolvedWeeks: 1 + (met ? 1 : 0), okWeeks: (prevMet ? 1 : 0) + (met ? 1 : 0) };
  }

  function context(h) {
    if (h.schedule.kind === "timesPerWeek") {
      const s = weeklyStats(h);
      const pips = '<span class="wk" aria-hidden="true">' + Array.from({ length: s.target }, (_, i) => '<span class="' + (i < s.got ? "on" : "") + '"></span>').join("") + "</span>";
      return { html: pips + (s.met ? "Goal met · " : "") + s.got + " of " + s.target + " this week", text: (s.met ? "goal met, " : "") + s.got + " of " + s.target + " this week", recovering: false };
    }
    const s = dailyStats(h);
    if (h.polarity === "avoidance") {
      const t = "Cut down · " + (h.done ? "success logged" : "not logged yet");
      return { html: t, text: t, recovering: false };
    }
    if (s.recovering) {
      const t = "Rebuilding · " + s.since + " of 3 good days";
      return { html: '<span class="rc">' + icon("arrow.clockwise", 14) + "</span>" + t, text: t, recovering: true };
    }
    const t = s.streak > 0 ? "Every day · " + s.streak + "-day streak" : "Every day";
    return { html: t, text: t, recovering: false };
  }

  // Wording mirrors the implemented HabitPolarityFormatter (Avela/Features/Habit/UI).
  const words = (h) => h.polarity === "avoidance"
    ? { act: "Log success for " + h.name, undo: "Undo success for " + h.name, toast: "Success logged for " + h.name, ax: "Log success", axDone: "Logged" }
    : { act: "Mark " + h.name + " complete", undo: "Undo completion for " + h.name, toast: h.name + " done", ax: "Mark done", axDone: "Done" };

  // ---------------------------------------------------------------------------
  // Logging (reviewer panel)
  // ---------------------------------------------------------------------------
  const logEl = $("#log");
  const t0 = performance.now();
  function log(msg, cls) {
    const li = document.createElement("li");
    if (cls) li.className = cls;
    li.innerHTML = '<span class="t">' + ((performance.now() - t0) / 1000).toFixed(1) + "s</span>" + msg;
    logEl.prepend(li);
    while (logEl.children.length > 60) logEl.lastChild.remove();
  }
  function announce(msg) { const a = $("#announcer"); a.textContent = ""; setTimeout(() => { a.textContent = msg; }, 30); }

  // ---------------------------------------------------------------------------
  // Rendering — Today
  // ---------------------------------------------------------------------------
  const phone = $("#phone");
  const todayBody = $("#today-body");
  const rowEls = new Map();

  function applySettings() {
    phone.classList.toggle("theme-dark", settings.theme === "dark");
    phone.classList.toggle("text-xl", settings.text === "xl");
    phone.classList.toggle("text-ax3", settings.text === "ax3");
    phone.classList.toggle("reduce-motion", reduceMotion());
    phone.classList.toggle("hide-deferred", !settings.deferred);
    phone.classList.toggle("show-symbols", settings.symbols);
    document.body.style.background = settings.theme === "dark" ? "#1B1C1E" : "#E4E2DC";
    $("#system-motion").textContent = "(system: " + (mqReduce.matches ? "reduce" : "full") + ")";
  }

  function renderChrome() {
    $("#eyebrow").textContent = P.SAMPLE.eyebrow;
    $("#add-btn").innerHTML = icon("plus", 22);
    $("#back-btn").innerHTML = icon("chevron.left", 22);
    $("#sample-tag").textContent = P.SAMPLE.label + " · " + (settings.state === "many" ? "11 habits" : settings.state === "empty" ? "no habits" : "5 habits") + " · icons approximate SF Symbols";
    const tabIcons = { Today: "sun.max.fill", Insights: "chart.bar.xaxis", History: "calendar", Settings: "gearshape" };
    document.querySelectorAll(".tab").forEach((b) => { b.innerHTML = icon(tabIcons[b.dataset.tab], 24) + "<span>" + b.dataset.tab + "</span>"; });
  }

  function renderToday() {
    rowEls.clear();
    if (!habits.length) { renderEmpty(); return; }
    const doneCount = habits.filter((h) => h.done).length;
    todayBody.innerHTML = `
      <div class="pillars">
        <div class="pillar" id="habits-pillar" role="group" aria-label="Habits summary">
          <div class="p-label">Habits</div><div class="p-value round" id="pillar-value"></div><div class="pips" id="pillar-pips" aria-hidden="true"></div>
        </div>
        <div class="pillar deferred" data-deferred="DEFERRED · PHASE 2 ATTENTION" aria-hidden="true">
          <div class="p-label">Attention</div><div class="p-value" style="color:var(--accent)">On track</div>
          <div class="p-label" style="font-weight:400">Not interactive in this prototype</div>
        </div>
      </div>
      <div class="section-head"><span class="label" id="habits-heading">Habits</span><span class="count" id="habits-count"></span></div>
      <div class="card" id="habits-card" role="region" aria-labelledby="habits-heading">
        <ul class="rows" id="todo-list" aria-label="To do"></ul>
        <button class="done-toggle" id="done-toggle" aria-expanded="false" aria-controls="done-list"></button>
        <ul class="rows done-list" id="done-list" aria-label="Done" hidden></ul>
      </div>
      <div class="deferred" data-deferred="DEFERRED · PHASE 4 COMPANION" style="margin-top:28px;padding:14px 16px;background:var(--surface)" aria-hidden="true">
        <div style="font-size:var(--fs-sub);color:var(--ink2)">Companion sentence would appear above the pillars (Phase 4). Not interactive.</div>
      </div>
      <div class="section-head deferred" data-deferred="DEFERRED · PHASE 2 ATTENTION" style="margin-top:34px" aria-hidden="true"><span class="label">Attention</span></div>
      <div class="card deferred" data-deferred="DEFERRED · PHASE 2 ATTENTION" style="padding:16px;margin-top:20px" aria-hidden="true">
        <div style="display:flex;gap:12px;align-items:center">${icon("hourglass", 20)}<span style="font-size:var(--fs-body);font-weight:600">Social media</span><span class="round" style="margin-left:auto">18 / 30 min</span></div>
        <div style="font-size:var(--fs-foot);color:var(--ink3);margin-top:8px">Budget logging is out of scope for this prototype.</div>
      </div>`;
    const todo = $("#todo-list"), done = $("#done-list");
    habits.slice().sort((a, b) => a.order - b.order).forEach((h) => {
      const el = makeRow(h);
      (h.group === "done" ? done : todo).appendChild(el);
    });
    const toggle = $("#done-toggle");
    toggle.addEventListener("click", onToggleDone);
    const card = $("#habits-card");
    card.addEventListener("pointerenter", (e) => { if (e.pointerType === "mouse") pointerInList = true; });
    card.addEventListener("pointerleave", (e) => { if (e.pointerType === "mouse") { pointerInList = false; onListLeave(); } });
    card.addEventListener("pointerdown", () => noteListActivity("pointer"));
    card.addEventListener("keydown", () => noteListActivity("keyboard"));
    setDoneExpanded(doneExpanded, false);
    updateSummary(false);
    void doneCount;
  }

  function renderEmpty() {
    todayBody.innerHTML = `
      <div class="card empty">
        <div class="tile" style="width:52px;height:52px;border-radius:16px">${icon("sparkles", 26)}</div>
        <h2>Start with one habit</h2>
        <p>Pick something small you’d like to do more often, or less. It shows up here on the days it’s due.</p>
        <button class="primary" id="create-btn">${icon("plus", 20)} Create a habit</button>
      </div>
      <div class="card deferred" data-deferred="DEFERRED · PHASE 2 ATTENTION" style="margin-top:28px;padding:18px 20px" aria-hidden="true">
        <div style="font-size:var(--fs-body);font-weight:600">Attention budgets</div>
        <div style="font-size:var(--fs-sub);color:var(--ink2);margin-top:6px;line-height:1.4">Explainer appears only once Phase 2 ships. Hidden until then.</div>
      </div>`;
    $("#create-btn").addEventListener("click", () => note("Not prototyped: “Create a habit” opens the native New Habit sheet."));
  }

  function makeRow(h) {
    const li = document.createElement("li");
    li.className = "row";
    li.dataset.id = h.id;
    li.innerHTML = `
      <button class="row-open" data-role="open">
        <span class="tile">${icon(h.symbol, Math.round(parseFloat(getComputedStyle(phone).getPropertyValue("--tile")) * 0.52) || 21)}</span>
        <span class="row-text"><span class="row-name"></span><span class="row-ctx" style="display:block"></span></span>
      </button>
      <button class="check" data-role="check">
        <span class="ring" aria-hidden="true"></span>
        <span class="tick" aria-hidden="true">${icon("checkmark", 22)}</span>
        <span class="check-label" aria-hidden="true"></span>
      </button>`;
    li.querySelector('[data-role="open"]').addEventListener("click", () => openDetail(h.id));
    li.querySelector('[data-role="check"]').addEventListener("click", (e) => onCheck(h.id, e));
    rowEls.set(h.id, li);
    updateRow(h);
    return li;
  }

  function updateRow(h) {
    const li = rowEls.get(h.id);
    if (!li) return;
    const ctx = context(h), w = words(h);
    li.classList.toggle("is-done", h.done);
    li.classList.toggle("settling", h.done && h.group === "todo" && settings.regroup === "deferred");
    $(".row-name", li).textContent = h.name;
    const c = $(".row-ctx", li);
    c.innerHTML = ctx.html;
    c.classList.toggle("recovering", ctx.recovering);
    $('[data-role="open"]', li).setAttribute("aria-label", "Open " + h.name + " details. " + ctx.text);
    const check = $('[data-role="check"]', li);
    check.setAttribute("aria-label", h.done ? w.undo : w.act);
    $(".check-label", li).textContent = h.done ? w.axDone : w.ax;
  }

  function updateSummary(pulse) {
    if (!habits.length) return;
    const done = habits.filter((h) => h.done).length;
    $("#pillar-value").textContent = done + " of " + habits.length;
    $("#habits-pillar").setAttribute("aria-label", "Habits: " + done + " of " + habits.length + " done");
    $("#habits-count").textContent = done + " of " + habits.length;
    $("#pillar-pips").innerHTML = habits.length > 12 ? "" : habits.map((h) => '<span class="pip ' + (h.done ? "on" : "") + '"></span>').join("");
    const inDone = habits.filter((h) => h.group === "done");
    const t = $("#done-toggle");
    t.hidden = inDone.length === 0;
    t.innerHTML = '<span class="dt-label">Done · ' + inDone.length + "</span>" +
      '<span class="avatars" aria-hidden="true">' + inDone.slice(0, 4).map((h) => '<span class="av">' + icon(h.symbol, 13) + "</span>").join("") + "</span>" +
      '<span class="chev" aria-hidden="true">' + icon("chevron.down", 15) + "</span>";
    t.setAttribute("aria-label", "Done, " + inDone.length + (inDone.length === 1 ? " habit" : " habits") + (doneExpanded ? ", expanded" : ", collapsed"));
    if (pulse && !reduceMotion()) { t.classList.remove("pulse"); void t.offsetWidth; t.classList.add("pulse"); }
  }

  // ---------------------------------------------------------------------------
  // Completion, repeat-tap guard, undo
  // ---------------------------------------------------------------------------
  function onCheck(id, evt) {
    const h = habits.find((x) => x.id === id);
    const now = performance.now();
    if (settings.guard && now - h.lastToggle < TIMING.guardMs) {
      const btn = evt.currentTarget;
      btn.classList.add("guarded"); setTimeout(() => btn.classList.remove("guarded"), 250);
      log("Repeat tap on “" + h.name + "” ignored (" + Math.round(now - h.lastToggle) + " ms after the last change; guard " + TIMING.guardMs + " ms).", "guard");
      return;
    }
    h.lastToggle = now;
    setDone(h, !h.done, "control");
  }

  function setDone(h, done, source) {
    h.done = done;
    updateRow(h);
    updateSummary(false);
    const w = words(h);
    if (done) {
      log("“" + h.name + "” " + (h.polarity === "avoidance" ? "success logged" : "completed") + " via " + source + ". Native: .sensoryFeedback(.success) would play once.");
      showToast(h);
      announce(w.toast + ". Undo available.");
    } else {
      log("“" + h.name + "” undone via " + source + ". Native: light impact haptic.");
      if (toastHabitId === h.id) hideToast(false);
      announce((h.polarity === "avoidance" ? "Success undone for " : "Completion undone for ") + h.name + ".");
    }
    scheduleRegroup(source);
  }

  // ---------------------------------------------------------------------------
  // Regroup: To do ↔ Done. Deferred so rows never move under an active pointer.
  // ---------------------------------------------------------------------------
  function needsRegroup() { return habits.some((h) => (h.done ? "done" : "todo") !== h.group); }

  function scheduleRegroup(source) {
    if (!needsRegroup()) { clearRegroup(); return; }
    if (settings.regroup === "immediate") { regroup("immediate mode"); return; }
    regroupPending = true;
    clearTimeout(regroupTimer);
    regroupTimer = setTimeout(tryRegroup, TIMING.settleMs);
    if (source === "control") log("Regroup deferred: row stays in place for " + TIMING.settleMs + " ms of no list activity.");
  }

  function noteListActivity(kind) {
    if (!regroupPending || settings.regroup !== "deferred") return;
    clearTimeout(regroupTimer);
    regroupTimer = setTimeout(tryRegroup, TIMING.settleMs);
    void kind;
  }

  function tryRegroup() {
    if (pointerInList) {
      waitingForLeave = true;
      log("Regroup still waiting: mouse pointer is over the habit list.", "warn");
      return;
    }
    regroup("settled");
  }

  function onListLeave() {
    if (!waitingForLeave) return;
    clearTimeout(leaveTimer);
    leaveTimer = setTimeout(() => { if (!pointerInList) regroup("pointer left list"); }, TIMING.leaveMs);
  }

  function clearRegroup() { regroupPending = false; waitingForLeave = false; clearTimeout(regroupTimer); clearTimeout(leaveTimer); }

  function regroup(reason) {
    clearRegroup();
    const moving = habits.filter((h) => (h.done ? "done" : "todo") !== h.group);
    if (!moving.length) return;
    const todo = $("#todo-list"), done = $("#done-list");
    if (!todo) { moving.forEach((h) => { h.group = h.done ? "done" : "todo"; }); return; }

    const active = document.activeElement;
    const focusedRow = active && active.closest ? active.closest(".row") : null;
    const focusedRole = active && active.dataset ? active.dataset.role : null;

    // FLIP: First
    const first = new Map();
    rowEls.forEach((el, id) => first.set(id, el.getBoundingClientRect()));

    moving.forEach((h) => { h.group = h.done ? "done" : "todo"; });
    const place = (list, group) => habits.filter((h) => h.group === group).sort((a, b) => a.order - b.order)
      .forEach((h) => list.appendChild(rowEls.get(h.id)));
    place(todo, "todo"); place(done, "done");
    habits.forEach(updateRow);
    updateSummary(moving.some((h) => h.group === "done"));

    // FLIP: Last → Invert → Play (skipped under Reduce Motion: rows just appear in place).
    if (!reduceMotion()) {
      rowEls.forEach((el, id) => {
        const a = first.get(id), b = el.getBoundingClientRect();
        if (!a || !b.height || !a.height) return;
        const dy = a.top - b.top;
        if (!dy) return;
        el.style.transition = "none"; el.style.transform = "translateY(" + dy + "px)";
        requestAnimationFrame(() => { el.style.transition = "transform .28s cubic-bezier(.2,.8,.2,1)"; el.style.transform = ""; });
      });
    }

    // Focus preservation: keep focus on the same control; if its row is now hidden
    // (collapsed Done group), move focus to the Done toggle and say why.
    if (focusedRow && moving.some((h) => h.id === focusedRow.dataset.id)) {
      const h = habits.find((x) => x.id === focusedRow.dataset.id);
      const visible = !(h.group === "done" && !doneExpanded);
      if (visible) {
        const target = focusedRow.querySelector('[data-role="' + (focusedRole || "check") + '"]');
        target && target.focus({ preventScroll: true });
        log("Focus kept on “" + h.name + "” after it moved to " + (h.group === "done" ? "Done" : "To do") + ".");
      } else {
        $("#done-toggle").focus({ preventScroll: true });
        announce(h.name + " moved to Done. Done group is collapsed.");
        log("Focused row moved into the collapsed Done group → focus moved to “Done” toggle and announced.");
      }
    }
    log("Regrouped " + moving.map((h) => "“" + h.name + "” → " + h.group).join(", ") + " (" + reason + ").");
  }

  function onToggleDone() { setDoneExpanded(!doneExpanded, true); }
  function setDoneExpanded(v, user) {
    doneExpanded = v;
    const t = $("#done-toggle"), list = $("#done-list");
    if (!t) return;
    t.setAttribute("aria-expanded", String(v));
    list.hidden = !v;
    updateSummary(false);
    if (user) log("Done group " + (v ? "expanded" : "collapsed") + ".");
  }

  // ---------------------------------------------------------------------------
  // Toast: never steals focus; pauses while hovered/focused; never covers the
  // control that was just used.
  // ---------------------------------------------------------------------------
  const toast = $("#toast");
  toast.addEventListener("pointerenter", pauseToast);
  toast.addEventListener("pointerleave", resumeToast);
  toast.addEventListener("focusin", pauseToast);
  toast.addEventListener("focusout", (e) => { if (!toast.contains(e.relatedTarget)) resumeToast(); });
  $("#toast-undo").addEventListener("click", () => {
    const h = habits.find((x) => x.id === toastHabitId);
    if (!h) return;
    h.lastToggle = performance.now();
    hideToast(false);
    setDone(h, false, "toast Undo");
    // Undo from the toast puts the row back immediately (pointer is on the toast, not the list).
    if (settings.regroup === "deferred") regroup("undo from toast");
    const btn = rowEls.get(h.id) && rowEls.get(h.id).querySelector('[data-role="check"]');
    if (btn) { btn.focus({ preventScroll: false }); log("Focus returned to “" + h.name + "” control after Undo (toast is gone)."); }
  });

  function showToast(h) {
    toastHabitId = h.id;
    $("#toast-text").textContent = words(h).toast;
    $(".toast-icon").innerHTML = icon("checkmark", 18);
    toast.hidden = false;
    phone.classList.add("toast-open");
    if (!reduceMotion()) { toast.classList.add("entering"); requestAnimationFrame(() => requestAnimationFrame(() => toast.classList.remove("entering"))); }
    toastRemaining = TIMING.toastMs; toastPaused = false; startToastTimer();
    keepClearOfToast(h);
  }
  function startToastTimer() { clearTimeout(toastTimer); toastStartedAt = performance.now(); toastTimer = setTimeout(() => hideToast(true), toastRemaining); }
  function pauseToast() { if (toast.hidden || toastPaused) return; toastPaused = true; clearTimeout(toastTimer); toastRemaining -= performance.now() - toastStartedAt; log("Toast paused (hover/focus)."); }
  function resumeToast() { if (toast.hidden || !toastPaused) return; toastPaused = false; toastRemaining = Math.max(toastRemaining, 1500); startToastTimer(); }
  function hideToast(expired) {
    clearTimeout(toastTimer);
    if (toast.contains(document.activeElement)) {
      const btn = rowEls.get(toastHabitId) && rowEls.get(toastHabitId).querySelector('[data-role="check"]');
      (btn && btn.offsetParent ? btn : $("#today-title")).focus({ preventScroll: true });
      log("Toast closing while focused → focus moved back to the habit control.");
    }
    toast.hidden = true; phone.classList.remove("toast-open");
    if (expired) log("Toast expired. Undo remains available: tap the filled control (expand Done if needed).");
    toastHabitId = null;
  }
  function keepClearOfToast(h) {
    const el = rowEls.get(h.id);
    if (!el) return;
    requestAnimationFrame(() => {
      const r = el.getBoundingClientRect(), tr = toast.getBoundingClientRect();
      const overlap = r.bottom + 8 - tr.top;
      if (overlap > 0) {
        $("#today-scroll").scrollBy({ top: overlap, behavior: reduceMotion() ? "auto" : "smooth" });
        log("Scrolled " + Math.round(overlap) + " px so the toast does not cover “" + h.name + "”.");
      }
    });
  }

  // ---------------------------------------------------------------------------
  // Detail navigation (read-only; opening detail never completes a habit)
  // ---------------------------------------------------------------------------
  const todayView = $("#today-view"), detailView = $("#detail-view");

  function openDetail(id) {
    const h = habits.find((x) => x.id === id);
    if (regroupPending || needsRegroup()) regroup("leaving Today");
    detailOrigin = id;
    if (!toast.hidden) hideToast(false);
    renderDetail(h);
    detailView.hidden = false;
    $("#detail-scroll").scrollTop = 0;
    if (!reduceMotion()) { detailView.classList.add("entering"); todayView.classList.add("covered"); }
    else { detailView.classList.add("entering"); }
    requestAnimationFrame(() => requestAnimationFrame(() => { detailView.classList.remove("entering"); }));
    todayView.setAttribute("aria-hidden", "true"); todayView.inert = true;
    setTimeout(() => { $("#detail-title").focus({ preventScroll: true }); }, reduceMotion() ? 20 : 330);
    log("Opened detail for “" + h.name + "” (" + (reduceMotion() ? "cross-fade" : "push") + "). Focus → title.");
  }

  function closeDetail() {
    if (detailView.hidden) return;
    todayView.removeAttribute("aria-hidden"); todayView.inert = false;
    todayView.classList.remove("covered");
    detailView.classList.add("entering");
    const done = () => {
      detailView.hidden = true; detailView.classList.remove("entering");
      const h = habits.find((x) => x.id === detailOrigin);
      const el = rowEls.get(detailOrigin);
      if (h && el && el.offsetParent) { el.querySelector('[data-role="open"]').focus({ preventScroll: false }); log("Back to Today. Focus restored to “" + h.name + "” row."); }
      else { $("#done-toggle") ? $("#done-toggle").focus() : $("#today-title").focus(); log("Back to Today. Origin row is in the collapsed Done group → focus on “Done” toggle."); }
    };
    setTimeout(done, reduceMotion() ? 180 : 320);
  }

  function renderDetail(h) {
    const sched = h.schedule.kind === "timesPerWeek" ? h.schedule.target + (h.schedule.target === 1 ? " time" : " times") + " a week" : "Every day";
    const pol = h.polarity === "avoidance" ? "Cut down" : "Build up";
    let recovery = "", stats = "";
    if (h.schedule.kind === "daily") {
      const s = dailyStats(h);
      if (s.recovering && h.polarity === "positive") {
        const missDay = ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"][s.lastMiss % 7];
        recovery = `<div class="card recovery"><div class="eyebrow-r">${icon("arrow.clockwise", 15)} REBUILDING MOMENTUM</div>
          <div class="r-main">${s.since} good ${s.since === 1 ? "day" : "days"} since your miss on ${missDay}.</div>
          <div class="r-sub">${3 - s.since === 1 ? "One more" : 3 - s.since + " more"} and you’re back on a steady run.</div>
          <div class="rpips" aria-hidden="true">${[0, 1, 2].map((i) => '<span class="' + (i < s.since ? "on" : "") + '"></span>').join("")}</div></div>`;
      }
      stats = stat("Current streak", s.streak, s.streak === 1 ? "day" : "days", "Best: " + s.best + " days") +
              stat("Consistency", s.resolved ? Math.round((100 * s.ok) / s.resolved) : "—", s.resolved ? "%" : "", s.resolved ? s.ok + " of " + s.resolved + " days" + (s.skips ? " · " + s.skips + " skip excused" : "") : "Not enough data yet");
    } else {
      const s = weeklyStats(h);
      stats = stat("Current streak", s.streak, s.streak === 1 ? "week" : "weeks", "Best: " + s.best + " weeks") +
              stat("This week", s.got, "of " + s.target, s.met ? "Goal met" : "Week still open");
    }
    const dh = "SMTWTFS".split("").map((d) => '<div class="dh" aria-hidden="true">' + d + "</div>").join("");
    const names = { d: "done", m: "missed", s: "skipped", ".": "no check-in", t: "today, open" };
    const cellHtml = cells(h).map((c) => {
      const cls = c === "." ? "n" : c;
      const inner = c === "d" ? icon("checkmark", 16) : c === "s" ? icon("forward.end", 13) : "";
      return '<div class="cell ' + cls + '" aria-hidden="true">' + inner + "</div>";
    }).join("");
    const counts = cells(h).reduce((m, c) => { m[c] = (m[c] || 0) + 1; return m; }, {});
    const summary = "Last 14 days: " + Object.keys(names).filter((k) => counts[k]).map((k) => counts[k] + " " + names[k]).join(", ") + ".";
    $("#detail-body").innerHTML = `
      <div class="d-head"><span class="tile">${icon(h.symbol, 30)}</span>
        <div><h1 class="d-title" id="detail-title" tabindex="-1">${h.name}</h1><div class="d-sub">${h.category} · ${pol} · ${sched}</div></div></div>
      ${recovery}
      <div class="stats">${stats}</div>
      <div class="section-head"><span class="label">Last 14 days</span><span class="count">${P.SAMPLE.rangeLabel}</span></div>
      <div class="card ledger"><div class="ledger-grid" role="img" aria-label="${summary}">${dh}${cellHtml}</div>
        <div class="legend" aria-hidden="true"><span><i style="background:var(--accent)"></i>Done</span><span><i style="border:1.5px solid var(--ink3)"></i>Missed</span>
          <span><i style="background:var(--surface2);border:1px solid var(--ink3)"></i>Skipped</span>${h.schedule.kind === "timesPerWeek" ? '<span><i style="border:1.5px dotted var(--ink3)"></i>No check-in</span>' : ""}
          <span><i style="border:1.5px dashed var(--accent)"></i>Today</span></div></div>
      <div class="card nav-rows" style="margin-top:14px">
        <button class="nr" data-note="History is not part of this prototype.">${icon("calendar", 20)}<span class="grow">View history</span>${icon("chevron.right", 15)}</button>
        <button class="nr" data-note="Archive is not part of this prototype (its confirmation must show Cancel — UX_AUDIT F9).">${icon("archivebox", 20)}<span class="grow">Archive habit…</span></button>
      </div>
      <p class="readonly-note">Detail is read-only for today’s status, as in the app: complete or undo from Today. Figures are computed from sample data with simplified rules.</p>`;
    $("#detail-body").querySelectorAll("[data-note]").forEach((b) => b.addEventListener("click", () => note("Not prototyped: " + b.dataset.note)));
  }
  function stat(label, value, unit, noteText) {
    return `<div class="stat"><div class="s-label">${label}</div><div class="s-value round">${value}<small> ${unit}</small></div><div class="s-note">${noteText}</div></div>`;
  }

  // ---------------------------------------------------------------------------
  // Reviewer notes for things outside the prototype (never silent dead buttons)
  // ---------------------------------------------------------------------------
  let noteTimer = null;
  function note(msg) {
    const b = $("#note-banner");
    b.textContent = msg; b.hidden = false;
    clearTimeout(noteTimer); noteTimer = setTimeout(() => { b.hidden = true; }, TIMING.noteMs);
    log(msg, "warn");
  }

  // ---------------------------------------------------------------------------
  // Wiring
  // ---------------------------------------------------------------------------
  $("#back-btn").addEventListener("click", closeDetail);
  $("#edit-btn").addEventListener("click", () => note("Not prototyped: Edit opens the native habit form."));
  $("#add-btn").addEventListener("click", () => note("Not prototyped: Add opens the native New Habit sheet."));
  document.querySelectorAll(".tab").forEach((b) => b.addEventListener("click", () => {
    if (b.dataset.tab !== "Today") note("Not prototyped: the " + b.dataset.tab + " tab.");
    else if (!detailView.hidden) closeDetail();
  }));
  document.addEventListener("keydown", (e) => { if (e.key === "Escape" && !detailView.hidden) closeDetail(); });

  function syncPanel() {
    ["state", "theme", "text", "motion", "regroup"].forEach((k) => {
      document.querySelectorAll('input[name="' + k + '"]').forEach((r) => { r.checked = r.value === settings[k]; });
    });
    $("#guard").checked = settings.guard; $("#deferred").checked = settings.deferred; $("#symbols").checked = settings.symbols;
  }
  function updateUrl() {
    const p = new URLSearchParams();
    p.set("state", settings.state); p.set("theme", settings.theme); p.set("text", settings.text); p.set("motion", settings.motion);
    p.set("regroup", settings.regroup); if (!settings.guard) p.set("guard", "off"); if (settings.deferred) p.set("deferred", "show"); if (settings.symbols) p.set("symbols", "show");
    history.replaceState(null, "", "?" + p.toString());
  }
  document.querySelectorAll(".panel input").forEach((inp) => inp.addEventListener("change", () => {
    if (inp.type === "radio") settings[inp.name] = inp.value;
    else settings[inp.id] = inp.checked;
    if (inp.name === "state") { loadData(); if (!detailView.hidden) { detailView.hidden = true; todayView.inert = false; todayView.removeAttribute("aria-hidden"); todayView.classList.remove("covered"); } hideToast(false); }
    applySettings(); updateUrl();
    if (["state", "text"].includes(inp.name)) renderToday();
    else habits.forEach(updateRow);
    log("Reviewer: " + (inp.name || inp.id) + " → " + (inp.type === "radio" ? inp.value : inp.checked) + ".");
  }));
  $("#reset-btn").addEventListener("click", () => { loadData(); hideToast(false); closeDetail(); renderToday(); log("Reviewer: sample data reset."); });
  $("#copy-link").addEventListener("click", () => {
    const url = location.href;
    (navigator.clipboard ? navigator.clipboard.writeText(url) : Promise.reject()).then(() => log("Link copied: " + url), () => log("Copy failed; URL: " + url, "warn"));
  });
  mqReduce.addEventListener("change", () => { applySettings(); log("System Reduce Motion changed."); });

  loadData(); applySettings(); renderChrome(); syncPanel(); updateUrl(); renderToday();
  log("Prototype ready. Sample data only; nothing is saved.");
})();
