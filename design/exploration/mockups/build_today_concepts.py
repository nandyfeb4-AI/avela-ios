#!/usr/bin/env python3
"""Today-screen concept round 2: Action-first, Balance, Quiet companion — vs Tidewater.

Exploration artifact only. Reuses helpers from build.py (imported, not modified)
and writes only new files prefixed "today-" so earlier artifacts are preserved.

    python3 design/exploration/mockups/build_today_concepts.py          # HTML + PNG
    python3 design/exploration/mockups/build_today_concepts.py --html   # HTML only
"""

import copy
import os
import sys

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import build as B  # noqa: E402
from build import icon, phone, tabbar, companion, esc  # noqa: E402

# Extra approximations of SF Symbols used only by this round (added at runtime;
# build.py itself is untouched).
B.ICONS.update({
    "chevron.down": '<path d="M5 9l7 7 7-7" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>',
    "arrow.uturn.backward": '<path d="M9 14L4 9l5-5" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/><path d="M4 9h10a6 6 0 0 1 0 12h-3" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/>',
    "newspaper": '<rect x="3" y="4.5" width="15" height="15" rx="2.2" fill="none" stroke="currentColor" stroke-width="1.9"/><path d="M18 8.5h2.2a.8.8 0 0 1 .8.8V17a2.5 2.5 0 0 1-5 0M6.5 8.5h8M6.5 12h8M6.5 15.5h5" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round"/>',
    "sunrise": '<path d="M3 18h18M6.5 18a5.5 5.5 0 0 1 11 0" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><path d="M12 3.5v4M9.5 6l2.5-2.5L14.5 6M4.2 11.2l1.6 1M19.8 11.2l-1.6 1" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round" stroke-linejoin="round"/><path d="M7 21h10" stroke="currentColor" stroke-width="2" stroke-linecap="round" opacity=".5"/>',
    "pills.fill": '<rect x="3.5" y="8.5" width="17" height="7" rx="3.5" transform="rotate(-35 12 12)" fill="currentColor"/><path d="M12 7.2l1.6 7.6" stroke="var(--accentSoft)" stroke-width="1.6" transform="rotate(-35 12 12)"/>',
    "bubble.left.fill": '<path d="M4 6.5A3 3 0 0 1 7 3.5h10a3 3 0 0 1 3 3v7a3 3 0 0 1-3 3h-7l-4.5 3.5V16.3A3 3 0 0 1 4 13.5z" fill="currentColor"/>',
    "phone.fill": '<path d="M6.6 3.5l3 .6 1.2 3.9-2 1.6a12 12 0 0 0 5.6 5.6l1.6-2 3.9 1.2.6 3c.1.8-.5 1.6-1.4 1.6C10.3 19 5 13.7 5 5c0-.9.8-1.6 1.6-1.5z" fill="currentColor"/>',
    "nosign": '<circle cx="12" cy="12" r="8.4" fill="none" stroke="currentColor" stroke-width="2.2"/><path d="M6.2 6.2l11.6 11.6" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/>',
    "figure.cooldown": '<circle cx="12" cy="4" r="2.1" fill="currentColor"/><path d="M12 7.4v6.2M12 13.6l-4.4 6.4M12 13.6l4.4 6.4M5.6 9.4l6.4 1.4 6.4-1.4" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round"/>',
})

EXTRA_CSS = """
.future[data-f]::after{content:attr(data-f);white-space:nowrap}
.zoomwrap{zoom:.66}
.flow{display:flex;align-items:center;gap:18px}
.arrow{font:600 34px -apple-system;color:#9a9a9a}
.capt{font:600 13px system-ui;color:#555;margin:0 0 12px;text-transform:uppercase;letter-spacing:.04em}
.darkboard .capt{color:#aaa}
.metric{display:grid;grid-template-columns:240px repeat(4,1fr);font:13.5px/1.35 system-ui;border-top:1px solid #cfcac0;margin-top:30px}
.metric div{padding:9px 10px;border-bottom:1px solid #d9d4ca}
.metric .h{font-weight:700;background:#dfdbd2}
"""

# ---------------------------------------------------------------------------
# Identical realistic data for every concept. Saturday Oct 3, 9:41 AM.
# Habit copy follows the implemented HabitPolarityFormatter wording
# ("Log success", not "Avoided").
# ---------------------------------------------------------------------------

HABITS = copy.deepcopy(B.HABITS)
HABITS[4]["ctx"] = "Cut down · success logged for last night"
B.HABITS[4]["ctx"] = HABITS[4]["ctx"]  # so the Tidewater baseline renders identical data

ATTENTION = [  # all FUTURE — Phase 2 attention engine
    dict(name="Social media", icon="hourglass", kind="budget", used=18, limit=30),
    dict(name="News", icon="newspaper", kind="window", ctx="Protected until 6:00 PM", status="On track"),
    dict(name="Phone-free morning", icon="sunrise", kind="session", ctx="First 30 min after waking · done 7:12 AM", done=True),
]

