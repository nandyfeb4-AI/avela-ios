#!/usr/bin/env python3
"""Generates Avela visual-direction mockups as standalone HTML, then renders PNGs.

Exploration artifact only. Not part of the app target, has no dependencies
beyond Python 3 and a local Google Chrome, and reads nothing from the app.

    python3 design/exploration/mockups/build.py          # HTML + PNG
    python3 design/exploration/mockups/build.py --html   # HTML only

Fonts: SF Pro (system-ui), SF Pro Rounded, and New York are loaded from
macOS's /System/Library/Fonts at render time. They are never copied into the
repository. Icons are hand-drawn SVG approximations of the named SF Symbols;
the real app would use Image(systemName:) with the names in ICON_SYSTEM.md.
"""

import html
import os
import re
import subprocess
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
HTML_DIR = os.path.join(HERE, "html")
PNG_DIR = os.path.join(HERE, "png")
CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

PHONE_W, PHONE_H = 393, 852

# ---------------------------------------------------------------------------
# Theme tokens. Values are proposals; contrast checked in VISUAL_DIRECTIONS.md.
# ---------------------------------------------------------------------------

THEMES = {
    "tide-light": dict(
        bg="#F5F3EE", surface="#FFFFFF", surface2="#EEEBE4", ink="#1D2321", ink2="#56605C",
        ink3="#636C67", sep="rgba(29,35,33,.10)", accent="#2C6B63", accentInk="#FFFFFF",
        accentSoft="#DCEAE5", amber="#9A6414", amberSoft="#F5E8D2", clay="#9C5136",
        gold="#B48A1E", glass="rgba(250,249,246,.72)", glassBorder="rgba(255,255,255,.9)",
        shadow="0 1px 2px rgba(29,35,33,.05), 0 6px 18px rgba(29,35,33,.05)", halo="#CFE5DE",
    ),
    "tide-dark": dict(
        bg="#0F1312", surface="#191F1D", surface2="#222A27", ink="#ECEFEC", ink2="#A8B2AD",
        ink3="#78837E", sep="rgba(236,239,236,.10)", accent="#6EBFB1", accentInk="#0B1F1C",
        accentSoft="#1E3834", amber="#E2A955", amberSoft="#3A2E1B", clay="#DC8A6C",
        gold="#E0C060", glass="rgba(38,44,42,.62)", glassBorder="rgba(255,255,255,.10)",
        shadow="none", halo="#1E3834",
    ),
    "almanac-light": dict(
        bg="#FAF7F0", surface="#FFFDF8", surface2="#F1ECE0", ink="#1F1C17", ink2="#5E574B",
        ink3="#766F62", sep="rgba(31,28,23,.14)", accent="#4C6330", accentInk="#FFFFFF",
        accentSoft="#E3E9D6", amber="#9A5F14", amberSoft="#F3E4CA", clay="#9A4B2E",
        gold="#A88120", glass="rgba(250,247,240,.74)", glassBorder="rgba(255,255,255,.9)",
        shadow="none", halo="#E3E9D6",
    ),
    "almanac-dark": dict(
        bg="#15130F", surface="#1D1B16", surface2="#29261F", ink="#EEE7D7", ink2="#B5AC9A",
        ink3="#857D6E", sep="rgba(238,231,215,.13)", accent="#A9C07E", accentInk="#1A2110",
        accentSoft="#2C3420", amber="#E0A85A", amberSoft="#3A2C18", clay="#D9896A",
        gold="#D9BC6A", glass="rgba(41,38,31,.66)", glassBorder="rgba(255,255,255,.08)",
        shadow="none", halo="#2C3420",
    ),
    "dusk-dark": dict(
        bg="#0C0E1C", surface="#161A2E", surface2="#1F2440", ink="#EEF0FF", ink2="#AEB3D6",
        ink3="#7D82A8", sep="rgba(238,240,255,.10)", accent="#A4AEFF", accentInk="#10132A",
        accentSoft="#262C55", amber="#F2B866", amberSoft="#3B2F22", clay="#EE9A7E",
        gold="#F3D27A", glass="rgba(40,45,78,.58)", glassBorder="rgba(255,255,255,.12)",
        shadow="none", halo="#3B4590", mint="#7FD8BE",
    ),
    "dusk-light": dict(
        bg="#F2F1FA", surface="#FFFFFF", surface2="#E8E7F5", ink="#191B33", ink2="#545878",
        ink3="#6B6E8E", sep="rgba(25,27,51,.10)", accent="#4F58C9", accentInk="#FFFFFF",
        accentSoft="#E1E3FA", amber="#965F12", amberSoft="#F6E8D0", clay="#A14F35",
        gold="#9C7A16", glass="rgba(250,250,255,.70)", glassBorder="rgba(255,255,255,.9)",
        shadow="0 1px 2px rgba(25,27,51,.06), 0 8px 22px rgba(25,27,51,.06)", halo="#C9CDF7",
        mint="#2B8C72",
    ),
}


def theme_css():
    out = []
    for name, t in THEMES.items():
        t = dict(t)
        t.setdefault("mint", t["accent"])
        decls = ";".join(f"--{k}:{v}" for k, v in t.items())
        out.append(f".t-{name}{{{decls}}}")
    return "\n".join(out)


BASE_CSS = r"""
@font-face{font-family:"AvRounded";src:url("file:///System/Library/Fonts/SFNSRounded.ttf");font-weight:1 1000}
@font-face{font-family:"AvSerif";src:url("file:///System/Library/Fonts/NewYork.ttf");font-weight:1 1000}
@font-face{font-family:"AvSerif";font-style:italic;src:url("file:///System/Library/Fonts/NewYorkItalic.ttf");font-weight:1 1000}
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:-apple-system,system-ui,"Helvetica Neue",sans-serif;-webkit-font-smoothing:antialiased;background:#E4E2DC;color:#1d1d1f}
.round{font-family:"AvRounded",-apple-system,system-ui,sans-serif}
.serif{font-family:"AvSerif",Georgia,serif}
.tnum{font-variant-numeric:tabular-nums}
.phone{width:393px;height:852px;border-radius:56px;overflow:hidden;position:relative;background:var(--bg);color:var(--ink);
  box-shadow:0 0 0 10px #111,0 0 0 11px #3a3a3a,0 30px 60px rgba(0,0,0,.25);flex:none}
.island{position:absolute;top:11px;left:50%;transform:translateX(-50%);width:124px;height:36px;border-radius:20px;background:#000;z-index:30}
.status{position:absolute;top:0;left:0;right:0;height:54px;display:flex;align-items:center;justify-content:space-between;padding:6px 34px 0 46px;font-weight:600;font-size:17px;z-index:20;color:var(--ink)}
.status .glyphs{display:flex;gap:6px;align-items:center}
.home{position:absolute;bottom:8px;left:50%;transform:translateX(-50%);width:139px;height:5px;border-radius:3px;background:var(--ink);opacity:.85;z-index:30}
.scroll{position:absolute;top:54px;left:0;right:0;bottom:0;overflow:hidden;padding:0 16px}
.glassbtn{width:44px;height:44px;border-radius:22px;background:var(--glass);backdrop-filter:blur(18px) saturate(1.6);-webkit-backdrop-filter:blur(18px) saturate(1.6);
  border:.5px solid var(--glassBorder);box-shadow:0 2px 10px rgba(0,0,0,.08);display:flex;align-items:center;justify-content:center;color:var(--ink)}
.glasspill{height:44px;border-radius:22px;padding:0 16px;background:var(--glass);backdrop-filter:blur(18px) saturate(1.6);border:.5px solid var(--glassBorder);
  box-shadow:0 2px 10px rgba(0,0,0,.08);display:flex;align-items:center;gap:6px;font-size:17px;font-weight:500;color:var(--ink)}
.tabbar{position:absolute;left:16px;right:16px;bottom:22px;height:62px;border-radius:31px;background:var(--glass);backdrop-filter:blur(22px) saturate(1.7);
  -webkit-backdrop-filter:blur(22px) saturate(1.7);border:.5px solid var(--glassBorder);box-shadow:0 8px 28px rgba(0,0,0,.12);display:flex;padding:4px;z-index:25}
.tab{flex:1;display:flex;flex-direction:column;align-items:center;justify-content:center;gap:2px;font-size:10px;font-weight:600;color:var(--ink);border-radius:27px}
.tab.sel{background:var(--surface2);color:var(--accent)}
.fade{position:absolute;left:0;right:0;bottom:0;height:120px;background:linear-gradient(to bottom,transparent,var(--bg) 70%);z-index:24;pointer-events:none}
.marker{position:absolute;width:22px;height:22px;border-radius:11px;background:#E8572A;color:#fff;font:700 12px/22px -apple-system,system-ui;text-align:center;z-index:50;
  box-shadow:0 0 0 2px #fff}
.future{outline:1.5px dashed #7E6BD9;outline-offset:3px;position:relative}
.future::after{content:"FUTURE";position:absolute;top:-17px;right:10px;font:700 9px/1 -apple-system;letter-spacing:.06em;background:#7E6BD9;color:#fff;padding:3px 5px;border-radius:4px}

/* Boards */
.board{padding:48px 56px 56px;background:#E9E7E1;min-height:100vh}
.board.darkboard{background:#1B1C1E;color:#EDEDED}
.board h1{font:700 30px/1.15 -apple-system;letter-spacing:-.01em}
.board .sub{font:400 16px/1.45 -apple-system;color:#5c5c5c;margin-top:6px;max-width:1100px}
.darkboard .sub{color:#A5A5A5}
.row{display:flex;gap:64px;margin-top:40px;align-items:flex-start}
.col{width:413px;display:flex;flex-direction:column;align-items:center}
.col h2{font:600 15px/1.2 -apple-system;margin:0 0 22px;align-self:flex-start;letter-spacing:.02em;text-transform:uppercase;color:#6a6a6a}
.darkboard .col h2{color:#9a9a9a}
.notes{margin-top:34px;align-self:stretch;list-style:none;counter-reset:n}
.notes li{counter-increment:n;font:400 13.5px/1.45 -apple-system;color:#333;padding-left:30px;position:relative;margin-bottom:9px}
.darkboard .notes li{color:#cfcfcf}
.notes li::before{content:counter(n);position:absolute;left:0;top:0;width:20px;height:20px;border-radius:10px;background:#E8572A;color:#fff;font:700 11px/20px -apple-system;text-align:center}
.notes li.plain::before{background:#7E6BD9;content:"F"}
.legend{margin-top:14px;font:400 12.5px/1.4 -apple-system;color:#6a6a6a}
.darkboard .legend{color:#9a9a9a}
"""

