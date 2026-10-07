import SwiftUI
import UIKit

/// Value-based, environment-injected app palette; no global mutable selection.
/// UIKit's dynamic colors follow system appearance, including presented sheets.
struct AppPalette {
    let theme: AppTheme

    var accent: Color { dynamic(light: theme.lightAccent, dark: theme.darkAccent) }
    var onAccent: Color { .appOnAccent }
    // Opaque themed reading surfaces. The canvas carries colour; text stays
    // on contrast-tested surfaces rather than transparent glass layers.
    var pageTop: Color { dynamic(light: 0xF1F3F5, dark: 0x131720) }
    var pageBottom: Color { dynamic(light: 0xF7F5F0, dark: 0x101216) }
    var surface: Color { dynamic(light: 0xFFFFFF, dark: 0x202329) }
    var surfaceSecondary: Color { dynamic(light: 0xF0EFEC, dark: 0x2A2D34) }
    var pageGradient: LinearGradient {
        LinearGradient(colors: [pageTop, atmosphere, pageBottom], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
    var heroEnd: Color {
        let hex = theme.lightAccent
        return Color(uiColor: UIColor(red: CGFloat((hex >> 16) & 255) / 255 * 0.72,
            green: CGFloat((hex >> 8) & 255) / 255 * 0.72,
            blue: CGFloat(hex & 255) / 255 * 0.72, alpha: 1))
    }
    var heroGradient: LinearGradient {
        LinearGradient(colors: [prominentFill, heroEnd], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// A complementary sky wash, distinct from accent-colored actions.
    var atmosphere: Color {
        switch theme {
        case .tidewater: dynamic(light: 0xE8EFF2, dark: 0x152029)
        case .sapphire: dynamic(light: 0xE7EDF8, dark: 0x171F30)
        case .plum: dynamic(light: 0xF0EAF4, dark: 0x231D2D)
        case .ember: dynamic(light: 0xF4EBDF, dark: 0x29201B)
        case .rose: dynamic(light: 0xF6E9EF, dark: 0x2B1E28)
        case .indigo: dynamic(light: 0xEAEAF8, dark: 0x1E1E32)
        case .forest: dynamic(light: 0xEAF0E5, dark: 0x1B241E)
        case .coral: dynamic(light: 0xF7EBE5, dark: 0x2C201F)
        case .gold: dynamic(light: 0xF4EDDB, dark: 0x28231A)
        }
    }

    /// Native prominent/glass toolbar controls enforce white template icons.
    /// Use a deep fill in both appearances instead of a pale dark-mode accent.
    var prominentFill: Color { Color(uiColor: Self.uiColor(theme.lightAccent)) }
    var prominentInk: Color { .white }
    var accentSoft: Color {
        if theme == .tidewater { return .appAccentSoft }
        return dynamic(light: theme.lightAccent, dark: theme.darkAccent, opacity: 0.12)
    }
    var toastBackground: Color {
        if theme == .tidewater { return .appToastBackground }
        return Color(uiColor: UIColor { traits in
            let dark = traits.userInterfaceStyle == .dark
            let color = Self.uiColor(dark ? theme.darkAccent : theme.lightAccent)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            // Dark toast is a light accent wash; light toast is a deep accent.
            return dark
                ? UIColor(red: r * 0.85 + 0.15, green: g * 0.85 + 0.15, blue: b * 0.85 + 0.15, alpha: 1)
                : UIColor(red: r * 0.48, green: g * 0.48, blue: b * 0.48, alpha: 1)
        })
    }
    var toastInk: Color {
        theme == .tidewater ? .appToastInk : dynamic(light: 0xFFFFFF, dark: 0x03231F)
    }
    var toastIcon: Color {
        theme == .tidewater ? .appToastIcon : toastInk
    }

    private func dynamic(light: UInt32, dark: UInt32, opacity: CGFloat = 1) -> Color {
        Color(uiColor: UIColor { traits in
            Self.uiColor(traits.userInterfaceStyle == .dark ? dark : light).withAlphaComponent(opacity)
        })
    }

    private static func uiColor(_ hex: UInt32) -> UIColor {
        UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

private struct AppPaletteKey: EnvironmentKey {
    static let defaultValue = AppPalette(theme: .tidewater)
}

extension EnvironmentValues {
    var appPalette: AppPalette {
        get { self[AppPaletteKey.self] }
        set { self[AppPaletteKey.self] = newValue }
    }
}

/// Shared native screen treatment; stronger contrast uses a simpler solid canvas.
private struct AppThemeCanvasModifier: ViewModifier {
    @Environment(\.appPalette) private var palette
    @Environment(\.colorSchemeContrast) private var contrast
    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 52)
            .listSectionSpacing(20)
            .background {
                if contrast == .increased { palette.pageBottom.ignoresSafeArea() }
                else { palette.pageGradient.ignoresSafeArea() }
            }
    }
}

extension View {
    func appThemeCanvas() -> some View { modifier(AppThemeCanvasModifier()) }
}

/// Original, resolution-independent scenery. Decorative, static and independent
/// of logged progress: a landscape must never imply a tracking outcome.
struct ThemeLandscape: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    let theme: AppTheme

    var body: some View {
        Canvas { context, size in
            let width = size.width, height = size.height
            let palette = AppPalette(theme: theme)
            let dark = colorScheme == .dark
            let sky = dark ? Color(red: 0.09, green: 0.13, blue: 0.22) : Color(red: 0.76, green: 0.87, blue: 0.94)
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
                Gradient(colors: [sky, palette.accent.opacity(dark ? 0.35 : 0.22)]),
                startPoint: .zero, endPoint: CGPoint(x: width, y: height)))
            let orbSize = min(width * 0.12, height * 0.40)
            context.fill(Path(ellipseIn: CGRect(x: width * 0.75, y: height * 0.12, width: orbSize, height: orbSize)),
                         with: .color(dark ? .white.opacity(0.75) : Color(red: 1, green: 0.88, blue: 0.62)))
            if dark {
                for point in [CGPoint(x: 0.12, y: 0.22), CGPoint(x: 0.28, y: 0.13), CGPoint(x: 0.54, y: 0.26)] {
                    context.fill(Path(ellipseIn: CGRect(x: width * point.x, y: height * point.y, width: 2, height: 2)), with: .color(.white.opacity(0.6)))
                }
            }
            for (x, y, scale) in [(0.10, 0.18, 0.20), (0.46, 0.33, 0.16)] {
                let w = width * scale, h = height * 0.12
                var cloud = Path(roundedRect: CGRect(x: width * x, y: height * y + h * 0.5, width: w, height: h), cornerRadius: h / 2)
                cloud.addEllipse(in: CGRect(x: width * x + w * 0.22, y: height * y, width: w * 0.35, height: h * 1.4))
                cloud.addEllipse(in: CGRect(x: width * x + w * 0.48, y: height * y + h * 0.2, width: w * 0.30, height: h))
                context.fill(cloud, with: .color(.white.opacity(dark ? 0.12 : 0.64)))
            }
            // Each palette has its own horizon family, not a recolored card.
            let mountains = theme == .sapphire || theme == .indigo || theme == .plum
            for layer in 0..<3 {
                let y = height * (0.53 + Double(layer) * 0.13)
                var horizon = Path()
                horizon.move(to: CGPoint(x: 0, y: y))
                if mountains {
                    horizon.addLines([CGPoint(x: width * 0.20, y: y - height * 0.23),
                                      CGPoint(x: width * 0.42, y: y + height * 0.08),
                                      CGPoint(x: width * 0.68, y: y - height * 0.17), CGPoint(x: width, y: y)])
                } else {
                    horizon.addCurve(to: CGPoint(x: width, y: y + height * 0.06),
                        control1: CGPoint(x: width * 0.28, y: y - height * 0.28),
                        control2: CGPoint(x: width * 0.65, y: y + height * 0.28))
                }
                horizon.addLine(to: CGPoint(x: width, y: height))
                horizon.addLine(to: CGPoint(x: 0, y: height)); horizon.closeSubpath()
                let colors = [palette.accent.opacity(dark ? 0.22 : 0.28), palette.prominentFill.opacity(0.65), palette.heroEnd]
                context.fill(horizon, with: .color(colors[layer]))
            }
            if theme == .forest {
                for (x, scale) in [(0.12, 0.9), (0.23, 1.2), (0.87, 1.0)] {
                    let base = height * 0.83, treeHeight = height * 0.39 * scale
                    var tree = Path()
                    tree.move(to: CGPoint(x: width * x, y: base - treeHeight))
                    tree.addLine(to: CGPoint(x: width * x - treeHeight * 0.28, y: base))
                    tree.addLine(to: CGPoint(x: width * x + treeHeight * 0.28, y: base)); tree.closeSubpath()
                    context.fill(tree, with: .color(palette.heroEnd))
                }
            }
            if theme == .tidewater || theme == .coral {
                for y in [0.80, 0.92] {
                    var ripple = Path()
                    ripple.move(to: CGPoint(x: width * 0.08, y: height * y))
                    ripple.addCurve(to: CGPoint(x: width * 0.90, y: height * y),
                        control1: CGPoint(x: width * 0.38, y: height * (y - 0.09)),
                        control2: CGPoint(x: width * 0.65, y: height * (y + 0.09)))
                    context.stroke(ripple, with: .color(.white.opacity(0.24)), lineWidth: 1.5)
                }
            }
        }
        .opacity(contrast == .increased ? 0 : 1)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}