MANY = HABITS + [
    dict(name="Vitamins", icon="pills.fill", ctx="Every day · 9-day streak", done=False, kind="daily"),
    dict(name="Practice Spanish", icon="bubble.left.fill", ctx="1 of 3 this week", done=False, kind="weekly", got=1, target=3),
    dict(name="Call a friend", icon="phone.fill", ctx="0 of 1 this week", done=False, kind="weekly", got=0, target=1),
    dict(name="Floss", icon="sparkles", ctx="Every day · 2-day streak", done=False, kind="daily"),
    dict(name="No sugar after 8 PM", icon="nosign", ctx="Cut down · log tonight", done=False, kind="daily"),
    dict(name="Stretch", icon="figure.cooldown", ctx="Every day · 3-day streak", done=True, kind="daily"),
]
# MANY: 11 habits, 3 done (walk, no phone in bed, stretch), 8 to do.

FUT_ATTN = "PHASE 2 · ATTENTION"
FUT_RANK = "NOT BUILT · NEXT-UP RULE"
FUT_SKIP = "NOT BUILT · SKIP ON TODAY"
FUT_COMP = "PHASE 4 · COMPANION"
FUT_TOAST = "NOT BUILT · UNDO TOAST"


def fut(inner, label, style=""):
    return f'<div class="future" data-f="{label}" style="{style}">{inner}</div>'


card = B.tide_card
sep = B.tide_sep
row = B.tide_row
section = B.tide_section


def header(title="Today", eyebrow="Saturday, October 3", trailing=""):
    return f'''<div style="display:flex;justify-content:flex-end;gap:8px;padding-top:4px">{trailing}<div class="glassbtn">{icon("plus", 22)}</div></div>
      <div style="font-size:13px;font-weight:600;color:var(--ink3);letter-spacing:.04em;text-transform:uppercase;margin:-6px 4px 0">{eyebrow}</div>
      <div style="font-size:34px;font-weight:700;letter-spacing:-.02em;margin:0 4px 14px">{title}</div>'''


def toast(text, bottom=96, label=FUT_TOAST):
    inner = (f'<div style="display:flex;align-items:center;gap:10px;padding:0 8px 0 18px;height:52px;border-radius:26px;background:var(--ink);color:var(--bg);'
             f'box-shadow:0 8px 24px rgba(0,0,0,.18)">{icon("checkmark", 18, "var(--accentSoft)")}<span style="flex:1;font-size:15px;font-weight:500">{text}</span>'
             f'<span style="padding:8px 14px;border-radius:18px;font-weight:600;font-size:15px;background:rgba(127,127,127,.3)">Undo</span></div>')
    return f'<div style="position:absolute;left:16px;right:16px;bottom:{bottom}px;z-index:26">{fut(inner, label)}</div>'


def small_check(done, size=30):
    if done:
        return (f'<div style="width:44px;height:44px;display:flex;align-items:center;justify-content:center;flex:none"><div style="width:{size}px;height:{size}px;border-radius:{size//2}px;'
                f'background:var(--accent);display:flex;align-items:center;justify-content:center">{icon("checkmark", size*.55, "var(--accentInk)")}</div></div>')
    return (f'<div style="width:44px;height:44px;display:flex;align-items:center;justify-content:center;flex:none"><div style="width:{size}px;height:{size}px;border-radius:{size//2}px;'
            f'border:2.2px solid var(--ink3)"></div></div>')


# ===========================================================================
# Concept 1 — Action-first ("Next up")
# ===========================================================================

def c1_hero(h, reason, label="Mark Journal done"):
    ctx_color = "var(--amber)" if h["kind"] == "recovering" else "var(--ink2)"
    inner = f'''<div style="padding:18px 18px 14px">
      <div style="display:flex;align-items:center;justify-content:space-between">
        <span style="font-size:13px;font-weight:700;letter-spacing:.06em;color:var(--accent)">NEXT UP</span>
        <span style="font-size:13px;color:var(--ink3)" class="tnum">1 of 3 left</span></div>
      <div style="display:flex;align-items:center;gap:14px;margin-top:12px">
        <div style="width:52px;height:52px;border-radius:16px;background:var(--accentSoft);display:flex;align-items:center;justify-content:center">{icon(h["icon"], 27, "var(--accent)")}</div>
        <div style="flex:1"><div style="font-size:24px;font-weight:700;letter-spacing:-.01em">{esc(h["name"])}</div>
        <div style="font-size:15px;color:{ctx_color};margin-top:1px">{B.tide_progress(h)}{esc(h["ctx"])}</div></div></div>
      <div style="font-size:15px;color:var(--ink2);margin-top:12px;line-height:1.35">{reason}</div>
      <div style="margin-top:14px;height:52px;border-radius:26px;background:var(--accent);color:var(--accentInk);display:flex;align-items:center;justify-content:center;gap:8px;font-size:17px;font-weight:600">{icon("checkmark", 20, "var(--accentInk)")}{label}</div>
      <div style="display:flex;justify-content:center;gap:34px;margin-top:6px;font-size:15px;font-weight:600;color:var(--accent)">
        <span style="padding:12px 4px">Not now</span>{fut('<span style="padding:12px 4px;display:block">Skip today…</span>', "NOT BUILT")}</div></div>'''
    return fut(card(inner, "box-shadow:0 0 0 1.5px var(--accentSoft),var(--shadow)"), FUT_RANK)