# ---------------------------------------------------------------------------
# Icons — approximations of SF Symbols (name shown in specs), 24-unit grid.
# ---------------------------------------------------------------------------

ICONS = {
    "checkmark": '<path d="M5 12.6l4.6 4.6L19.4 7" fill="none" stroke="currentColor" stroke-width="2.6" stroke-linecap="round" stroke-linejoin="round"/>',
    "book.fill": '<path d="M2.5 5.6c3.2-1.4 6.4-1.2 8.7.7v13.4c-2.3-1.6-5.5-1.8-8.7-.6z M21.5 5.6c-3.2-1.4-6.4-1.2-8.7.7v13.4c2.3-1.6 5.5-1.8 8.7-.6z" fill="currentColor"/>',
    "figure.walk": '<circle cx="13.6" cy="3.9" r="2.1" fill="currentColor"/><path d="M12.6 7.6l-2 5.6 3.2 3.2 1 4.8M10.6 13.2l-2.4 7M12.4 8.2l-3.6 2.6-.6 3M12.8 8.4l1.6 3.4 3 1.2" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round"/>',
    "drop.fill": '<path d="M12 2.8C9 7.4 5.8 10.6 5.8 14.6a6.2 6.2 0 0 0 12.4 0c0-4-3.2-7.2-6.2-11.8z" fill="currentColor"/>',
    "moon.stars.fill": '<path d="M13.2 4.4a7.8 7.8 0 1 0 6.6 11.8 6.6 6.6 0 0 1-6.6-11.8z" fill="currentColor"/><path d="M18 3.2l.7 1.6 1.6.7-1.6.7-.7 1.6-.7-1.6-1.6-.7 1.6-.7z" fill="currentColor"/>',
    "pencil.line": '<path d="M4 16.8L15.4 5.4l3.2 3.2L7.2 20H4z" fill="currentColor"/><path d="M12 21h8" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
    "iphone.slash": '<rect x="7" y="2.8" width="10" height="18.4" rx="2.6" fill="none" stroke="currentColor" stroke-width="2"/><path d="M4 4l16 16" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/>',
    "leaf.fill": '<path d="M5 19.5C4.6 10.5 10.4 4.6 20.2 4c.4 9.8-5.4 15.6-15.2 15.5z" fill="currentColor"/><path d="M5 19.5L13 11.5" stroke="var(--bg)" stroke-width="1.4" stroke-linecap="round"/>',
    "hourglass": '<path d="M6 3h12M6 21h12M7.5 3c0 5 9 5 9 9s-9 4-9 9M16.5 3c0 5-9 5-9 9s9 4 9 9" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/><path d="M9.5 19h5l-2.5-2.6z" fill="currentColor"/>',
    "chevron.right": '<path d="M9 5l7 7-7 7" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>',
    "chevron.left": '<path d="M15 5l-7 7 7 7" fill="none" stroke="currentColor" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/>',
    "plus": '<path d="M12 5v14M5 12h14" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"/>',
    "sun.max": '<circle cx="12" cy="12" r="4.2" fill="none" stroke="currentColor" stroke-width="2"/><path d="M12 2.5v2.2M12 19.3v2.2M2.5 12h2.2M19.3 12h2.2M5.3 5.3l1.5 1.5M17.2 17.2l1.5 1.5M5.3 18.7l1.5-1.5M17.2 6.8l1.5-1.5" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
    "sun.max.fill": '<circle cx="12" cy="12" r="4.8" fill="currentColor"/><path d="M12 2.5v2.2M12 19.3v2.2M2.5 12h2.2M19.3 12h2.2M5.3 5.3l1.5 1.5M17.2 17.2l1.5 1.5M5.3 18.7l1.5-1.5M17.2 6.8l1.5-1.5" stroke="currentColor" stroke-width="2.1" stroke-linecap="round"/>',
    "chart.bar.xaxis": '<path d="M3.5 20.5h17" stroke="currentColor" stroke-width="2" stroke-linecap="round"/><rect x="5" y="11" width="3.4" height="7" rx="1" fill="currentColor"/><rect x="10.3" y="5" width="3.4" height="13" rx="1" fill="currentColor"/><rect x="15.6" y="8.5" width="3.4" height="9.5" rx="1" fill="currentColor"/>',
    "calendar": '<rect x="3.5" y="5" width="17" height="15.5" rx="3" fill="none" stroke="currentColor" stroke-width="2"/><path d="M3.5 9.5h17M8 3v4M16 3v4" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
    "gearshape": '<circle cx="12" cy="12" r="6.6" fill="none" stroke="currentColor" stroke-width="3.2" stroke-dasharray="2.6 2.6"/><circle cx="12" cy="12" r="5.6" fill="none" stroke="currentColor" stroke-width="1.8"/><circle cx="12" cy="12" r="2.2" fill="none" stroke="currentColor" stroke-width="1.8"/>',
    "arrow.clockwise": '<path d="M19 12.5a7 7 0 1 1-2.1-5" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round"/><path d="M18.8 3.6v4.6h-4.6" fill="none" stroke="currentColor" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round"/>',
    "sparkles": '<path d="M10 3l1.6 4.8L16.4 9.4l-4.8 1.6L10 15.8 8.4 11 3.6 9.4l4.8-1.6z" fill="currentColor"/><path d="M18 13.5l.9 2.4 2.4.9-2.4.9-.9 2.4-.9-2.4-2.4-.9 2.4-.9z" fill="currentColor"/>',
    "forward.end": '<path d="M5 6l9 6-9 6z" fill="currentColor"/><path d="M17.5 6v12" stroke="currentColor" stroke-width="2.4" stroke-linecap="round"/>',
    "ellipsis": '<circle cx="5.5" cy="12" r="1.9" fill="currentColor"/><circle cx="12" cy="12" r="1.9" fill="currentColor"/><circle cx="18.5" cy="12" r="1.9" fill="currentColor"/>',
    "bell": '<path d="M6 16.5V11a6 6 0 0 1 12 0v5.5l1.5 1.8h-15z" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linejoin="round"/><path d="M10 20.5a2.2 2.2 0 0 0 4 0" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/>',
    "archivebox": '<rect x="3" y="4" width="18" height="5" rx="1.4" fill="none" stroke="currentColor" stroke-width="1.9"/><path d="M4.6 9v9.5a1.8 1.8 0 0 0 1.8 1.8h11.2a1.8 1.8 0 0 0 1.8-1.8V9M9.5 13h5" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/>',
    "clock": '<circle cx="12" cy="12" r="8.6" fill="none" stroke="currentColor" stroke-width="1.9"/><path d="M12 7v5.4l3.4 2" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/>',
    "arrow.up.right": '<path d="M7 17L17 7M9 7h8v8" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round" stroke-linejoin="round"/>',
    "square.and.pencil": '<path d="M11 4.5H6.5a2.5 2.5 0 0 0-2.5 2.5v10.5A2.5 2.5 0 0 0 6.5 20H17a2.5 2.5 0 0 0 2.5-2.5V13" fill="none" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/><path d="M10 14.2l.6-3L18.4 3.4l2.4 2.4-7.8 7.8z" fill="currentColor"/>',
    "wifi": '<path d="M2.5 9.2a13.5 13.5 0 0 1 19 0M5.6 12.4a9 9 0 0 1 12.8 0M8.7 15.6a4.6 4.6 0 0 1 6.6 0" fill="none" stroke="currentColor" stroke-width="2.3" stroke-linecap="round"/><circle cx="12" cy="19" r="1.7" fill="currentColor"/>',
    "circle.dashed": '<circle cx="12" cy="12" r="8.6" fill="none" stroke="currentColor" stroke-width="1.9" stroke-dasharray="3 2.6"/>',
    "list.bullet": '<circle cx="5" cy="6.5" r="1.6" fill="currentColor"/><circle cx="5" cy="12" r="1.6" fill="currentColor"/><circle cx="5" cy="17.5" r="1.6" fill="currentColor"/><path d="M9.5 6.5h10M9.5 12h10M9.5 17.5h10" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
    "timer": '<circle cx="12" cy="13" r="7.6" fill="none" stroke="currentColor" stroke-width="1.9"/><path d="M12 13V9M10 2.8h4" stroke="currentColor" stroke-width="1.9" stroke-linecap="round"/>',
    "cup.and.saucer.fill": '<path d="M5 6h11v5.5a5.5 5.5 0 0 1-11 0zM16 7.5h1.6a2.6 2.6 0 0 1 0 5.2H16" fill="currentColor"/><path d="M3 19.5h16" stroke="currentColor" stroke-width="2" stroke-linecap="round"/>',
}


def icon(name, size=22, color="currentColor", extra=""):
    body = ICONS[name]
    return (f'<svg width="{size}" height="{size}" viewBox="0 0 24 24" style="color:{color};flex:none;display:block" '
            f'aria-label="{name}" {extra}>{body}</svg>')


def status_bar():
    battery = ('<svg width="27" height="13" viewBox="0 0 27 13"><rect x=".5" y=".5" width="23" height="12" rx="3.5" fill="none" '
               'stroke="currentColor" opacity=".4"/><rect x="2" y="2" width="20" height="9" rx="2" fill="currentColor"/>'
               '<path d="M25 4.5v4" stroke="currentColor" stroke-width="1.5" opacity=".4" stroke-linecap="round"/></svg>')
    bars = ('<svg width="18" height="12" viewBox="0 0 18 12">' + "".join(
        f'<rect x="{i*4.6}" y="{9-i*3}" width="3.2" height="{3+i*3}" rx="1" fill="currentColor"/>' for i in range(4)) + '</svg>')
    return (f'<div class="island"></div><div class="status"><span class="tnum">9:41</span>'
            f'<span class="glyphs">{bars}{icon("wifi", 17)}{battery}</span></div>')


def tabbar(selected="Today", style=""):
    tabs = [("Today", "sun.max"), ("Insights", "chart.bar.xaxis"), ("History", "calendar"), ("Settings", "gearshape")]
    items = ""
    for label, ic in tabs:
        sel = " sel" if label == selected else ""
        ic_name = "sun.max.fill" if (label == "Today" and sel) else ic
        items += f'<div class="tab{sel}">{icon(ic_name, 24)}<span>{label}</span></div>'
    return f'<div class="fade"></div><div class="tabbar" style="{style}">{items}</div>'


