import SwiftUI

/// Vivid Tidewater's semantic colour tokens, backed by named colour assets in
/// `Resources/Assets.xcassets` with light/dark appearances — see
/// `docs/DATA_MODEL.md`'s "Vivid Tidewater UX pass" section for the exact
/// values and their source (`design/exploration/prototype-vivid/vivid.css`).
///
/// `AccentColor` itself is not wrapped here: it is the one colour-asset name
/// SwiftUI resolves automatically for `.tint`/`Color.accentColor` and the
/// system's own accent-aware controls, so giving it a second name here would
/// only invite the two to drift apart.
extension Color {
    static let appBackground = Color("Background")
    static let appSurface = Color("Surface")
    static let appSurfaceSecondary = Color("SurfaceSecondary")
    static let appInk = Color("Ink")
    static let appInkSecondary = Color("InkSecondary")
    static let appInkTertiary = Color("InkTertiary")
    static let appOnAccent = Color("OnAccent")
    static let appAccentSoft = Color("AccentSoft")
    static let appRecovery = Color("Recovery")
    static let appRecoverySoft = Color("RecoverySoft")
    static let appOverBudget = Color("OverBudget")
    static let appDoneWash = Color("DoneWash")
    static let appToastBackground = Color("ToastBackground")
    static let appToastInk = Color("ToastInk")
    static let appToastIcon = Color("ToastIcon")
}

/// Shared layout constants from `design/exploration/COMPONENT_SPEC.md` §1,
/// kept in one place so every retinted screen agrees on them.
enum AppMetrics {
    static let cardCornerRadius: CGFloat = 22
    static let tileCornerRadius: CGFloat = 12
}