def c1_queue_row(h):
    return f'''<div style="display:flex;align-items:center;gap:12px;padding:4px 6px 4px 14px;min-height:56px">
      {icon(h["icon"], 19, "var(--accent)")}
      <div style="flex:1"><span style="font-size:16px;font-weight:600">{esc(h["name"])}</span>
      <span style="font-size:14px;color:{"var(--amber)" if h["kind"] == "recovering" else "var(--ink2)"}"> · {esc(h["ctx"])}</span></div>{small_check(h["done"])}</div>'''


def c1_done_row(done_list):
    icons = "".join(f'<div style="width:28px;height:28px;border-radius:14px;background:var(--accent);display:flex;align-items:center;justify-content:center;margin-left:-6px;border:2px solid var(--surface)">{icon(h["icon"], 14, "var(--accentInk)")}</div>' for h in done_list)
    return card(f'''<div style="display:flex;align-items:center;gap:12px;padding:12px 16px;min-height:52px">
      <span style="font-size:16px;font-weight:600;flex:1">Done · {len(done_list)}</span><div style="display:flex;padding-left:6px">{icons}</div>{icon("chevron.down", 16, "var(--ink3)")}</div>''')


def c1_attention_strip():
    chips = [("hourglass", "Social 18/30"), ("newspaper", "News 6 PM"), ("sunrise", "Phone-free ✓")]
    inner = "".join(f'<div style="display:flex;align-items:center;gap:6px;padding:9px 10px;border-radius:16px;background:var(--surface);font-size:13px;font-weight:600;white-space:nowrap">{icon(i, 15, "var(--ink2)")}{t}</div>' for i, t in chips)
    return fut(f'<div style="display:flex;gap:6px">{inner}</div>', FUT_ATTN, "margin-top:16px")


def c1_today(theme="tide-light", after=False, markers=True):
    todo = [h for h in HABITS if not h["done"]]
    done = [h for h in HABITS if h["done"]]
    if after:  # Journal logged → hero advances to Drink water
        hero = c1_hero(todo[0], "Next on your list. You’ve done this four days running.", "Mark Drink water done")
        hero = hero.replace("1 of 3 left", "2 left")
        queue = [todo[1]]
        done = done + [dict(todo[2], done=True)]
    else:
        hero = c1_hero(todo[2], "One more good day finishes your rebuild after Wednesday’s miss.")
        queue = [todo[0], todo[1]]
    q = sep().replace("66px", "45px").join(c1_queue_row(h) for h in queue)
    inner = f'''<div class="scroll">{header(trailing='<div class="glasspill" style="font-size:15px;padding:0 14px"><span class="round tnum" style="font-weight:700">' + str(len(done)) + '</span>&nbsp;of 5</div>')}
      {hero}
      {section("Later today", str(len(queue)))}
      {card(q)}
      <div style="height:10px"></div>{c1_done_row(done)}
      {c1_attention_strip()}
    </div>{tabbar("Today")}{toast("Journal done") if after else ""}'''
    m = [(2, 190), (2, 400), (2, 600)] if markers else []
    return phone(theme, inner, m)


# ===========================================================================
# Concept 2 — Habit-and-attention balance ("Two pillars")
# ===========================================================================

def c2_pillars(attn_state="On track", attn_sub="Social 18 of 30 min", tone="var(--accent)", habits_val="2 of 5", dots=None):
    dots = dots or [h["done"] for h in HABITS]
    pips = "".join(f'<span style="width:9px;height:9px;border-radius:5px;{"background:var(--accent)" if d else "border:1.6px solid var(--ink3)"}"></span>' for d in dots)
    habits = f'''<div style="flex:1;background:var(--surface);border-radius:20px;padding:13px 14px;box-shadow:var(--shadow)">
      <div style="font-size:13px;font-weight:600;color:var(--ink2)">Habits</div>
      <div class="round tnum" style="font-size:26px;font-weight:700;margin-top:2px">{habits_val}</div>
      <div style="display:flex;gap:5px;margin-top:6px;flex-wrap:wrap">{pips}</div></div>'''
    attn = fut(f'''<div style="background:var(--surface);border-radius:20px;padding:13px 14px;box-shadow:var(--shadow);height:100%">
      <div style="font-size:13px;font-weight:600;color:var(--ink2)">Attention</div>
      <div style="font-size:22px;font-weight:700;margin-top:4px;color:{tone}">{attn_state}</div>
      <div style="font-size:13px;color:var(--ink2);margin-top:4px" class="tnum">{attn_sub}</div></div>''', FUT_ATTN, "flex:1")
    return f'<div style="display:flex;gap:10px">{habits}{attn}</div>'