def phone(theme, inner, markers=(), extra_cls=""):
    marks = "".join(f'<div class="marker" style="left:{x}px;top:{y}px">{i + 1}</div>' for i, (x, y) in enumerate(markers))
    return (f'<div class="phone t-{theme} {extra_cls}">{status_bar()}{inner}<div class="home"></div>{marks}</div>')


# ---------------------------------------------------------------------------
# Companion placeholder. Original, deliberately generic silhouette: a rounded
# pebble body with two soft ears. Final species/art is a brand-art deliverable.
# ---------------------------------------------------------------------------

def companion(size=56, state="calm", body="var(--accent)", face="var(--surface)", halo="var(--halo)"):
    eyes = {
        "calm": '<path d="M37 52q4 3 8 0M55 52q4 3 8 0" fill="none" stroke="FACE" stroke-width="3.2" stroke-linecap="round"/>',
        "focused": '<circle cx="41" cy="52" r="3.2" fill="FACE"/><circle cx="59" cy="52" r="3.2" fill="FACE"/>',
        "recovering": '<path d="M37 53q4-3 8 0M55 53q4-3 8 0" fill="none" stroke="FACE" stroke-width="3.2" stroke-linecap="round"/>',
    }[state].replace("FACE", face)
    return (f'<svg width="{size}" height="{size}" viewBox="0 0 100 100" style="flex:none;display:block" aria-label="companion ({state})">'
            f'<circle cx="50" cy="54" r="46" fill="{halo}"/>'
            f'<path d="M28 40 L30 18 L44 31 Z M72 40 L70 18 L56 31 Z" fill="{body}" stroke="{body}" stroke-width="5" stroke-linejoin="round"/>'
            f'<ellipse cx="50" cy="58" rx="27" ry="25" fill="{body}"/>'
            f'{eyes}<ellipse cx="50" cy="63" rx="3" ry="2" fill="{face}" opacity=".85"/></svg>')


# ---------------------------------------------------------------------------
# Shared fixture (one coherent dataset across every mockup).
# Today = Saturday, October 3. Reviewed week = Sun Sep 21 – Sat Sep 27.
# ---------------------------------------------------------------------------

HABITS = [
    dict(name="Drink water", icon="drop.fill", ctx="Every day · 4-day streak", done=False, kind="daily"),
    dict(name="Read", icon="book.fill", ctx="2 of 3 this week", done=False, kind="weekly", got=2, target=3),
    dict(name="Journal", icon="pencil.line", ctx="Rebuilding · 2 of 3 good days", done=False, kind="recovering"),
    dict(name="Morning walk", icon="figure.walk", ctx="Every day · 6-day streak", done=True, kind="daily"),
    dict(name="No phone in bed", icon="iphone.slash", ctx="Cut down · avoided last night", done=True, kind="avoid"),
]

# 14-day Journal ledger, Sun Sep 20 → Sat Oct 3. d=done, m=miss, s=skip, t=today (open)
JOURNAL_14 = list("dddmdddsdddmdd")[:13] + ["t"]
JOURNAL_14 = ["d", "d", "d", "m", "d", "d", "s", "d", "d", "d", "m", "d", "d", "t"]
# check: resolved = 13 - 1 skip = 12; misses 2 → 10 of 12 = 83%; current run 2 since Wed Sep 30.

WEEK_RESULTS = [  # reviewed week Sep 21–27
    ("Morning walk", "figure.walk", "7 of 7 days", 100),
    ("Read", "book.fill", "3 of 3 · goal met", 100),
    ("Drink water", "drop.fill", "6 of 7 days", 86),
    ("Journal", "pencil.line", "5 of 6 days · 1 skip excused", 83),
    ("No phone in bed", "iphone.slash", "Avoided 3 of 7 nights", 43),
]
# average = (100+100+86+83+43)/5 = 82.4 → 82%


def esc(s):
    return html.escape(s)


# ===========================================================================
# Direction A — Tidewater (recommended)
# ===========================================================================

def tide_progress(h):
    if h["kind"] == "weekly":
        pills = "".join(
            f'<span style="width:18px;height:6px;border-radius:3px;background:{"var(--accent)" if i < h["got"] else "var(--surface2)"}"></span>'
            for i in range(h["target"]))
        return f'<span style="display:inline-flex;gap:3px;margin-right:7px;vertical-align:1px">{pills}</span>'
    if h["kind"] == "recovering":
        return f'<span style="display:inline-block;vertical-align:-3px;margin-right:4px">{icon("arrow.clockwise", 14, "var(--amber)")}</span>'
    return ""


def tide_check(done, size=44, ax=False):
    if done:
        return (f'<div style="width:{size}px;height:{size}px;border-radius:{size//2}px;background:var(--accent);display:flex;align-items:center;'
                f'justify-content:center;flex:none">{icon("checkmark", size*0.5, "var(--accentInk)")}</div>')
    return (f'<div style="width:{size}px;height:{size}px;border-radius:{size//2}px;border:2.5px solid var(--ink3);opacity:.75;flex:none"></div>')


def tide_row(h):
    ctx_color = "var(--amber)" if h["kind"] == "recovering" else "var(--ink2)"
    ink = "var(--ink2)" if h["done"] else "var(--ink)"
    tile_bg = "var(--accentSoft)"
    return f'''
    <div style="display:flex;align-items:center;gap:13px;padding:11px 14px 11px 12px;min-height:68px">
      <div style="width:40px;height:40px;border-radius:12px;background:{tile_bg};display:flex;align-items:center;justify-content:center;flex:none">
        {icon(h["icon"], 21, "var(--accent)")}</div>
      <div style="flex:1;min-width:0">
        <div style="font-size:17px;font-weight:600;color:{ink};letter-spacing:-.01em">{esc(h["name"])}</div>
        <div style="font-size:14px;color:{ctx_color};margin-top:2px" class="tnum">{tide_progress(h)}{esc(h["ctx"])}</div>
      </div>
      {tide_check(h["done"])}
    </div>'''


def tide_card(inner, style=""):
    return f'<div style="background:var(--surface);border-radius:22px;box-shadow:var(--shadow);{style}">{inner}</div>'


def tide_sep():
    return '<div style="height:.5px;background:var(--sep);margin-left:66px"></div>'


def tide_section(label, trailing=""):
    return (f'<div style="display:flex;justify-content:space-between;align-items:baseline;margin:20px 6px 8px">'
            f'<span style="font-size:15px;font-weight:600;color:var(--ink2)">{label}</span>'
            f'<span style="font-size:15px;color:var(--ink3)" class="tnum">{trailing}</span></div>')


def tide_today(theme="tide-light", markers=True):
    todo = [h for h in HABITS if not h["done"]]
    done = [h for h in HABITS if h["done"]]
    todo_html = tide_sep().join(tide_row(h) for h in todo)
    done_html = tide_sep().join(tide_row(h) for h in done)
    inner = f'''
    <div class="scroll">
      <div style="display:flex;justify-content:flex-end;padding-top:4px">{'<div class="glassbtn">' + icon("plus", 22) + '</div>'}</div>
      <div style="font-size:13px;font-weight:600;color:var(--ink3);letter-spacing:.04em;text-transform:uppercase;margin:-6px 4px 0">Saturday, October 3</div>
      <div style="font-size:34px;font-weight:700;letter-spacing:-.02em;margin:0 4px 14px">Today</div>
      {tide_card(f"""<div style="display:flex;align-items:center;gap:14px;padding:14px 16px">{companion(58)}
          <div style="flex:1"><div style="font-size:17px;font-weight:600">A steady morning.</div>
          <div style="font-size:14px;color:var(--ink2);margin-top:2px">2 of 5 done · Social media well within today’s budget</div></div></div>""")}
      {tide_section("To do", "3")}
      {tide_card(todo_html)}
      {tide_section("Done", "2")}
      {tide_card(done_html)}
      {tide_section("Attention")}
      <div class="future">{tide_card(f"""<div style="display:flex;align-items:center;gap:13px;padding:14px">
          <div style="width:40px;height:40px;border-radius:12px;background:var(--surface2);display:flex;align-items:center;justify-content:center">{icon("hourglass", 21, "var(--ink2)")}</div>
          <div style="flex:1"><div style="display:flex;justify-content:space-between"><span style="font-size:17px;font-weight:600">Social media</span>
          <span class="round tnum" style="font-size:16px;font-weight:600">18<span style="color:var(--ink3);font-weight:500"> / 30 min</span></span></div>
          <div style="height:6px;border-radius:3px;background:var(--surface2);margin-top:9px"><div style="width:60%;height:6px;border-radius:3px;background:var(--accent)"></div></div></div></div>""")}</div>
    </div>{tabbar("Today")}'''
    m = [(2, 100), (2, 190), (2, 392), (2, 462), (2, 572)] if markers else []
    return phone(theme, inner, m)


def tide_ledger(cells, size=34, gap=7):
    labels = "SMTWTFS"
    out = []
    for i, c in enumerate(cells):
        if c == "d":
            st = "background:var(--accent);"
            inner = icon("checkmark", 16, "var(--accentInk)")
        elif c == "m":
            st = "border:2px solid var(--ink3);opacity:.7;"
            inner = ""
        elif c == "s":
            st = "background:var(--surface2);"
            inner = icon("forward.end", 13, "var(--ink3)")
        else:
            st = "border:2px dashed var(--accent);"
            inner = ""
        out.append(f'<div style="width:{size}px;height:{size}px;border-radius:{size//2}px;{st}display:flex;align-items:center;justify-content:center">{inner}</div>')
    head = "".join(f'<div style="width:{size}px;text-align:center;font-size:12px;font-weight:600;color:var(--ink3)">{d}</div>' for d in labels)
    rows = f'<div style="display:flex;gap:{gap}px">{"".join(out[:7])}</div><div style="display:flex;gap:{gap}px;margin-top:{gap}px">{"".join(out[7:])}</div>'
    return f'<div style="display:flex;gap:{gap}px;margin-bottom:8px">{head}</div>{rows}'


