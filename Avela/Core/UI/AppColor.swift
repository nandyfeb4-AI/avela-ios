import SwiftUI

/// Vivid Tidewater's semantic colour tokens, backed by named colour assets in
/// `Resources/Assets.xcassets` with light/dark appearances — see
/// `docs/DATA_MODEL.md`'s "Vivid Tidewater UX pass" section for the exact
/// values and their source (`design/exploration/prototype-vivid/vivid.css`).
///
/// These assets remain the default palette and stable semantic states.
/// Theme-aware accent surfaces resolve through the value-based `AppPalette`
/// environment; the composition root supplies the same accent to native tint.
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

/// Consistent icon treatment for informational app rows. The containing
/// control keeps its own 44-point bounds and spoken label.
struct AppIconBadge: View {
    @Environment(\.appPalette) private var palette
    @ScaledMetric(relativeTo: .body) private var symbolSize = 20.0
    let symbol: String
    var ink: Color? = nil
    var fill: Color? = nil

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: min(symbolSize, 28), weight: .medium))
            .foregroundStyle(ink ?? palette.accent)
            .frame(width: 44, height: 44)
            .background(fill ?? palette.accentSoft, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

/// Stable visual identity selected from the symbol, never private habit text.
/// Status and completion still use the selected app theme, independently.
struct HabitIconBadge: View {
    let symbol: String
    var isArchived = false

    static func identityTheme(for symbol: String) -> AppTheme {
        if ["book", "pencil", "graduation", "brain", "paint", "music"].contains(where: symbol.hasPrefix) { return .plum }
        if ["figure", "dumbbell", "bicycle", "shoe", "flame"].contains(where: symbol.hasPrefix) { return .ember }
        if ["leaf", "tree", "sun", "moon", "sparkles"].contains(where: symbol.hasPrefix) { return .forest }
        if ["heart", "person", "hands"].contains(where: symbol.hasPrefix) { return .rose }
        return .sapphire
    }

    var body: some View {
        let identity = AppPalette(theme: Self.identityTheme(for: symbol))
        let ink = isArchived ? Color.appInkSecondary : identity.accent
        AppIconBadge(symbol: symbol, ink: ink, fill: ink.opacity(0.10))
    }
}