def c2_habits_card(habits, expanded=False):
    todo = [h for h in habits if not h["done"]]
    done = [h for h in habits if h["done"]]
    body = sep().join(row(h) for h in todo)
    if done and expanded:
        body += '<div style="padding:10px 16px 4px;font-size:13px;font-weight:600;color:var(--ink3);border-top:.5px solid var(--sep)">DONE</div>'
        body += sep().join(row(h) for h in done)
    elif done:
        icons = "".join(f'<div style="width:26px;height:26px;border-radius:13px;background:var(--accent);display:flex;align-items:center;justify-content:center;margin-left:-6px;border:2px solid var(--surface)">{icon(h["icon"], 13, "var(--accentInk)")}</div>' for h in done)
        body += (f'<div style="display:flex;align-items:center;gap:12px;padding:0 16px;min-height:50px;border-top:.5px solid var(--sep)">'
                 f'<span style="font-size:15px;font-weight:600;color:var(--ink2);flex:1">Done · {len(done)}</span><div style="display:flex;padding-left:6px">{icons}</div>{icon("chevron.down", 15, "var(--ink3)")}</div>')
    return card(body)


def c2_budget_row(a, used=None):
    used = a["used"] if used is None else used
    pct = used / a["limit"]
    col = "var(--accent)" if pct < .7 else ("var(--amber)" if pct < 1 else "var(--clay)")
    state = "" if pct < .7 else ("Near limit" if pct < 1 else "Over today’s budget")
    chips = "".join(f'<span style="height:34px;padding:0 14px;border-radius:17px;background:var(--accentSoft);color:var(--accent);font-size:14px;font-weight:600;display:inline-flex;align-items:center">{t}</span>' for t in ["+5 min", "+15 min", "Other…"])
    return f'''<div style="padding:13px 14px 14px 12px">
      <div style="display:flex;align-items:center;gap:13px">
        <div style="width:40px;height:40px;border-radius:12px;background:var(--surface2);display:flex;align-items:center;justify-content:center">{icon(a["icon"], 21, "var(--ink2)")}</div>
        <div style="flex:1"><div style="display:flex;justify-content:space-between;align-items:baseline"><span style="font-size:17px;font-weight:600">{a["name"]}</span>
          <span class="round tnum" style="font-size:16px;font-weight:600">{used}<span style="color:var(--ink3);font-weight:500"> / {a["limit"]} min</span></span></div>
        <div style="height:6px;border-radius:3px;background:var(--surface2);margin-top:8px"><div style="width:{min(pct, 1)*100:.0f}%;height:6px;border-radius:3px;background:{col}"></div></div>
        {f'<div style="font-size:13px;font-weight:600;color:{col};margin-top:5px">{state}</div>' if state else ''}</div></div>
      <div style="display:flex;gap:8px;margin:11px 0 0 53px">{chips}</div></div>'''


def c2_simple_row(a):
    trailing = (f'<div style="width:44px;height:44px;border-radius:22px;background:var(--accent);display:flex;align-items:center;justify-content:center">{icon("checkmark", 22, "var(--accentInk)")}</div>'
                if a.get("done") else f'<span style="font-size:13px;font-weight:600;color:var(--accent);background:var(--accentSoft);padding:5px 10px;border-radius:11px">{a["status"]}</span>')
    return f'''<div style="display:flex;align-items:center;gap:13px;padding:11px 14px 11px 12px;min-height:68px">
      <div style="width:40px;height:40px;border-radius:12px;background:var(--surface2);display:flex;align-items:center;justify-content:center">{icon(a["icon"], 21, "var(--ink2)")}</div>
      <div style="flex:1"><div style="font-size:17px;font-weight:600">{a["name"]}</div><div style="font-size:14px;color:var(--ink2);margin-top:2px">{a["ctx"]}</div></div>{trailing}</div>'''


def c2_attention_card(used=None):
    return fut(card(c2_budget_row(ATTENTION[0], used) + sep() + c2_simple_row(ATTENTION[1]) + sep() + c2_simple_row(ATTENTION[2])), FUT_ATTN)