def tide_stat(label, value, unit, note=""):
    return f'''<div style="flex:1;background:var(--surface);border-radius:20px;padding:14px 14px 13px;box-shadow:var(--shadow)">
      <div style="font-size:13px;font-weight:600;color:var(--ink2)">{label}</div>
      <div class="round tnum" style="font-size:28px;font-weight:700;margin-top:4px;letter-spacing:-.01em">{value}<span style="font-size:16px;font-weight:600;color:var(--ink2)"> {unit}</span></div>
      <div style="font-size:12.5px;color:var(--ink3);margin-top:2px">{note}</div></div>'''


def tide_detail(theme="tide-light", markers=True):
    inner = f'''
    <div class="scroll">
      <div style="display:flex;justify-content:space-between;padding-top:4px">
        <div class="glassbtn">{icon("chevron.left", 22)}</div>
        <div class="glasspill">Edit</div></div>
      <div style="display:flex;align-items:center;gap:14px;margin:14px 4px 18px">
        <div style="width:60px;height:60px;border-radius:18px;background:var(--accentSoft);display:flex;align-items:center;justify-content:center">{icon("pencil.line", 30, "var(--accent)")}</div>
        <div><div style="font-size:28px;font-weight:700;letter-spacing:-.02em">Journal</div>
        <div style="font-size:15px;color:var(--ink2)">Mindfulness · Build up · Every day</div></div></div>
      {tide_card(f"""<div style="padding:16px">
        <div style="display:flex;align-items:center;gap:8px;color:var(--amber);font-size:14px;font-weight:600">{icon("arrow.clockwise", 16, "var(--amber)")} REBUILDING MOMENTUM</div>
        <div style="font-size:17px;font-weight:600;margin-top:6px;line-height:1.3">2 good days since your miss on Wednesday.</div>
        <div style="font-size:15px;color:var(--ink2);margin-top:3px">One more and you’re back on a steady run.</div>
        <div style="display:flex;gap:5px;margin-top:12px">{''.join(f'<span style="flex:1;height:6px;border-radius:3px;background:{"var(--amber)" if i < 2 else "var(--amberSoft)"}"></span>' for i in range(3))}</div>
        </div>""")}
      <div style="display:flex;gap:10px;margin-top:12px">
        {tide_stat("Current streak", "2", "days", "Best: 12 days")}
        {tide_stat("Consistency", "83", "%", "10 of 12 days")}
      </div>
      {tide_section("Last 14 days", "Sep 20 – Oct 3")}
      {tide_card(f"""<div style="padding:14px 16px 12px">{tide_ledger(JOURNAL_14)}
        <div style="display:flex;gap:14px;margin-top:12px;font-size:12.5px;color:var(--ink2)">
          <span style="display:flex;align-items:center;gap:5px"><span style="width:10px;height:10px;border-radius:5px;background:var(--accent)"></span>Done</span>
          <span style="display:flex;align-items:center;gap:5px"><span style="width:10px;height:10px;border-radius:5px;border:1.5px solid var(--ink3)"></span>Missed</span>
          <span style="display:flex;align-items:center;gap:5px"><span style="width:10px;height:10px;border-radius:5px;background:var(--surface2)"></span>Skipped</span>
          <span style="display:flex;align-items:center;gap:5px"><span style="width:10px;height:10px;border-radius:5px;border:1.5px dashed var(--accent)"></span>Today</span></div></div>""")}
      <div style="margin-top:14px"></div>
      {tide_card(f"""<div style="display:flex;align-items:center;gap:12px;padding:14px 16px">{icon("calendar", 20, "var(--accent)")}<span style="flex:1;font-size:17px">View history</span>{icon("chevron.right", 15, "var(--ink3)")}</div>
        {tide_sep().replace("66px", "48px")}
        <div style="display:flex;align-items:center;gap:12px;padding:14px 16px">{icon("archivebox", 20, "var(--ink2)")}<span style="flex:1;font-size:17px">Archive habit…</span></div>""")}
    </div>'''
    m = [(2, 212), (2, 384), (2, 533), (2, 708)] if markers else []
    return phone(theme, inner, m)


def tide_insights(theme="tide-light", markers=True):
    def result_row(name, ic, ctx, pct, tone="var(--accent)"):
        return f'''<div style="display:flex;align-items:center;gap:12px;padding:12px 16px">
          <div style="width:34px;height:34px;border-radius:10px;background:var(--accentSoft);display:flex;align-items:center;justify-content:center">{icon(ic, 18, "var(--accent)")}</div>
          <div style="flex:1"><div style="font-size:16px;font-weight:600">{name}</div><div style="font-size:13.5px;color:var(--ink2)">{ctx}</div></div>
          <span class="round tnum" style="font-size:17px;font-weight:600;color:{tone}">{pct}%</span></div>'''
    bars = ""
    days = [("S", 4, 5), ("M", 4, 5), ("T", 3, 5), ("W", 4, 5), ("T", 5, 5), ("F", 4, 5), ("S", 3, 4)]
    for d, got, of in days:
        h = 62 * got / 5
        bars += (f'<div style="flex:1;display:flex;flex-direction:column;align-items:center;gap:5px"><div style="height:62px;width:22px;display:flex;align-items:flex-end">'
                 f'<div style="width:22px;height:{h}px;border-radius:6px;background:var(--accent);opacity:{1 if got == of else .38}"></div></div>'
                 f'<span style="font-size:12px;font-weight:600;color:var(--ink3)">{d}</span></div>')
    inner = f'''
    <div class="scroll">
      <div style="display:flex;justify-content:flex-end;gap:8px;padding-top:4px">
        <div class="glasspill" style="padding:0 6px;gap:0">{icon("chevron.left", 20)}<span style="font-size:15px;padding:0 6px" class="tnum">Sep 21 – 27</span>{icon("chevron.right", 20, "var(--ink3)")}</div></div>
      <div style="font-size:34px;font-weight:700;letter-spacing:-.02em;margin:6px 4px 14px">Insights</div>
      {tide_card(f"""<div style="padding:18px 18px 16px">
        <div style="display:flex;align-items:flex-end;gap:10px"><span class="round tnum" style="font-size:56px;font-weight:700;line-height:.95;letter-spacing:-.02em">82<span style="font-size:30px">%</span></span>
          <span style="font-size:15px;color:var(--ink2);padding-bottom:6px">average consistency<br>across 5 habits</span></div>
        <div style="display:inline-flex;align-items:center;gap:5px;margin-top:12px;padding:5px 10px;border-radius:12px;background:var(--accentSoft);color:var(--accent);font-size:14px;font-weight:600">
          {icon("arrow.up.right", 14, "var(--accent)")} 6 points vs. Sep 14 – 20</div>
        <div style="font-size:12.5px;color:var(--ink3);margin-top:7px">Compared across the same 5 habits on unchanged schedules.</div>
        </div>""")}
      {tide_section("Went well")}
      {tide_card(result_row("Morning walk", "figure.walk", "7 of 7 days", 100) + tide_sep().replace("66px", "62px") + result_row("Read", "book.fill", "3 of 3 · weekly goal met", 100))}
      {tide_section("Needs recovery")}
      {tide_card(result_row("No phone in bed", "iphone.slash", "Avoided 3 of 7 nights", 43, "var(--amber)"))}
      <div class="future" style="margin-top:22px">{tide_section("Most complete day", "Thursday · 5 of 5").replace("margin:20px", "margin:4px")}{tide_card(f'<div style="display:flex;gap:4px;padding:14px 16px 12px">{bars}</div>')}</div>
      {tide_section("Attention budget")}
      <div class="future">{tide_card('<div style="padding:14px 16px;font-size:16px">Social media stayed within budget on <b>5 of 7 days</b>.</div>')}</div>
    </div>{tabbar("Insights")}'''
    m = [(2, 205), (2, 392), (2, 552)] if markers else []
    return phone(theme, inner, m)


def tide_today_ax(theme="tide-light", markers=True):
    """Today at accessibility size AX3 (body ≈ 40pt in HIG table; see notes)."""
    def ax_row(h, last=False):
        ctx_color = "var(--amber)" if h["kind"] == "recovering" else "var(--ink2)"
        return f'''<div style="padding:16px 16px 18px;{'' if last else 'border-bottom:.5px solid var(--sep);'}">
          <div style="display:flex;align-items:center;gap:12px">{icon(h["icon"], 36, "var(--accent)")}</div>
          <div style="font-size:40px;font-weight:600;line-height:1.12;margin-top:8px;letter-spacing:-.01em">{esc(h["name"])}</div>
          <div style="font-size:33px;line-height:1.18;color:{ctx_color};margin-top:4px">{esc(h["ctx"])}</div>
          <div style="margin-top:14px;height:64px;border-radius:32px;{'background:var(--accent);color:var(--accentInk)' if h['done'] else 'border:2.5px solid var(--accent);color:var(--accent)'};
            display:flex;align-items:center;justify-content:center;gap:10px;font-size:30px;font-weight:600">
            {icon("checkmark", 30, "currentColor") if h['done'] else ''}{'Done' if h['done'] else 'Mark done'}</div></div>'''
    inner = f'''
    <div class="scroll">
      <div style="display:flex;justify-content:flex-end;padding-top:4px"><div class="glassbtn">{icon("plus", 22)}</div></div>
      <div style="font-size:40px;font-weight:700;letter-spacing:-.02em;margin:0 4px 12px;line-height:1.1">Today</div>
      {tide_card(f"""<div style="padding:16px">{companion(64)}<div style="font-size:40px;font-weight:600;line-height:1.12;margin-top:10px">A steady morning.</div>
        <div style="font-size:33px;color:var(--ink2);line-height:1.18;margin-top:4px">2 of 5 done</div></div>""")}
      <div style="margin-top:14px"></div>
      {tide_card(ax_row(HABITS[0]) + ax_row(HABITS[1], True))}
    </div>{tabbar("Today")}'''
    return phone(theme, inner, [(4, 150), (4, 400), (4, 540)] if markers else [])


# ===========================================================================
# Direction B — Almanac (editorial)
# ===========================================================================

def alm_check(done):
    if done:
        return (f'<div style="width:28px;height:28px;border-radius:9px;background:var(--accent);display:flex;align-items:center;justify-content:center;flex:none">'
                f'{icon("checkmark", 17, "var(--accentInk)")}</div>')
    return '<div style="width:28px;height:28px;border-radius:9px;border:2px solid var(--ink3);flex:none"></div>'


