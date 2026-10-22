import SwiftUI

/// Bundled, original environmental artwork. It is scenery, never a metric or
/// evidence that a habit was completed. Coast has native light/dark variants.
enum RilovaWorldScene {
    case coast
    case sanctuary

    fileprivate var assetName: String {
        switch self {
        case .coast: return "RilovaCoast"
        case .sanctuary: return "RilovaSanctuary"
        }
    }
}

struct RilovaWorldArtwork: View {
    @Environment(\.appPalette) private var palette
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let scene: RilovaWorldScene

    var body: some View {
        GeometryReader { proxy in
            if contrast == .increased || reduceTransparency {
                palette.luminousColors.last ?? palette.heroEnd
            } else {
                Image(scene.assetName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .overlay {
                        if palette.theme != .tidewater {
                            palette.accent.opacity(0.16).blendMode(.color)
                        }
                    }
            }
        }
        .clipped()
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }
}

/// Presentation receives the existing saved preference from the composition
/// root. A missing profile never opts a user into a companion.
private struct RilovaCompanionProfileKey: EnvironmentKey {
    static let defaultValue: CompanionProfile? = nil
}

extension EnvironmentValues {
    var rilovaCompanionProfile: CompanionProfile? {
        get { self[RilovaCompanionProfileKey.self] }
        set { self[RilovaCompanionProfileKey.self] = newValue }
    }
}