def c2_today(theme="tide-light", markers=True, after=False):
    used = 23 if after else 18
    pill = c2_pillars("Near limit", "Social 23 of 30 min", "var(--amber)") if after else c2_pillars()
    inner = f'''<div class="scroll">{header()}
      {pill}
      {section("Habits", "2 of 5")}
      {c2_habits_card(HABITS)}
      {section("Attention")}
      {c2_attention_card(used)}
    </div>{tabbar("Today")}{toast("Added 5 min to Social media") if after else ""}'''
    m = [(2, 150), (2, 270), (2, 495)] if markers else []
    return phone(theme, inner, m)


def c2_interim(theme="tide-light"):
    """What ships before Phase 2: the attention pillar is absent, not a placeholder."""
    inner = f'''<div class="scroll">{header()}
      {section("Habits", "2 of 5").replace("margin:20px", "margin:0")}
      {c2_habits_card(HABITS)}
    </div>{tabbar("Today")}'''
    return phone(theme, inner)


def c2_empty(theme="tide-light"):
    inner = f'''<div class="scroll">{header()}
      {card(f"""<div style="padding:22px 20px 20px">
        <div style="width:52px;height:52px;border-radius:16px;background:var(--accentSoft);display:flex;align-items:center;justify-content:center">{icon("sparkles", 26, "var(--accent)")}</div>
        <div style="font-size:22px;font-weight:700;margin-top:14px">Start with one habit</div>
        <div style="font-size:16px;color:var(--ink2);line-height:1.4;margin-top:6px">Pick something small you’d like to do more often, or less. It shows up here on the days it’s due.</div>
        <div style="margin-top:18px;height:52px;border-radius:26px;background:var(--accent);color:var(--accentInk);display:flex;align-items:center;justify-content:center;gap:8px;font-size:17px;font-weight:600">{icon("plus", 20, "var(--accentInk)")}Create a habit</div></div>""")}
      <div style="height:22px"></div>
      {fut(card(f"""<div style="padding:18px 20px">
        <div style="display:flex;gap:12px;align-items:center">{icon("hourglass", 22, "var(--ink2)")}<span style="font-size:17px;font-weight:600">Attention budgets</span></div>
        <div style="font-size:15px;color:var(--ink2);line-height:1.4;margin-top:6px">Later, you can set a daily budget, such as 30 minutes of social media, and log time here.</div>
        <div style="font-size:16px;font-weight:600;color:var(--accent);margin-top:12px">Set a budget</div></div>"""), FUT_ATTN)}
    </div>{tabbar("Today")}'''
    return phone(theme, inner)


def c2_many_top(theme="tide-light"):
    dots = [h["done"] for h in MANY]
    inner = f'''<div class="scroll">{header()}
      {c2_pillars(habits_val="3 of 11", dots=dots)}
      {section("Habits", "3 of 11")}
      {c2_habits_card(MANY)}
    </div>{tabbar("Today")}'''
    return phone(theme, inner)


def c2_many_scrolled(theme="tide-light"):
    todo = [h for h in MANY if not h["done"]]
    done = [h for h in MANY if h["done"]]
    tail = sep().join(row(h) for h in todo[5:])
    tail += '<div style="padding:10px 16px 4px;font-size:13px;font-weight:600;color:var(--ink3);border-top:.5px solid var(--sep)">DONE</div>'
    tail += sep().join(row(h) for h in done)
    sticky = f'''<div style="position:absolute;top:0;left:0;right:0;height:112px;z-index:22;background:var(--glass);backdrop-filter:blur(20px);-webkit-backdrop-filter:blur(20px);border-bottom:.5px solid var(--sep)">
      <div style="position:absolute;top:58px;left:0;right:0;text-align:center;font-size:17px;font-weight:600">Today</div>
      <div style="position:absolute;top:84px;left:0;right:0;display:flex;justify-content:center;gap:8px;font-size:13px;font-weight:600">
        <span style="padding:3px 9px;border-radius:10px;background:var(--surface2)" class="tnum">Habits 3 of 11</span>
        <span class="future" data-f="PHASE 2" style="padding:3px 9px;border-radius:10px;background:var(--accentSoft);color:var(--accent)">Attention on track</span></div></div>'''
    inner = f'''{sticky}<div class="scroll" style="top:96px">
      <div style="margin-top:-30px">{card(tail)}</div>
      {section("Attention")}
      {c2_attention_card()}
    </div>{tabbar("Today")}'''
    return phone(theme, inner)