def alm_row(h, last=False):
    ctx = h["ctx"]
    tally = ""
    if h["kind"] == "weekly":
        tally = '<span style="letter-spacing:3px;color:var(--accent);font-weight:700;margin-right:6px">' + "●" * h["got"] + '<span style="color:var(--ink3);font-weight:400">' + "○" * (h["target"] - h["got"]) + '</span></span>'
    color = "var(--amber)" if h["kind"] == "recovering" else "var(--ink2)"
    name_style = "color:var(--ink2)" if h["done"] else ""
    return f'''<div style="display:flex;align-items:flex-start;gap:14px;padding:14px 4px;{'' if last else 'border-bottom:.5px solid var(--sep)'}">
      <div style="padding:10px 4px 0 0;margin:-8px -4px -8px -8px;padding:8px">{alm_check(h["done"])}</div>
      <div style="flex:1"><div style="font-size:17px;font-weight:500;{name_style}">{esc(h["name"])}</div>
        <div style="font-size:14px;color:{color};margin-top:2px" class="tnum">{tally}{esc(ctx)}</div></div>
      <div style="padding-top:3px">{icon(h["icon"], 18, "var(--ink3)")}</div></div>'''


def alm_head(text, top=26):
    return f'<div class="serif" style="font-size:20px;font-weight:600;margin:{top}px 4px 2px">{text}</div>'


def alm_today(theme="almanac-light", markers=True):
    rows = "".join(alm_row(h, i == len(HABITS) - 1) for i, h in enumerate(HABITS))
    inner = f'''
    <div class="scroll" style="padding:0 20px">
      <div style="display:flex;justify-content:flex-end;padding-top:4px"><div class="glassbtn">{icon("plus", 22)}</div></div>
      <div style="display:flex;align-items:flex-end;justify-content:space-between;margin-top:-4px">
        <div><div class="serif" style="font-size:38px;font-weight:600;letter-spacing:-.01em;line-height:1.05">Saturday</div>
        <div style="font-size:16px;color:var(--ink2);margin-top:4px">October 3</div></div>
        {companion(62, "calm", "var(--accent)", "var(--bg)", "transparent")}</div>
      <div class="serif" style="font-style:italic;font-size:19px;line-height:1.35;color:var(--ink);margin:16px 0 4px;padding:14px 0;border-top:.5px solid var(--sep);border-bottom:.5px solid var(--sep)">
        “Two done, three to go. An unhurried start.”</div>
      {alm_head("Habits")}
      {rows}
      <div class="future" style="margin-top:8px">{alm_head("Attention", 18)}
        <div style="display:flex;justify-content:space-between;font-size:16px;padding:8px 4px 0"><span>Social media</span><span class="tnum">18 of 30 min</span></div>
        <div style="height:2px;background:var(--sep);margin:9px 4px 8px"><div style="width:60%;height:2px;background:var(--accent)"></div></div></div>
    </div>{tabbar("Today")}'''
    m = [(2, 120), (2, 200), (2, 285), (2, 390)] if markers else []
    return phone(theme, inner, m)


def alm_detail(theme="almanac-light", markers=True):
    cells = ""
    for c in JOURNAL_14:
        st = {"d": "background:var(--accent)", "m": "border:1.5px solid var(--ink3)", "s": "background:var(--surface2);",
              "t": "border:1.5px dashed var(--accent)"}[c]
        cells += f'<div style="width:36px;height:36px;border-radius:8px;{st}"></div>'
    inner = f'''
    <div class="scroll" style="padding:0 20px">
      <div style="display:flex;justify-content:space-between;padding-top:4px"><div class="glassbtn">{icon("chevron.left", 22)}</div><div class="glasspill">Edit</div></div>
      <div class="serif" style="font-size:36px;font-weight:600;margin-top:14px">Journal</div>
      <div style="font-size:15px;color:var(--ink2);margin-top:2px">Every day · Mindfulness · Build up</div>
      <div class="serif" style="font-size:20px;line-height:1.4;margin-top:18px;padding-left:14px;border-left:3px solid var(--amber)">
        You’re rebuilding momentum — <span style="color:var(--amber)">two good days</span> since Wednesday’s miss. One more and you’re back on a steady run.</div>
      {alm_head("Last fourteen days")}
      <div style="display:grid;grid-template-columns:repeat(7,36px);gap:8px;justify-content:space-between;margin:12px 4px 6px">{cells}</div>
      <div style="font-size:13px;color:var(--ink3);margin:6px 4px">Sep 20 – Oct 3 · filled = done, outline = missed, tinted = skipped</div>
      {alm_head("By the numbers")}
      {''.join(f'<div style="display:flex;justify-content:space-between;padding:12px 4px;border-bottom:.5px solid var(--sep);font-size:17px"><span>{a}</span><span class="tnum" style="font-weight:600">{b}</span></div>' for a, b in [("Current streak", "2 days"), ("Best streak", "12 days"), ("Consistency", "10 of 12 · 83%")])}
      <div style="display:flex;justify-content:space-between;padding:14px 4px;font-size:17px;color:var(--accent)"><span>View history</span>{icon("chevron.right", 15, "var(--ink3)")}</div>
    </div>'''
    m = [(2, 205), (2, 330), (2, 470)] if markers else []
    return phone(theme, inner, m)


def alm_insights(theme="almanac-light", markers=True):
    def para(head, body, future=False):
        f = ' class="future"' if future else ""
        return f'<div{f} style="margin-top:20px"><div style="font-size:12px;font-weight:700;letter-spacing:.08em;color:var(--ink3);text-transform:uppercase;margin:0 2px 4px">{head}</div><div class="serif" style="font-size:18px;line-height:1.42;margin:0 2px">{body}</div></div>'
    inner = f'''
    <div class="scroll" style="padding:0 20px">
      <div style="display:flex;justify-content:space-between;padding-top:4px"><div class="glassbtn">{icon("chevron.left", 22)}</div><div class="glassbtn">{icon("chevron.right", 22, "var(--ink3)")}</div></div>
      <div style="font-size:15px;color:var(--ink2);margin-top:10px">Weekly review</div>
      <div class="serif" style="font-size:32px;font-weight:600;line-height:1.1;margin-top:2px">The week of<br>September 21</div>
      <div style="display:flex;align-items:baseline;gap:12px;margin-top:18px;padding:16px 0;border-top:.5px solid var(--sep);border-bottom:.5px solid var(--sep)">
        <span class="serif tnum" style="font-size:60px;font-weight:500;line-height:.9">82%</span>
        <span style="font-size:15px;color:var(--ink2);line-height:1.35">average across five habits<br><span style="color:var(--accent);font-weight:600">6 points higher</span> than the week before</span></div>
      {para("Went well", "<b>Morning walk</b> and <b>Read</b> were both perfect: seven of seven days, and three of three for the week.")}
      {para("Needs recovery", "<b>No phone in bed</b> held on three of seven nights. Worth a gentler target, or a reminder at 10 PM?")}
      {para("Attention", "Social media stayed within its 30-minute budget on five of seven days.", True)}
      {para("One observation", "Thursday was your most complete day — all five habits.")}
    </div>{tabbar("Insights")}'''
    m = [(2, 225), (2, 345), (2, 645)] if markers else []
    return phone(theme, inner, m)


# ===========================================================================
# Direction C — Dusk (immersive, dark-first)
# ===========================================================================

def ring(pct, size=64, stroke=6, color="var(--accent)", track="var(--surface2)", inner=""):
    r = (size - stroke) / 2
    c = 2 * 3.14159 * r
    return (f'<div style="position:relative;width:{size}px;height:{size}px;flex:none"><svg width="{size}" height="{size}" style="transform:rotate(-90deg)">'
            f'<circle cx="{size/2}" cy="{size/2}" r="{r}" fill="none" stroke="{track}" stroke-width="{stroke}"/>'
            f'<circle cx="{size/2}" cy="{size/2}" r="{r}" fill="none" stroke="{color}" stroke-width="{stroke}" stroke-linecap="round" stroke-dasharray="{c*pct/100} {c}"/></svg>'
            f'<div style="position:absolute;inset:0;display:flex;align-items:center;justify-content:center">{inner}</div></div>')


def dusk_tile(h):
    pct = 100 if h["done"] else (67 if h["kind"] == "weekly" else (66 if h["kind"] == "recovering" else 0))
    col = "var(--mint)" if h["done"] else ("var(--amber)" if h["kind"] == "recovering" else "var(--accent)")
    ctx = {"Drink water": "4-day streak", "Read": "2 of 3 this week", "Journal": "Rebuilding · 2 of 3",
           "Morning walk": "Done · 6 days", "No phone in bed": "Avoided"}[h["name"]]
    return f'''<div style="background:var(--surface);border-radius:24px;padding:14px;display:flex;flex-direction:column;gap:10px;border:.5px solid var(--sep)">
      {ring(pct, 54, 5, col, "var(--surface2)", icon(h["icon"], 22, col))}
      <div><div style="font-size:16px;font-weight:600">{esc(h["name"])}</div><div style="font-size:13px;color:var(--ink2);margin-top:1px">{ctx}</div></div></div>'''


def dusk_stage(height=250, text="A steady morning.", sub="2 of 5 done · within budget"):
    return f'''<div style="position:absolute;top:0;left:0;right:0;height:{height}px;background:radial-gradient(120% 90% at 50% 30%, var(--halo) 0%, transparent 62%);opacity:.9"></div>
      <div style="position:relative;display:flex;flex-direction:column;align-items:center;padding-top:6px">
        {companion(124, "calm", "var(--accent)", "var(--bg)", "rgba(164,174,255,.16)")}
        <div style="font-size:22px;font-weight:600;margin-top:12px">{text}</div>
        <div style="font-size:15px;color:var(--ink2);margin-top:3px">{sub}</div></div>'''


def dusk_today(theme="dusk-dark", markers=True):
    tiles = "".join(dusk_tile(h) for h in HABITS[:4])
    inner = f'''
    <div class="scroll">
      {dusk_stage()}
      <div style="display:flex;justify-content:space-between;align-items:center;margin:22px 4px 10px">
        <span style="font-size:22px;font-weight:700">Today</span><div class="glassbtn" style="width:36px;height:36px">{icon("plus", 18)}</div></div>
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:10px">{tiles}</div>
      <div class="future" style="margin-top:10px;background:var(--surface);border-radius:24px;padding:14px 16px;display:flex;align-items:center;gap:14px;border:.5px solid var(--sep)">
        {ring(60, 46, 5, "var(--accent)", "var(--surface2)", icon("hourglass", 18, "var(--accent)"))}
        <div style="flex:1"><div style="font-size:16px;font-weight:600">Social media</div><div style="font-size:13px;color:var(--ink2)">18 of 30 min</div></div></div>
    </div>{tabbar("Today")}'''
    m = [(4, 100), (4, 330), (4, 470)] if markers else []
    return phone(theme, inner, m)


