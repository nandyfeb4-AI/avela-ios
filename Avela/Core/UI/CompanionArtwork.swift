import SwiftUI
import UIKit

/// One shared, original six-pose atlas per animal. The extension uses exactly
/// the same rendering as the app, without importing persistence or domain APIs.
struct CompanionArtwork: View {
    let animal: String
    let state: String
    let size: CGFloat

    var body: some View {
        if let image = Self.image(animal: animal, state: state) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }

    static func image(animal: String, state: String) -> UIImage? {
        guard let index = stateNames.firstIndex(of: state) else { return nil }
        let poses: [UIImage]
        switch animal {
        case "owl": poses = owlArtwork
        case "fox": poses = foxArtwork
        case "otter": poses = otterArtwork
        default: return nil
        }
        return poses.indices.contains(index) ? poses[index] : nil
    }

    private static let stateNames = ["calm", "focused", "nearLimit", "overloaded", "recovering", "celebrating"]

    // Lazy immutable caches load only the requested animal, especially in
    // memory-constrained widgets. Each cell is decoded once at a size suited
    // to our maximum 80-point display at 3x screen scale.
    private static let owlArtwork = loadAtlas(named: "CompanionOwlStates")
    private static let foxArtwork = loadAtlas(named: "CompanionFoxStates")
    private static let otterArtwork = loadAtlas(named: "CompanionOtterStates")

    private static func loadAtlas(named name: String) -> [UIImage] {
        guard let source = UIImage(named: name)?.cgImage else { return [] }
        let width = source.width / 3
        let height = source.height / 2
        guard width > 0, height > 0 else { return [] }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        let renderedSize = CGSize(width: 256, height: 256 * CGFloat(height) / CGFloat(width))
        let renderer = UIGraphicsImageRenderer(size: renderedSize, format: format)
        let poses = (0..<6).compactMap { index -> UIImage? in
            let rect = CGRect(x: (index % 3) * width, y: (index / 3) * height, width: width, height: height)
            guard let cell = source.cropping(to: rect) else { return nil }
            return renderer.image { _ in
                UIImage(cgImage: cell).draw(in: CGRect(origin: .zero, size: renderedSize))
            }
        }
        return poses.count == 6 ? poses : []
    }
}