def c2_ax(theme="tide-light"):
    def tile(label, value, future=False):
        t = card(f'<div style="padding:16px"><div style="font-size:28px;font-weight:600;color:var(--ink2)">{label}</div><div style="font-size:40px;font-weight:700;line-height:1.12">{value}</div></div>')
        return fut(t, "PHASE 2") if future else t
    h = HABITS[2]
    habit = card(f'''<div style="padding:16px 16px 18px">{icon(h["icon"], 36, "var(--accent)")}
      <div style="font-size:40px;font-weight:600;line-height:1.12;margin-top:8px">{h["name"]}</div>
      <div style="font-size:33px;line-height:1.18;color:var(--amber);margin-top:4px">Rebuilding · 2 of 3 good days</div>
      <div style="margin-top:14px;height:64px;border-radius:32px;border:2.5px solid var(--accent);color:var(--accent);display:flex;align-items:center;justify-content:center;font-size:30px;font-weight:600">Mark done</div></div>''')
    inner = f'''<div class="scroll">
      <div style="display:flex;justify-content:flex-end;padding-top:4px"><div class="glassbtn">{icon("plus", 22)}</div></div>
      <div style="font-size:40px;font-weight:700;margin:0 4px 12px">Today</div>
      {tile("Habits", "2 of 5 done")}<div style="height:10px"></div>{tile("Attention", "On track", True)}
      <div style="height:14px"></div>{habit}
    </div>{tabbar("Today")}'''
    return phone(theme, inner)


# ===========================================================================
# Concept 3 — Quiet companion-led
# ===========================================================================

def c3_today(theme="tide-light", after=False, markers=True):
    habits = copy.deepcopy(HABITS)
    if after:
        habits[2].update(done=True, ctx="Every day · 3-day streak", kind="daily")
        line = "Three done. Journal is back on a steady run."
        state = "calm"
        action = '<span style="font-size:15px;color:var(--ink2)">Drink water and Read are still open.</span>'
    else:
        line = "Two done. Journal keeps your rebuild going."
        state = "focused"
        action = f'''<div style="display:flex;align-items:center;gap:6px;margin-top:12px">
          <div style="height:44px;padding:0 18px;border-radius:22px;background:var(--accent);color:var(--accentInk);display:inline-flex;align-items:center;gap:7px;font-size:16px;font-weight:600">{icon("checkmark", 17, "var(--accentInk)")}Log Journal</div>
          <span style="font-size:15px;font-weight:600;color:var(--accent);padding:12px 10px">Not now</span></div>'''
    order = [h for h in habits if not h["done"]] + [h for h in habits if h["done"]]
    body = sep().join(row(h) for h in order)
    band = f'''<div style="position:absolute;top:0;left:0;right:0;height:360px;background:linear-gradient(to bottom,var(--accentSoft) 0%,var(--bg) 100%)"></div>'''
    inner = f'''{band}<div class="scroll">
      <div style="display:flex;justify-content:space-between;align-items:center;padding-top:4px">
        <span style="font-size:13px;font-weight:600;color:var(--ink2);letter-spacing:.04em;text-transform:uppercase;margin-left:4px">Saturday morning</span>
        <div class="glassbtn">{icon("plus", 22)}</div></div>
      {fut(f"""<div style="display:flex;gap:14px;align-items:flex-start;margin-top:8px">
        <div style="flex:none">{companion(84, state, "var(--accent)", "var(--surface)", "var(--surface)")}</div>
        <div style="flex:1;padding-top:6px"><div style="font-size:21px;font-weight:600;line-height:1.28;letter-spacing:-.01em">{line}</div>{action}</div></div>""", "PHASE 4 · COMPANION + NEXT-UP RULE", "margin-top:14px")}
      <div style="font-size:14px;color:var(--ink2);margin:16px 4px 0;display:flex;gap:10px;flex-wrap:wrap">
        <span class="tnum">{"3" if after else "2"} of 5 habits</span><span>·</span>{fut('<span class="tnum">Social 18 of 30 min</span>', "PHASE 2", "display:inline-block")}</div>
      {section("Your day", "")}
      {card(body)}
    </div>{tabbar("Today")}{toast("Journal done") if after else ""}'''
    m = [(2, 120), (2, 230), (2, 340)] if markers else []
    return phone(theme, inner, m)


# ===========================================================================
# Boards
# ===========================================================================

def col(title, ph, notes, w=413):
    lis = "".join(f'<li class="plain">{n[1:]}</li>' if n.startswith("!") else f"<li>{n}</li>" for n in notes)
    return f'<div class="col" style="width:{w}px"><h2>{title}</h2>{ph}<ol class="notes">{lis}</ol></div>'


def page(title, body, width, dark=False):
    html_ = B.page(title, body, width, dark)
    return html_.replace("</style>", EXTRA_CSS + "</style>", 1)


LEGEND = ('Purple dashed outline = not implemented today; the label says which phase or missing behavior it depends on. '
          'Identical data in every phone: Saturday Oct 3, 9:41 AM; five habits (2 done); three attention goals (Phase 2). Icons are SF Symbol approximations; the companion is placeholder art.')

BOARDS = {}