def dusk_detail(theme="dusk-dark", markers=True):
    dots = ""
    for c in JOURNAL_14:
        st = {"d": "background:var(--mint);box-shadow:0 0 10px rgba(127,216,190,.55)", "m": "border:1.5px solid var(--ink3)",
              "s": "background:var(--surface2)", "t": "border:1.5px dashed var(--accent)"}[c]
        dots += f'<div style="width:30px;height:30px;border-radius:15px;{st}"></div>'
    inner = f'''
    <div class="scroll">
      <div style="display:flex;justify-content:space-between;padding-top:4px"><div class="glassbtn">{icon("chevron.left", 22)}</div><div class="glassbtn">{icon("ellipsis", 22)}</div></div>
      <div style="display:flex;flex-direction:column;align-items:center;margin-top:6px">
        {ring(83, 176, 12, "var(--mint)", "var(--surface2)", f'<div style="text-align:center"><div class="round tnum" style="font-size:44px;font-weight:700">83%</div><div style="font-size:13px;color:var(--ink2)">last 14 days</div></div>')}
        <div style="display:flex;align-items:center;gap:8px;margin-top:14px">{icon("pencil.line", 22, "var(--accent)")}<span style="font-size:26px;font-weight:700">Journal</span></div>
        <div style="margin-top:10px;padding:7px 12px;border-radius:16px;background:var(--amberSoft);color:var(--amber);font-size:14px;font-weight:600;display:flex;gap:6px;align-items:center">{icon("arrow.clockwise", 14, "var(--amber)")} Rebuilding · 2 of 3 good days</div></div>
      <div style="background:var(--surface);border-radius:24px;padding:16px;margin-top:18px;border:.5px solid var(--sep)">
        <div style="display:grid;grid-template-columns:repeat(7,30px);justify-content:space-between;row-gap:12px">{dots}</div></div>
      <div style="display:flex;gap:10px;margin-top:10px">
        {''.join(f'<div style="flex:1;background:var(--surface);border-radius:20px;padding:12px 14px;border:.5px solid var(--sep)"><div style="font-size:12.5px;color:var(--ink2)">{a}</div><div class="round tnum" style="font-size:24px;font-weight:700;margin-top:2px">{b}</div></div>' for a, b in [("Streak", "2 d"), ("Best", "12 d"), ("Skips", "1")])}</div>
      <div style="background:var(--surface);border-radius:22px;margin-top:10px;border:.5px solid var(--sep);display:flex;align-items:center;gap:12px;padding:14px 16px">{icon("calendar", 20, "var(--accent)")}<span style="flex:1;font-size:17px">View history</span>{icon("chevron.right", 15, "var(--ink3)")}</div>
    </div>'''
    m = [(4, 150), (4, 330), (4, 410), (4, 520)] if markers else []
    return phone(theme, inner, m)


def dusk_insights(theme="dusk-dark", markers=True):
    rings = "".join(
        f'<div style="display:flex;flex-direction:column;align-items:center;gap:6px;width:62px">{ring(p, 52, 5, "var(--mint)" if p == 100 else ("var(--amber)" if p < 60 else "var(--accent)"), "var(--surface2)", icon(ic, 18, "var(--ink2)"))}'
        f'<span class="round tnum" style="font-size:13px;font-weight:600">{p}%</span></div>' for _, ic, _, p in WEEK_RESULTS)
    inner = f'''
    <div class="scroll">
      <div style="display:flex;justify-content:space-between;align-items:center;padding-top:4px">
        <span style="font-size:28px;font-weight:700;margin-left:4px">This week</span>
        <div class="glasspill" style="padding:0 6px;gap:0">{icon("chevron.left", 20)}<span style="font-size:15px;padding:0 6px" class="tnum">Sep 21 – 27</span>{icon("chevron.right", 20, "var(--ink3)")}</div></div>
      <div style="display:flex;flex-direction:column;align-items:center;margin-top:18px">
        {ring(82, 190, 14, "var(--accent)", "var(--surface2)", f'<div style="text-align:center"><div class="round tnum" style="font-size:50px;font-weight:700">82%</div><div style="font-size:13px;color:var(--mint);font-weight:600">▲ 6 pts</div></div>')}</div>
      <div style="display:flex;justify-content:space-between;margin-top:22px;padding:14px 10px;background:var(--surface);border-radius:24px;border:.5px solid var(--sep)">{rings}</div>
      <div style="margin-top:10px;background:var(--surface);border-radius:24px;padding:16px;border:.5px solid var(--sep);display:flex;gap:12px;align-items:center">
        {companion(48, "focused", "var(--accent)", "var(--bg)", "rgba(164,174,255,.16)")}
        <div style="font-size:15px;line-height:1.38">Walk and Read were perfect. <span style="color:var(--amber)">No phone in bed</span> could use a gentler week.</div></div>
      <div class="future" style="margin-top:10px;background:var(--surface);border-radius:24px;padding:16px;border:.5px solid var(--sep);font-size:15px">Social media within budget · <b>5 of 7 days</b></div>
    </div>{tabbar("Insights")}'''
    m = [(4, 200), (4, 360), (4, 450)] if markers else []
    return phone(theme, inner, m)


# ===========================================================================
# Component / interaction states board (recommended direction)
# ===========================================================================

def states_board(theme="tide-light"):
    base = HABITS[0]
    def frame(title, content, w=361):
        return f'<div style="width:{w}px"><div style="font:600 12px -apple-system;color:#6a6a6a;margin-bottom:8px;text-transform:uppercase;letter-spacing:.04em">{title}</div>{content}</div>'
    def card(content):
        return f'<div class="t-{theme}" style="background:var(--bg);padding:12px;border-radius:26px"><div style="background:var(--surface);border-radius:22px;box-shadow:var(--shadow);color:var(--ink)">{content}</div></div>'
    pressed = tide_row(base).replace('border:2.5px solid var(--ink3);opacity:.75', 'border:2.5px solid var(--accent);background:var(--accentSoft);transform:scale(.92)')
    done = tide_row(dict(base, done=True, ctx="Every day · 5-day streak"))
    skip = tide_row(dict(base, name="Morning walk", icon="figure.walk", ctx="Skipped today · travel")).replace(
        '<div style="width:44px;height:44px;border-radius:22px;border:2.5px solid var(--ink3);opacity:.75;flex:none"></div>',
        f'<div style="width:44px;height:44px;border-radius:22px;background:var(--surface2);display:flex;align-items:center;justify-content:center">{icon("forward.end", 18, "var(--ink2)")}</div>')
    avoid = tide_row(dict(HABITS[4], done=False, ctx="Cut down · not yet confirmed for tonight"))
    toast = (f'<div class="t-{theme}" style="padding:12px;background:var(--bg);border-radius:26px"><div style="display:flex;align-items:center;gap:10px;padding:0 8px 0 18px;height:52px;'
             f'border-radius:26px;background:var(--ink);color:var(--bg)">{icon("checkmark", 18, "var(--accent)" if "dark" in theme else "var(--accentSoft)")}'
             f'<span style="flex:1;font-size:15px;font-weight:500">Drink water done</span><span style="padding:8px 14px;border-radius:18px;font-weight:600;font-size:15px;background:rgba(127,127,127,.25)">Undo</span></div></div>')
    menu = (f'<div class="t-{theme}" style="padding:12px;background:var(--bg);border-radius:26px"><div style="background:var(--surface);border-radius:22px;padding:6px 0;box-shadow:var(--shadow);color:var(--ink)">'
            + "".join(f'<div style="display:flex;align-items:center;gap:12px;padding:12px 16px;font-size:17px;{"border-bottom:.5px solid var(--sep);" if i < 2 else ""}">{icon(ic, 19, "var(--ink2)")}<span>{t}</span></div>'
                      for i, (t, ic) in enumerate([("Skip today…", "forward.end"), ("Open details", "list.bullet"), ("Edit habit", "square.and.pencil")])) + '</div></div>')
    bars = (f'<div class="t-{theme}" style="padding:16px;background:var(--bg);border-radius:26px;color:var(--ink);display:flex;flex-direction:column;gap:14px">'
            + "".join(f'<div><div style="display:flex;justify-content:space-between;font-size:14px"><span>{lab}</span><span class="round tnum" style="font-weight:600">{v}</span></div>'
                      f'<div style="height:6px;border-radius:3px;background:var(--surface2);margin-top:6px"><div style="width:{w}%;height:6px;border-radius:3px;background:var({c})"></div></div></div>'
                      for lab, v, w, c in [("Healthy · under 70%", "18 / 30 min", 60, "--accent"), ("Near limit · 70–99%", "25 / 30 min", 83, "--amber"), ("Over budget · 100%+", "36 / 30 min", 100, "--clay")]) + '</div>')
    comp = (f'<div class="t-{theme}" style="padding:16px;background:var(--bg);border-radius:26px;color:var(--ink);display:flex;gap:6px;justify-content:space-between">'
            + "".join(f'<div style="display:flex;flex-direction:column;align-items:center;gap:6px">{companion(44, st, "var(--accent)" if col is None else col, "var(--surface)", "var(--surface2)")}<span style="font-size:11.5px;color:var(--ink2)">{lab}</span></div>'
                      for lab, st, col in [("calm", "calm", None), ("focused", "focused", None), ("nearLimit", "focused", "var(--amber)"), ("overloaded", "calm", "var(--clay)"), ("recovering", "recovering", "var(--amber)"), ("celebrating", "calm", "var(--gold)")]) + '</div>')
    grid = f'''<div style="display:grid;grid-template-columns:repeat(3,385px);gap:28px 40px;margin-top:34px">
      {frame("1 · Row — default (44pt control)", card(tide_row(base)))}
      {frame("2 · Row — pressed (scale .92, haptic on commit)", card(pressed))}
      {frame("3 · Row — done (fill + symbol replace)", card(done))}
      {frame("4 · Undo toast (≈4 s, above tab bar)", toast)}
      {frame("5 · Row — skipped (excused, not a miss)", card(skip))}
      {frame("6 · Row — avoidance (“Cut down”) pending", card(avoid))}
      {frame("7 · Long-press / context menu", menu)}
      {frame("8 · Attention budget states (no red)", bars)}
      {frame("9 · Companion state palette (placeholder art)", comp)}
    </div>'''
    return grid


