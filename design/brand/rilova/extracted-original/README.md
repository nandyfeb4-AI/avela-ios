# Original-board icon extraction

The owner selected the original Rilova App Branding Board. These assets extract its actual R artwork rather than generating a new symbol. The gradient icon is the primary iPhone/Watch icon; the dark version is bundled for iOS dark icon appearance and in-app BrandIcon dark appearance. The older hand-built flowing-R and imagegen variants remain explorations and are not applied.

## Provenance and reproduction

Run `swift extract.swift "/path/to/Rilova App Branding Board.png"` on macOS. Source board is 1254 × 1254px. Each icon crop is 388 × 388px: gradient origin (688,439), dark origin (178,439). The native square assets retain 136,996 original interior pixels each. Assertions verify every RGB pixel in the R's bounding rectangle is identical to the source before scaling. A third-degree background surface, fitted outside the symbol rectangle, extends only corners and the outer margin to remove the board's mask/shadow. No generative edit, redraw or vector claim is made.

`rilova-*-native.png` are source-scale square exports. `rilova-*-1024.png` are opaque sRGB interpolated exports for asset catalogs. Upscaling does not recover missing detail. `extracted-preview.png` displays both masked icons and 120/60/40/29px checks. iOS applies its own mask; production PNGs are square, opaque and have no outside shadow.

App icons are decorative identifiers rather than reading/status controls. The slim source upright is retained intentionally to honor the approved design; final physical-device/tinted appearance review remains open. Tagline and tracking themes remain unchanged.