BOARDS["today-compare-light"] = (f'''
<h1>Today: four concepts, same data</h1>
<div class="sub">Tidewater (the previous recommendation) next to three new information architectures. All four use Tidewater’s tokens and components, so the comparison is about structure and interaction, not colour.</div>
<div class="row" style="gap:44px">
{col("Baseline · Tidewater", B.tide_today("tide-light", False), [
  "Companion status card, then To do and Done cards, then attention below the fold.",
  "Every habit shows the same row and a one-tap trailing control.",
  "Attention is the last section; on a 6.3-inch screen it is mostly under the tab bar."])}
{col("1 · Action-first", c1_today(), [
  "The hero card shows one suggested next action with its reason and a 52pt button. The suggestion rule is new product behavior (recovering → daily → weekly) and is not built.",
  "Everything else is compressed: “Later today” rows and a collapsed “Done · 2”.",
  "Attention becomes three chips. Glanceable, but there is no logging from Today."])}
{col("2 · Habit + attention balance", c2_today(), [
  "Two equal pillar tiles, Habits and Attention, each with one number or state. Tapping a tile scrolls to its section.",
  "Habits: to-do rows, then done rows collapsed into one “Done · 2” row (tap to expand). That keeps Attention above the fold.",
  "The Attention section has type-specific controls: +5 / +15 min chips log in one tap, a protected window shows status, a phone-free session shows done."])}
{col("3 · Quiet companion-led", c3_today(), [
  "The companion narrates in one sentence and offers one action. It uses the same next-up rule as concept 1, but phrased as an offer.",
  "A thin metrics line replaces the cards; attention is a single clause.",
  "The full habit list stays one scroll away (about 360pt down), so every action is still one tap."])}
</div><div class="legend">{LEGEND}</div>''', 1900, False)

BOARDS["today-compare-dark"] = (f'''
<h1>Today: four concepts, dark appearance</h1>
<div class="sub">The same four screens with dark tokens. Concept 3’s tinted band relies on accentSoft; in dark mode it becomes a deep teal wash rather than a light glow.</div>
<div class="row" style="gap:44px">
{col("Baseline · Tidewater", B.tide_today("tide-dark", False), [])}
{col("1 · Action-first", c1_today("tide-dark", markers=False), [])}
{col("2 · Habit + attention balance", c2_today("tide-dark", markers=False), [])}
{col("3 · Quiet companion-led", c3_today("tide-dark", markers=False), [])}
</div><div class="legend">{LEGEND}</div>''', 1900, True)

BOARDS["today-interactions"] = (f'''
<h1>One logging action per concept: before → after</h1>
<div class="sub">This shows what changes on screen after a single tap. These are static frames; motion rules are in COMPONENT_SPEC §3. The undo toast is not built yet; today, undo means tapping the filled control again.</div>
<div style="display:flex;flex-direction:column;gap:38px;margin-top:34px">
  <div><div class="capt">1 · Action-first: tap “Mark Journal done”</div><div class="flow"><div class="zoomwrap">{c1_today(markers=False)}</div><div class="arrow">→</div><div class="zoomwrap">{c1_today(after=True, markers=False)}</div>
    <div style="font:14px/1.5 system-ui;max-width:440px;color:#333">The hero advances to the next suggestion. Journal moves into the collapsed Done group, which is now out of sight, so the undo toast (not built) becomes the main way to undo. <b>Risk:</b> the content moves under the user’s thumb; a second quick tap logs a different habit.</div></div></div>
  <div><div class="capt">2 · Balance: tap “+5 min” on Social media</div><div class="flow"><div class="zoomwrap">{c2_today(markers=False)}</div><div class="arrow">→</div><div class="zoomwrap">{c2_today(markers=False, after=True)}</div>
    <div style="font:14px/1.5 system-ui;max-width:440px;color:#333">23 of 30 min crosses the 70% threshold, so the bar turns amber with “Near limit” as text, and the Attention pillar updates to match. Nothing else moves, and undo is the toast. Logging attention takes one tap instead of opening a sheet, but it needs the Phase 2 engine.</div></div></div>
  <div><div class="capt">3 · Companion-led: tap “Log Journal”</div><div class="flow"><div class="zoomwrap">{c3_today(markers=False)}</div><div class="arrow">→</div><div class="zoomwrap">{c3_today(after=True, markers=False)}</div>
    <div style="font:14px/1.5 system-ui;max-width:440px;color:#333">The companion’s sentence and pose update (“back on a steady run”), and the offer disappears instead of suggesting the next habit, which keeps it quiet. The list reorders. The companion only reflects what was logged; it never says “I”.</div></div></div>
</div><div class="legend">{LEGEND}</div>''', 1500, False)