# ===========================================================================
# App icon concepts — original marks, no SF Symbols (see ICON_SYSTEM.md).
# ===========================================================================

def app_icon(kind, size=180):
    r = size * 0.2237
    if kind == "tide":
        art = ('<defs><linearGradient id="tg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#3E857B"/><stop offset="1" stop-color="#1F4F49"/></linearGradient></defs>'
               '<rect width="100" height="100" fill="url(#tg)"/><circle cx="50" cy="42" r="15" fill="#F5F3EE"/>'
               '<path d="M14 66q9-7 18 0t18 0 18 0 18 0" fill="none" stroke="#F5F3EE" stroke-width="5" stroke-linecap="round"/>'
               '<path d="M22 79q7-5 14 0t14 0 14 0 14 0" fill="none" stroke="#F5F3EE" stroke-width="4" stroke-linecap="round" opacity=".55"/>')
    elif kind == "almanac":
        art = ('<rect width="100" height="100" fill="#FAF7F0"/>'
               '<path d="M50 18c15 12 18 34 0 64-18-30-15-52 0-64z" fill="#4C6330"/><path d="M50 30v52" stroke="#FAF7F0" stroke-width="2.6" stroke-linecap="round"/>'
               '<path d="M50 48l9-7M50 60l-9-7" stroke="#FAF7F0" stroke-width="2.2" stroke-linecap="round"/>')
    elif kind == "dusk":
        art = ('<defs><radialGradient id="dg" cx=".5" cy=".38" r=".7"><stop offset="0" stop-color="#3B4590"/><stop offset="1" stop-color="#0C0E1C"/></radialGradient></defs>'
               '<rect width="100" height="100" fill="url(#dg)"/><path d="M30 46L32 24l14 13M70 46L68 24 54 37" fill="#A4AEFF" stroke="#A4AEFF" stroke-width="4" stroke-linejoin="round"/>'
               '<ellipse cx="50" cy="60" rx="25" ry="23" fill="#A4AEFF"/><path d="M38 56q4 3 8 0M54 56q4 3 8 0" fill="none" stroke="#0C0E1C" stroke-width="3.2" stroke-linecap="round"/>')
    elif kind == "tide-dark":
        art = ('<rect width="100" height="100" fill="#0F1312"/><circle cx="50" cy="42" r="15" fill="#6EBFB1"/>'
               '<path d="M14 66q9-7 18 0t18 0 18 0 18 0" fill="none" stroke="#6EBFB1" stroke-width="5" stroke-linecap="round"/>'
               '<path d="M22 79q7-5 14 0t14 0 14 0 14 0" fill="none" stroke="#6EBFB1" stroke-width="4" stroke-linecap="round" opacity=".55"/>')
    elif kind == "tide-tinted":
        art = ('<rect width="100" height="100" fill="#1A1A1A"/><circle cx="50" cy="42" r="15" fill="#E6E6E6"/>'
               '<path d="M14 66q9-7 18 0t18 0 18 0 18 0" fill="none" stroke="#E6E6E6" stroke-width="5" stroke-linecap="round"/>'
               '<path d="M22 79q7-5 14 0t14 0 14 0 14 0" fill="none" stroke="#E6E6E6" stroke-width="4" stroke-linecap="round" opacity=".55"/>')
    return (f'<svg width="{size}" height="{size}" viewBox="0 0 100 100" style="border-radius:{r}px;box-shadow:0 10px 30px rgba(0,0,0,.18);display:block">'
            f'<clipPath id="c{kind}"><rect width="100" height="100" rx="22.37"/></clipPath><g clip-path="url(#c{kind})">{art}</g></svg>')


# ===========================================================================
# Page assembly
# ===========================================================================

def fix_fonts(markup):
    return re.sub(r"(font:[^;\"]*?)-apple-system", r"\1system-ui", markup)


def page(title, body, width, dark=False):
    return fix_fonts(f'''<!doctype html><html><head><meta charset="utf-8"><title>{esc(title)}</title>
<style>{BASE_CSS}{theme_css()}</style></head><body style="width:{width}px">
<div class="board{' darkboard' if dark else ''}">{body}</div></body></html>''')


def col(title, ph, notes):
    lis = "".join(f'<li class="plain">{n[1:]}</li>' if n.startswith("!") else f"<li>{n}</li>" for n in notes)
    return f'<div class="col"><h2>{title}</h2>{ph}<ol class="notes">{lis}</ol></div>'


FUTURE_NOTE = "Dashed purple outline = future surface (attention engine / weekday patterns are not built yet; shown so layout reserves room for them)."

BOARDS = {}

BOARDS["A-tidewater-light"] = ("Direction A — Tidewater (recommended) · light", f'''
<h1>Direction A — Tidewater <span style="color:#2C6B63">· recommended</span></h1>
<div class="sub">Native grouped-card layout, warm paper neutrals, one deep tide-teal accent. SF Pro for UI, SF Pro Rounded only for numerals. Amber for recovery and near-limit states, never red. The companion lives in a compact status card, not a stage.</div>
<div class="row">
{col("Today — populated", tide_today(), [
  "Date eyebrow plus large title; the only toolbar action is Add (glass button, system navigation layer).",
  "Companion status card: one sentence of state plus one supporting metric. Copy is derived from data, never decorative.",
  "“To do” comes first, so the next action is always the top row. Weekly habits show capsule pips (2 of 3) instead of a streak.",
  "A recovering habit gets amber context text and a recovery glyph, never a broken-streak signal.",
  "Done rows keep the full name, dim to secondary ink, and keep their filled control so they can be undone in place.",
  "!Attention card reserves Phase 2 space: one bar, value with unit, no dial."])}
{col("Habit detail — Journal", tide_detail(), [
  "Recovery card leads, because it is the most actionable fact: “2 good days since your miss”, plus 3 pips toward the documented 3-success threshold.",
  "Two stat tiles only. Best streak is a footnote, not a competing hero number.",
  "14-day ledger: missed = hollow ring, skipped = tinted with skip glyph, today = dashed (open, not a miss). Never red.",
  "Archive sits after navigation and is phrased as reversible; its confirmation must show Cancel (UX_AUDIT F9)."])}
{col("Weekly Insights — Sep 21–27", tide_insights(), [
  "One hero number. The trend chip says points, not percent, and names the comparable cohort (UX_AUDIT Part 0, Rule 1).",
  "“Went well” lists every tied habit by name (documented tie rule).",
  "“Needs recovery” replaces “weakest”, and uses avoidance-polarity copy (“Avoided 3 of 7 nights”).",
  "!Most-complete-day chart appears only once enough data exists (MVP §7); full-day bars are accent, partial days are tint.",
  "!Attention budget result is one sentence, not a chart."])}
</div><div class="legend">{FUTURE_NOTE} Icons are SVG approximations of the SF Symbols named in ICON_SYSTEM.md. The companion is placeholder geometry, not final art.</div>''', 1500, False)

BOARDS["A-tidewater-dark"] = ("Direction A — Tidewater · dark", f'''
<h1>Direction A — Tidewater · dark appearance</h1>
<div class="sub">The same layout with dark tokens. Surfaces step up in lightness instead of using shadows, the accent lightens to #6EBFB1 to hold contrast, and amber and clay are warmed so they don’t glow.</div>
<div class="row">
{col("Today", tide_today("tide-dark", False), ["Card elevation comes from surface lightness (#191F1D on #0F1312), not shadow.", "Checkmark ink on the accent fill is dark (#0B1F1C), which keeps contrast above 7:1 on the filled control."])}
{col("Habit detail", tide_detail("tide-dark", False), ["Amber recovery text is #E2A955 on #191F1D (≈8:1).", "Hollow “missed” rings use ink3 at reduced opacity: visible, but never alarming."])}
{col("Weekly Insights", tide_insights("tide-dark", False), ["The hero numeral uses SF Pro Rounded Bold at full ink; supporting text uses ink2.", "The chart pairs accent with accentSoft, so full versus partial days don’t rely on hue alone (also differ in height)."])}
</div><div class="legend">{FUTURE_NOTE}</div>''', 1500, True)

BOARDS["A-tidewater-accessibility"] = ("Direction A — Tidewater · accessibility sizes", f'''
<h1>Direction A — Tidewater · large Dynamic Type</h1>
<div class="sub">Today at accessibility size AX3, where the HIG body style is about 40pt (the type values in this mockup approximate that size). At AX sizes, horizontal rows reflow vertically: icon, then name, then context, then a full-width labeled control. Light shown left, dark right.</div>
<div class="row">
{col("Today · AX3 · light", tide_today_ax("tide-light"), [
  "The companion card keeps its sentence and drops the secondary clause first. Text is never truncated; it wraps.",
  "Rows stack vertically. The habit name is never shortened, and context wraps to as many lines as it needs.",
  "The completion control becomes a 64pt-tall labeled button (“Mark done” / “Done”). No meaning is carried by an icon alone."])}
{col("Today · AX3 · dark", tide_today_ax("tide-dark", False), [
  "Same structure in dark tokens.",
  "Implementation: switch layouts on dynamicTypeSize.isAccessibilitySize (ViewThatFits as a fallback). Scale fixed dimensions with @ScaledMetric.",
  "The tab bar keeps system behavior; labels follow the system’s own large-content viewer."])}
<div class="col" style="width:420px"><h2>Rules at accessibility sizes</h2>
<ol class="notes" style="margin-top:0">
<li>Never truncate a habit name. Wrap it, and let the row grow.</li>
<li>Hide decorative chrome first (pip bars become text like “2 of 3 this week”), then secondary clauses. Primary state is never hidden.</li>
<li>Tap targets stay at least 44×44pt at every size. The AX control is full-width.</li>
<li>Numerals keep SF Pro Rounded, but hero numbers cap their growth so they don’t push content off-screen. Use text styles with relativeTo:, not fixed sizes.</li>
<li>VoiceOver: each row is one element. Label “Journal, rebuilding, 2 of 3 good days”, value “not done”, action “Mark done”. Plus custom actions for Skip and Open details.</li>
<li>To verify on device: AX5, Bold Text, Increase Contrast, Reduce Transparency (glass falls back to opaque), Reduce Motion.</li>
</ol></div>
</div>''', 1500, False)

