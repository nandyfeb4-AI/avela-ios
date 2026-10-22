# Rilova brand kit

**Rilova — Habits that fit real life.**

Suggested store title: **Rilova: Habits & Focus**. This kit is a visual identity, not a trademark-availability determination.

The original lowercase-r mark has a soft upright and an upward shoulder: a quiet suggestion of rhythm and continued progress. It stands independently of the animal companions.

## Files

- `rilova-app-icon.png`: opaque, square 1024px app icon; let iOS apply its mask.
- `rilova-app-icon.svg`: scalable icon source.
- `rilova-mark-teal.svg` / `rilova-mark-ivory.svg`: scalable transparent standalone marks.
- `rilova-mark-*.png`: transparent raster marks, 1200 × 1300px.
- `rilova-logo-teal.png` / `rilova-logo-ivory.png`: transparent name/tagline lockups, 1800 × 500px.
- `brand-board.png`: overview, palette and small-size examples.
- `icon-original.png`: initial generated exploration; the vector-derived exports are the final assets.

Use teal on light backgrounds and ivory on dark backgrounds. Keep clear space around the mark of at least a quarter of its width. Use the symbol alone at small sizes; do not squeeze the tagline into an app icon or widget.

## Palette and typography

Deep Tide `#072E32`, gradient highlight `#0C5257`, action teal `#0E7468`, warm ivory `#F6F3EB`. The wordmark export uses macOS Helvetica Neue Medium, while native app text continues using the system font. No font files are redistributed.

## Regeneration and provenance

Run `swift render.swift` from this folder on macOS. It renders the original Bezier master through Core Graphics, produces clean transparent PNGs and SVG marks, and regenerates the board. No runtime dependencies are added.

Initial direction was explored with the built-in imagegen tool: a premium Rilova icon, original flowing lowercase r, deep teal gradient, warm ivory, a subtle upward rhythm, clear at small sizes, with no flame, checkmark, infinity symbol, SF Symbol, wordmark or pre-applied mask. The final mark was reconstructed as a native vector for crisp scaling and clean transparency. The rough imagegen transparency experiment is not shipped.

## Original artwork refinement

The active app artwork now comes from `extracted-original/`: faithful extraction of the owner-approved gradient/dark board icons. Earlier vector exports here and `flowing-r/` are superseded explorations. See the extraction README for source-resolution limits and Desktop Original Artwork assets.