BOARDS["today-balance-states"] = (f'''
<h1>Concept 2 (strongest): states</h1>
<div class="sub">Empty, populated in light and dark, and the interim build that ships before the attention engine. In the interim build the Attention pillar is absent, not a placeholder (APPLE_COMPLIANCE: no placeholder screens or “coming soon” surfaces).</div>
<div class="row" style="gap:44px">
{col("Empty", c2_empty(), [
  "One clear next action, Create a habit (UX.md empty-state rule).",
  "!The attention explainer appears only once Phase 2 ships. Until then it is hidden."])}
{col("Populated · light", c2_today(markers=False), ["Same as the comparison board."])}
{col("Populated · dark", c2_today("tide-dark", markers=False), ["Pillar tiles use surface lightness for elevation; the attention state stays in text."])}
{col("Interim · before Phase 2", c2_interim(), [
  "With attention absent the pillars collapse, so this is effectively Tidewater without the companion card.",
  "This is why concept 2 can be adopted now with no rework later: the Habits section is final."])}
</div><div class="legend">{LEGEND}</div>''', 1900, False)

BOARDS["today-balance-scale"] = (f'''
<h1>Concept 2 (strongest): many habits and large text</h1>
<div class="sub">11 habits (3 done) at default size, top and scrolled, then AX3 Dynamic Type (body about 40pt) in light and dark.</div>
<div class="row" style="gap:44px">
{col("11 habits · top", c2_many_top(), [
  "Pillar pips wrap; past 12 habits they are replaced by text only.",
  "The Habits section grows. Attention is pushed below the fold, which is the main scanning cost of this concept with many habits."])}
{col("11 habits · scrolled", c2_many_scrolled(), [
  "The pillar strip condenses into a sticky inline summary, so attention state stays visible while scrolling habits. (Done group shown expanded by the user.)",
  "!Tapping the attention chip jumps to the Attention section."])}
{col("AX3 · light", c2_ax(), [
  "Pillar tiles stack full-width; each shows a label and one value.",
  "Rows stack, and the control becomes a full-width “Mark done” button (COMPONENT_SPEC §6)."])}
{col("AX3 · dark", c2_ax("tide-dark"), ["Same structure; nothing is truncated."])}
</div><div class="legend">{LEGEND}</div>''', 1900, False)


def main():
    os.makedirs(B.HTML_DIR, exist_ok=True)
    os.makedirs(B.PNG_DIR, exist_ok=True)
    heights = {"today-compare-light": 1440, "today-compare-dark": 1170, "today-interactions": 2130,
               "today-balance-states": 1280, "today-balance-scale": 1330}
    jobs = []
    for key, (body, width, dark) in BOARDS.items():
        p = os.path.join(B.HTML_DIR, key + ".html")
        with open(p, "w") as f:
            f.write(page(key, body, width, dark))
        jobs.append((p, os.path.join(B.PNG_DIR, "board-" + key + ".png"), width, heights[key]))
    singles = {
        "today-c1-action-light": c1_today(markers=False), "today-c2-balance-light": c2_today(markers=False),
        "today-c2-balance-dark": c2_today("tide-dark", markers=False), "today-c2-empty-light": c2_empty(),
        "today-c2-many-light": c2_many_top(), "today-c2-ax3-light": c2_ax(), "today-c3-companion-light": c3_today(markers=False),
    }
    for key, ph in singles.items():
        p = os.path.join(B.HTML_DIR, "screen-" + key + ".html")
        with open(p, "w") as f:
            f.write(B.screen_page(ph).replace("</style>", EXTRA_CSS + "</style>", 1))
        jobs.append((p, os.path.join(B.PNG_DIR, "screen-" + key + ".png"), 433, 892))
    # Untagged stimuli for USER_TEST_TODAY.md: identical data, "not built" outlines hidden.
    hide = ".future{outline:none!important}.future::after{display:none!important}"
    stimuli = {
        "test-T-tidewater": B.tide_today("tide-light", False), "test-1-action": c1_today(markers=False),
        "test-2-balance": c2_today(markers=False), "test-3-companion": c3_today(markers=False),
        "test-T-tidewater-ax3": B.tide_today_ax("tide-light", False), "test-2-balance-ax3": c2_ax(),
    }
    for key, ph in stimuli.items():
        p = os.path.join(B.HTML_DIR, "today-" + key + ".html")
        with open(p, "w") as f:
            f.write(B.screen_page(ph).replace("</style>", EXTRA_CSS + hide + "</style>", 1))
        jobs.append((p, os.path.join(B.PNG_DIR, "today-" + key + ".png"), 433, 892))
    for _, out, _, _ in jobs:
        assert not os.path.basename(out).startswith(("board-A", "board-B", "board-C", "board-app", "screen-A", "screen-B", "screen-C")), out
    if "--html" in sys.argv:
        return
    for job in jobs:
        B.render(*job)
        print("rendered", os.path.relpath(job[1], B.HERE))


if __name__ == "__main__":
    main()
