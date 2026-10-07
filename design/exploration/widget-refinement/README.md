# Widget design refinement — October 7, 2026

Owner requested a design review before applying the white-card implementation. The owner approved **B · Rich Tide**. It is now implemented natively in Quick Log and Routine; see [native screenshots and verification](../../../docs/verification/two-widgets/README.md). This board remains a standalone browser proposal with sample data.

Open [index.html](index.html). Compare light/dark and Tidewater/Plum/Coral with the controls. Demo Log updates the sample state across variants; Routine advances to its next sample step. + only explains the in-app amount destination. There is no connection to tracking data.

- **A · Soft tint:** tinted theme surfaces and dark actions.
- **B · Rich Tide (recommended):** deep theme gradient, solid light logging actions, strong contrast and restrained tonal depth.
- **C · Open sky:** subdued original sky/coast decoration with solid actions; decoration is outside reading text.

[Light comparison](comparison-light.png) · [Dark comparison](comparison-dark.png)

All use the same two widgets, data and actions. These are original CSS sketches using system fonts, not competitor assets or screenshots of native widgets. Names/details are explanatory in this board, not functioning app deep links. Sizes are approximate; native dark/large-text, theme contrast, Reduce Transparency, Increase Contrast and WidgetKit accented rendering must be validated after selecting a direction. No claim of user-tested preference, adherence improvement or award readiness.

The two-widget functionality is implemented in the workspace and was checked on an isolated simulator (background check-ins, routine selection and logging). Approved Rich Tide styling has been installed on the owner simulator in place, without resetting data. Temporary SpringBoard drivers have been removed; no commit or push.
