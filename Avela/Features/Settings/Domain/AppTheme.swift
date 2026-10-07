import Foundation

/// Curated app accents. Status colors retain their meaning across themes.
enum AppTheme: String, CaseIterable, Identifiable, Sendable {
    case tidewater, sapphire, plum, ember, rose, indigo, forest, coral, gold

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var description: String {
        switch self {
        case .tidewater: return "Fresh teal · Avela's original palette"
        case .sapphire: return "Clear blue · Quiet focus"
        case .plum: return "Rich purple · A softer evening tone"
        case .ember: return "Warm copper · A little energy"
        case .rose: return "Deep rose · Warm and welcoming"
        case .indigo: return "Velvet blue · Clear and composed"
        case .forest: return "Leaf green · Grounded and fresh"
        case .coral: return "Soft coral · A brighter welcome"
        case .gold: return "Honey gold · Warm and luminous"
        }
    }

    /// Opaque sRGB values, paired for the system's light and dark appearance.
    var lightAccent: UInt32 {
        switch self {
        case .tidewater: return 0x0E7468
        case .sapphire: return 0x275DA8
        case .plum: return 0x754EB1
        case .ember: return 0xA44816
        case .rose: return 0x9D3F67
        case .indigo: return 0x4B4BB7
        case .forest: return 0x2B683D
        case .coral: return 0xAD463D
        case .gold: return 0x84600E
        }
    }
    var darkAccent: UInt32 {
        switch self {
        case .tidewater: return 0x3CC9B4
        case .sapphire: return 0x8BBBFF
        case .plum: return 0xCAB0FF
        case .ember: return 0xFFB186
        case .rose: return 0xF6A7C7
        case .indigo: return 0xB0B4FF
        case .forest: return 0x92D5A0
        case .coral: return 0xFFB0A5
        case .gold: return 0xF3CF72
        }
    }
}

@MainActor
protocol AppearanceRepository {
    func theme() throws -> AppTheme
    func save(theme: AppTheme) throws
}