BOARDS["B-almanac"] = ("Direction B — Almanac", f'''
<h1>Direction B — Almanac</h1>
<div class="sub">Editorial and text-forward. New York serif for titles and companion and insight sentences; SF Pro for controls. Hairline lists instead of cards, with Things-style leading checkboxes. Moss accent on cream paper. Insights read like a short written note.</div>
<div class="row">
{col("Today — populated", alm_today(), [
  "The weekday is a serif headline, so the screen reads like a dated page in a journal.",
  "Companion line drawing in the margin, with a quoted serif sentence. The most literary companion of the three directions.",
  "Leading rounded-square checkbox (28pt glyph in a 44pt hit area), on the side where the thumb starts.",
  "Weekly progress as dot tallies (●●○). Recovery stays amber text.",
  "!Attention as one hairline meter."])}
{col("Habit detail — Journal", alm_detail(), [
  "Recovery stated as a pull-quote sentence with an amber rule. Warm, but the heaviest reading load of the three directions.",
  "14-day ledger as rounded squares, with the legend written inline.",
  "Numbers set as a typeset table, which aligns well at large Dynamic Type sizes."])}
{col("Weekly Insights", alm_insights(), [
  "Headline week title, with the hero number as a serif figure.",
  "Each section is one or two plain-language sentences, which fits UX.md’s “not a spreadsheet” rule.",
  "!Suggestions (“a gentler target?”) need care: suggest, never prescribe, and stay away from medical tone.",
  "The observation is limited to factual patterns, with no causal claims."])}
</div>
<div class="row" style="margin-top:50px">{col("Today — dark", alm_today("almanac-dark", False), ["Parchment ink on deep umber. Serif text holds up well in dark mode, though weights below Regular should be avoided."])}
<div class="col" style="width:880px"><h2>Assessment</h2><ol class="notes" style="margin-top:0">
<li>Strongest brand distinctiveness for the writing voice, and the most calm-by-default direction.</li>
<li>Risk: serif headlines combined with Liquid Glass system chrome can feel like two design languages; it needs careful pairing.</li>
<li>Risk: long serif sentences at AX5 get very tall. Insights would need a summary-first collapse.</li>
<li>Risk: text-first Today is slower to scan than icon tiles once there are more than about 8 habits.</li>
<li>Recommended to adopt: the written Insights voice and the dot tallies. Not recommended: making serif the primary UI type.</li></ol></div></div>
<div class="legend">{FUTURE_NOTE}</div>''', 1500, False)

BOARDS["C-dusk"] = ("Direction C — Dusk", f'''
<h1>Direction C — Dusk</h1>
<div class="sub">Immersive and dark-first. The companion sits on a lit stage taking about a quarter of Today; habits are two-column ring tiles. Periwinkle accent, mint for done, amber for recovery. The most emotionally engaging direction, and the most likely to slip into “virtual pet” territory.</div>
<div class="row">
{col("Today — populated", dusk_today(), [
  "Companion stage (124pt) with halo color driven by state. Highest presence, so it must stay stateful, never decorative (APPLE_COMPLIANCE: not a pet with thin utility).",
  "Ring tiles: tap to complete, ring fills. Fast for up to 6 habits; a grid scales poorly beyond that and at AX sizes (falls back to a list).",
  "Recovery shown as an amber partial ring. Rings can look like “incomplete = failing”, so the copy has to carry the calm.",
  "!Attention as a ring, matching the other tiles."])}
{col("Habit detail — Journal", dusk_detail(), [
  "Hero consistency ring (83%). Visually satisfying, but it promotes a metric above recovery, the opposite of A’s ordering.",
  "Amber recovery chip under the title.",
  "Glowing dots for done days. The glow must be disabled under Reduce Transparency and Increase Contrast.",
  "Compact stat strip."])}
{col("Weekly Insights", dusk_insights(), [
  "Large ring hero with a trend delta.",
  "Per-habit mini rings. Dense, and the most chart-like; closest to an analytics dashboard, which UX.md warns against.",
  "The companion delivers the written summary, a good pattern that can be reused in A.",
  "!Attention line."])}
</div>
<div class="row" style="margin-top:50px">{col("Today — light", dusk_today("dusk-light", False), ["The light variant loses most of the stage’s atmosphere. This direction depends on dark mode."])}
<div class="col" style="width:880px"><h2>Assessment</h2><ol class="notes" style="margin-top:0">
<li>The best-suited direction for the future companion, widgets and Live Activity glance (a lit creature reads well on the Lock Screen).</li>
<li>Risk: rings and gems push toward the visual language of Finch and fitness rings; it is less differentiated from Streaks’ grid of circles.</li>
<li>Risk: the light mode is weak, and the stage costs about 250pt of the first screen, pushing the next action below the fold with 6+ habits.</li>
<li>Risk: highest motion and transparency budget, so the most Reduce Motion and Reduce Transparency work.</li>
<li>Recommended to adopt later: the stage pattern for the companion detail sheet, and the halo-as-state idea for widgets.</li></ol></div></div>
<div class="legend">{FUTURE_NOTE}</div>''', 1500, True)

BOARDS["A-components"] = ("Direction A — component & interaction states", f'''
<h1>Tidewater — component and interaction states</h1>
<div class="sub">The states engineering needs for the core loop, rendered with Direction A light tokens. Timing, haptics and accessibility behavior are specified in COMPONENT_SPEC.md.</div>
{states_board("tide-light")}
<div class="legend" style="margin-top:28px">Companion poses are placeholder geometry that only varies the eyes and color. Final pose and expression art is a brand-art deliverable (ICON_SYSTEM.md, section 4).</div>''', 1340, False)

BOARDS["app-icons"] = ("App icon concepts", f'''
<h1>App icon concepts (original marks)</h1>
<div class="sub">Concept sketches only, one per direction. These are not final art and contain no SF Symbols (Apple’s SF Symbols terms prohibit using symbols in app icons). The final icon is built as layered artwork in Icon Composer, with Default, Dark, Clear and Tinted appearances.</div>
<div style="display:flex;gap:70px;margin-top:44px;align-items:flex-end">
  <div style="text-align:center">{app_icon("tide")}<div style="font:600 14px -apple-system;margin-top:14px">A · Tidewater — “still water”</div><div style="font:13px/1.4 -apple-system;color:#666;margin-top:4px;width:200px">Rising sun or companion eye over two calm ripples. Reads at 29pt.</div></div>
  <div style="text-align:center">{app_icon("almanac")}<div style="font:600 14px -apple-system;margin-top:14px">B · Almanac — “leaf / quill”</div><div style="font:13px/1.4 -apple-system;color:#666;margin-top:4px;width:200px">Leaf that doubles as a quill. Editorial, but generic in the wellness category.</div></div>
  <div style="text-align:center">{app_icon("dusk")}<div style="font:600 14px -apple-system;margin-top:14px">C · Dusk — “the companion”</div><div style="font:13px/1.4 -apple-system;color:#666;margin-top:4px;width:200px">The companion itself. Strong character, but ties the brand to one species.</div></div>
</div>
<h1 style="font-size:20px;margin-top:60px">Tidewater appearance variants (concept)</h1>
<div style="display:flex;gap:40px;margin-top:22px;align-items:flex-end">
  {''.join(f'<div style="text-align:center">{app_icon(k, s)}<div style="font:13px -apple-system;color:#666;margin-top:10px">{lab}</div></div>' for k, s, lab in [("tide", 120, "Default"), ("tide-dark", 120, "Dark"), ("tide-tinted", 120, "Tinted (mono source)"), ("tide", 60, "60pt"), ("tide", 40, "40pt"), ("tide", 29, "29pt")])}
</div>''', 1340, False)


def single_screens():
    """Individual phone PNGs for quick review in the PR / docs."""
    return {
        "A-today-light": tide_today("tide-light", False), "A-detail-light": tide_detail("tide-light", False),
        "A-insights-light": tide_insights("tide-light", False), "A-today-dark": tide_today("tide-dark", False),
        "A-detail-dark": tide_detail("tide-dark", False), "A-insights-dark": tide_insights("tide-dark", False),
        "A-today-ax3-light": tide_today_ax("tide-light", False), "A-today-ax3-dark": tide_today_ax("tide-dark", False),
        "B-today-light": alm_today("almanac-light", False), "B-detail-light": alm_detail("almanac-light", False),
        "B-insights-light": alm_insights("almanac-light", False), "B-today-dark": alm_today("almanac-dark", False),
        "C-today-dark": dusk_today("dusk-dark", False), "C-detail-dark": dusk_detail("dusk-dark", False),
        "C-insights-dark": dusk_insights("dusk-dark", False), "C-today-light": dusk_today("dusk-light", False),
    }


def screen_page(ph):
    return fix_fonts(f'''<!doctype html><html><head><meta charset="utf-8"><style>{BASE_CSS}{theme_css()}
body{{background:transparent;width:433px;height:892px;padding:20px}}</style></head><body>{ph}</body></html>''')


def render(html_path, png_path, w, h):
    subprocess.run([CHROME, "--headless=new", "--disable-gpu", "--hide-scrollbars", "--allow-file-access-from-files",
                    "--force-device-scale-factor=2", "--default-background-color=00000000", f"--window-size={w},{h}",
                    f"--screenshot={png_path}", "file://" + html_path], check=True, capture_output=True)


def main():
    os.makedirs(HTML_DIR, exist_ok=True)
    os.makedirs(PNG_DIR, exist_ok=True)
    jobs = []
    heights = {"A-tidewater-light": 1500, "A-tidewater-dark": 1360, "A-tidewater-accessibility": 1300, "B-almanac": 2440,
               "C-dusk": 2420, "A-components": 760, "app-icons": 900}
    for key, (title, body, width, dark) in BOARDS.items():
        p = os.path.join(HTML_DIR, key + ".html")
        with open(p, "w") as f:
            f.write(page(title, body, width, dark))
        jobs.append((p, os.path.join(PNG_DIR, "board-" + key + ".png"), width, heights[key]))
    for key, ph in single_screens().items():
        p = os.path.join(HTML_DIR, "screen-" + key + ".html")
        with open(p, "w") as f:
            f.write(screen_page(ph))
        jobs.append((p, os.path.join(PNG_DIR, "screen-" + key + ".png"), 433, 892))
    if "--html" in sys.argv:
        return
    for job in jobs:
        render(*job)
        print("rendered", os.path.relpath(job[1], HERE))


if __name__ == "__main__":
    main()
