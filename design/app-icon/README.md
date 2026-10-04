# Beta app icon

The bundled icon is an original geometric A with a tide-shaped crossbar and
small amber point, drawn on the Vivid Tidewater teal gradient. It uses no font
glyph, SF Symbol, stock illustration or third-party asset. This is a usable
beta identity for review, not a claim that final brand exploration is finished.

Regenerate with native macOS frameworks:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  swift design/app-icon/render.swift \
  Avela/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png
```

Output: 1024px square RGB PNG, no alpha. Apple applies the icon mask. Review it
at Home Screen and App Store sizes before distribution. Companion artwork is
reviewed separately; this monogram does not select an animal.
